import AVFoundation
import MetronomeCore

/// 一次 tick 的描述，用于 UI 同步（拍点指示灯、摆锤、闪光、触觉）。
public struct TickInfo: Sendable, Equatable {
    /// 小节内第几拍（0 起）。
    public var beat: Int
    /// 是否为拍内细分点（非拍头）。
    public var isSubdivision: Bool
    /// 重音级别。
    public var accent: BeatAccent
    /// 预计出声时刻（系统 uptime 秒）。
    public var uptime: TimeInterval
    /// 从启动起的 tick 序号。
    public var ordinal: Int
    /// 当前是第几个小节（0 起）；预备拍阶段为第几个预备小节（0 起）。
    public var measure: Int
    /// 是否处于预备拍（count-in）阶段。
    public var isCountIn: Bool
    /// 该 tick 所在小节实际使用的 BPM（变速训练会在小节边界改变它）。
    public var bpm: Double
    /// 从开始起的第几个**拍**（含预备拍，细分 tick 不递增）。
    /// 视图靠它的奇偶决定摆锤朝哪一侧，保证相邻两拍首尾同向衔接。
    public var beatOrdinal: Int
    /// 从这一拍到下一拍的时长（秒）。细分 tick 为 0。
    /// 换速时这里已经是下一拍所在小节的实际间隔，摆锤不会因换速抽搐。
    public var beatInterval: TimeInterval

    public init(
        beat: Int,
        isSubdivision: Bool,
        accent: BeatAccent,
        uptime: TimeInterval,
        ordinal: Int,
        measure: Int = 0,
        isCountIn: Bool = false,
        bpm: Double = 0,
        beatOrdinal: Int = 0,
        beatInterval: TimeInterval = 0
    ) {
        self.beat = beat
        self.isSubdivision = isSubdivision
        self.accent = accent
        self.uptime = uptime
        self.ordinal = ordinal
        self.measure = measure
        self.isCountIn = isCountIn
        self.bpm = bpm
        self.beatOrdinal = beatOrdinal
        self.beatInterval = beatInterval
    }
}

/// 采样级精准节拍器音频引擎。
///
/// 时序策略（这也是所有专业节拍器的共同做法）：
/// - 声音通过 `AVAudioPlayerNode.scheduleBuffer` 按**采样时间**提前调度，
///   调度本身发生在后台串行队列，与主线程解耦。
/// - tick 时刻用 Double 采样数累加，调度时取整但**不累加舍入误差**，
///   长时运行不漂移。
/// - UI 同步通过 `playerTime(forNodeTime:)` → host time → uptime 换算，
///   在调度时一并算好回传到主线程。
///
/// 绝不能用 `Timer` 直接触发声音 —— 主线程抖动会造成可闻的节奏不准。
///
/// 小节与变速训练也在这一层完成：每个 tick 的间隔在**调度之后**按
/// 「下一 tick 所在小节的 BPM」算出，所以换速只改变小节边界之后的声音，
/// 不会重锚采样时钟。
public final class MetronomeEngine: @unchecked Sendable {
    /// 调度定时器触发间隔。
    private static let pumpInterval: TimeInterval = 0.03
    /// 调度前瞻窗口：保证队列里始终有未来 0.25s 的 tick。
    private static let lookahead: TimeInterval = 0.25
    /// 训练到位后停止前留出的收尾余量，避免截断最后一下点击的尾音。
    private static let stopTail: TimeInterval = 0.1

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let queue = DispatchQueue(label: "com.coffic.metronome.engine")
    private var timer: DispatchSourceTimer?

    private var settings = MetronomeSettings()
    private var buffers: [ClickSoundSet: [ClickKind: AVAudioPCMBuffer]] = [:]
    private var sampleRate: Double = 44100

    /// 下一次 tick 的采样时刻（node 时间线），Double 累加防漂移。
    private var nextTickSample: Double = 0
    /// 最近一次已经排进播放队列的 tick 时刻。
    /// 运行中改速度时用它作为锚点，保证新速度不会与已排队的 tick 撞在一起。
    private var lastScheduledSample: Double = 0
    private var tickOrdinal: Int = 0
    private var running = false

    // MARK: - 小节 / 预备拍 / 变速训练状态（仅在 queue 上读写）

    private enum Phase {
        case countIn
        case playing
    }

    private var phase: Phase = .playing
    /// 预备拍已排出的拍数。
    private var countInTickIndex = 0
    /// 本次启动实际要走的预备拍总数（启动时固定，避免中途改设置打乱序号）。
    private var countInBeats = 0
    /// 当前小节序号（0 起）。
    private var measure = 0
    /// 当前小节内已排出的 tick 数（含细分）。
    private var measureTick = 0
    /// 当前小节实际使用的 BPM。
    private var currentBPM: Double = 100
    /// 变速训练到达目标后，待停止的采样时刻。
    private var pendingStopSample: Double?

    /// 每次 tick 被调度后回调（主线程）。
    public var onTickScheduled: ((TickInfo) -> Void)?
    /// 变速训练到达目标并自动停止后回调（主线程）。
    public var onAutoStop: (() -> Void)?
    /// 启动失败（音频会话不可用等）后回调（主线程），让 UI 回到停止态。
    public var onStartFailure: (() -> Void)?

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    deinit {
        timer?.cancel()
    }

    // MARK: - Public API（可从任意线程调用）

    public func update(settings: MetronomeSettings) {
        queue.async {
            let previous = self.settings
            let timingChanged = previous.bpm != settings.bpm
                || previous.subdivision != settings.subdivision
                || previous.beatsPerMeasure != settings.beatsPerMeasure
            self.settings = settings
            self.player.volume = settings.volume

            guard self.running else { return }

            if timingChanged, let now = self.nowSampleTime() {
                // 拍号/细分变化时从当前小节拍头重新对齐，避免残留半拍。
                if self.phase == .playing,
                   previous.beatsPerMeasure != settings.beatsPerMeasure
                    || previous.subdivision != settings.subdivision {
                    self.measureTick = 0
                }
                // 速度/训练参数变化只影响从下一刻开始的间隔，不重锚已排出的 tick。
                // 以「已排进队列的最后一拍」为锚点再加一个新间隔：
                // - 不会排到已排队 tick 之前（高 BPM/密集细分时避免双击）；
                // - 也不会像直接取 now + interval 那样在拖动时把下一拍永远推到前瞻窗口之外。
                self.currentBPM = self.effectiveBPM()
                self.pendingStopSample = nil
                let anchor = max(now, self.lastScheduledSample)
                self.nextTickSample = anchor + self.intervalSamples()
            } else if previous.training != settings.training {
                self.currentBPM = self.effectiveBPM()
            }
        }
    }

    public func start(settings: MetronomeSettings) {
        queue.async {
            guard !self.running else { return }
            self.settings = settings
            do {
                try self.configureAudioSessionIfNeeded()
                let format = self.engine.outputNode.outputFormat(forBus: 0)
                self.sampleRate = format.sampleRate
                self.buffers = ClickSynthesizer.makeBuffers(
                    sampleRate: self.sampleRate,
                    channelCount: format.channelCount
                )
                self.player.volume = settings.volume
                self.engine.prepare()
                try self.engine.start()
                self.player.play()

                self.tickOrdinal = 0
                self.phase = settings.countInMeasures > 0 ? .countIn : .playing
                self.countInTickIndex = 0
                self.countInBeats = settings.countInMeasures * settings.beatsPerMeasure
                self.measure = 0
                self.measureTick = 0
                self.currentBPM = MetronomeTempo.clamp(settings.bpm)
                self.pendingStopSample = nil

                let now = self.nowSampleTime() ?? 0
                // 留一点启动余量，避免第一拍落在过去。
                self.nextTickSample = now + 0.1 * self.sampleRate
                self.lastScheduledSample = now
                self.running = true
                self.startPump()
            } catch {
                self.running = false
                DispatchQueue.main.async { [weak self] in
                    self?.onStartFailure?()
                }
            }
        }
    }

    public func stop() {
        queue.async {
            guard self.running else { return }
            self.finish(autoStopped: false)
        }
    }

    // MARK: - Scheduling（仅在 queue 上执行）

    private func startPump() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.pumpInterval, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in self?.pump() }
        timer.resume()
        self.timer = timer
    }

    private func pump() {
        guard running, let now = nowSampleTime() else { return }

        // 训练到位后不再排新 tick，等已排出的最后一下播完再收尾。
        if let stopSample = pendingStopSample {
            if now >= stopSample {
                finish(autoStopped: true)
            }
            return
        }

        let horizon = now + Self.lookahead * sampleRate
        while nextTickSample < horizon {
            lastScheduledSample = nextTickSample
            let tick = scheduleTick(at: nextTickSample)
            tickOrdinal += 1
            let shouldStop = advanceTick()
            let interval = intervalSamples()
            // 摆锤用的拍长：从这一拍到下一拍的实际时长。
            // 小节最后一拍之后要跨到下一小节，换速时取下一小节的目标速度，
            // 这样带细分时也不会在换速点抽搐。
            let beatInterval: TimeInterval = {
                guard let tick, !tick.isSubdivision else { return 0 }
                let nextBPM: Double
                if tick.isCountIn {
                    nextBPM = tick.bpm
                } else if tick.beat == settings.beatsPerMeasure - 1 {
                    nextBPM = settings.training.bpm(base: settings.bpm, measure: tick.measure + 1)
                } else {
                    nextBPM = tick.bpm
                }
                return 60.0 / max(1, nextBPM)
            }()
            if shouldStop {
                emit(tick, beatInterval: beatInterval)
                pendingStopSample = nextTickSample + interval + Self.stopTail * sampleRate
                return
            }
            nextTickSample += interval
            emit(tick, beatInterval: beatInterval)
        }
    }

    /// 排出一个 tick 的声音与时间信息；返回 nil 表示引擎还没拿到可用的播放时间。
    private func scheduleTick(at sample: Double) -> TickInfo? {
        let beat: Int
        let isSubdivision: Bool
        let accent: BeatAccent
        let tickMeasure: Int
        let beatOrdinal: Int

        switch phase {
        case .countIn:
            let beats = settings.beatsPerMeasure
            beat = countInTickIndex % beats
            isSubdivision = false
            tickMeasure = beats > 0 ? countInTickIndex / beats : 0
            beatOrdinal = countInTickIndex
            // 预备拍必须听得见，即使该拍在当前模式里被静音。
            let configured = settings.pattern.accent(at: beat)
            accent = configured == .muted ? .normal : configured
        case .playing:
            let multiplier = settings.subdivision.multiplier
            beat = (measureTick / multiplier) % settings.beatsPerMeasure
            isSubdivision = measureTick % multiplier != 0
            accent = isSubdivision ? BeatAccent.normal : settings.pattern.accent(at: beat)
            tickMeasure = measure
            beatOrdinal = countInBeats + measure * settings.beatsPerMeasure + beat
        }

        let scheduleTime = AVAudioTime(sampleTime: AVAudioFramePosition(sample.rounded()), atRate: sampleRate)
        if settings.soundEnabled && (accent != .muted || isSubdivision) {
            let kind: ClickKind = isSubdivision ? .subdivision : (accent == .accent ? .accent : .normal)
            if let buffer = buffers[settings.soundSet]?[kind] {
                player.scheduleBuffer(buffer, at: scheduleTime, options: [], completionHandler: nil)
            }
        }

        guard let playerTime = player.playerTime(forNodeTime: scheduleTime),
              playerTime.isHostTimeValid else { return nil }
        // hostTime 与 ProcessInfo.systemUptime 是同一时间基准，直接换算即可。
        // 不能把 sampleTime 当作「距开机秒数」再转 hostTime —— 那是距 player
        // 启动的秒数，会得到接近 0 的时刻，UI 相位将永远被钳在端点。
        let uptime = Self.uptimeSeconds(forHostTime: playerTime.hostTime)
        return TickInfo(
            beat: beat,
            isSubdivision: isSubdivision,
            accent: accent,
            uptime: uptime,
            ordinal: tickOrdinal,
            measure: tickMeasure,
            isCountIn: phase == .countIn,
            bpm: currentBPM,
            beatOrdinal: beatOrdinal
        )
    }

    /// 回主线程派发 tick，并补上「到下一拍的时长」。
    private func emit(_ tick: TickInfo?, beatInterval: TimeInterval) {
        guard var tick else { return }
        tick.beatInterval = beatInterval
        DispatchQueue.main.async { [weak self] in
            self?.onTickScheduled?(tick)
        }
    }

    /// 推进到下一 tick 所在的小节位置。返回 true 表示训练已到位、本小节播完即停。
    @discardableResult
    private func advanceTick() -> Bool {
        switch phase {
        case .countIn:
            countInTickIndex += 1
            // 用启动时固定的总数，播放中途改设置不会打乱预备拍序号。
            if countInTickIndex >= countInBeats {
                phase = .playing
                measure = 0
                measureTick = 0
                currentBPM = effectiveBPM()
            }
            return false

        case .playing:
            measureTick += 1
            let ticksPerMeasure = settings.beatsPerMeasure * settings.subdivision.multiplier
            guard measureTick >= ticksPerMeasure else { return false }

            // 本节已按目标速度完整播完，准备收尾。
            if settings.training.isEnabled,
               settings.training.stopAtTarget,
               settings.training.hasReachedTarget(base: settings.bpm, currentBPM: currentBPM) {
                return true
            }

            measure += 1
            measureTick = 0
            currentBPM = effectiveBPM()
            return false
        }
    }

    /// 下一 tick 与当前 tick 之间的采样数。
    /// 以「下一 tick 所在小节」的 BPM 计算：换速从新小节的第一拍开始生效。
    private func intervalSamples() -> Double {
        guard sampleRate > 0 else { return 0 }
        let multiplier = phase == .countIn ? 1 : settings.subdivision.multiplier
        return sampleRate * 60.0 / (max(1, currentBPM) * Double(multiplier))
    }

    private func effectiveBPM() -> Double {
        if phase == .countIn {
            return MetronomeTempo.clamp(settings.bpm)
        }
        return settings.training.bpm(base: settings.bpm, measure: measure)
    }

    private func finish(autoStopped: Bool) {
        running = false
        timer?.cancel()
        timer = nil
        pendingStopSample = nil
        player.stop()
        engine.pause()
        if autoStopped {
            DispatchQueue.main.async { [weak self] in
                self?.onAutoStop?()
            }
        }
    }

    private func nowSampleTime() -> Double? {
        guard let time = player.lastRenderTime, time.isSampleTimeValid else { return nil }
        return Double(time.sampleTime)
    }

    /// mach host time → 系统 uptime 秒。
    private static func uptimeSeconds(forHostTime hostTime: UInt64) -> TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(hostTime) * Double(info.numer) / Double(info.denom) / 1e9
    }

    // MARK: - iOS Audio Session

    private func configureAudioSessionIfNeeded() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif
    }
}
