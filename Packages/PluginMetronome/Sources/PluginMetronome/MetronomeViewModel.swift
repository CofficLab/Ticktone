import Combine
import Foundation
import MetronomeCore
import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

/// 节拍器会话状态机：UI 的唯一数据源。
///
/// 所有设置改动立即持久化并同步给音频引擎；引擎回调的 tick 事件
/// 驱动拍点指示灯、摆锤、闪光与触觉反馈。
@MainActor
public final class MetronomeViewModel: ObservableObject {
    // MARK: - Published 状态

    @Published public private(set) var settings: MetronomeSettings
    @Published public private(set) var presets: [MetronomePreset]
    @Published public private(set) var isPlaying = false
    /// 最近一次获准触发屏幕闪光的强拍 tick（已按每秒最多 3 次限流）。
    @Published public private(set) var flashTick: TickInfo?
    /// 最近一次**已经到达出声时刻**的整拍 tick，驱动拍点与屏幕闪光。
    ///
    /// 引擎会提前约 0.25s 调度 tick（细分开启时一次会排好几拍），若直接使用
    /// 最新调度结果，拍点/闪光会被更靠后的 tick 覆盖，导致开启细分或高 BPM 时
    /// 指示灯与闪光停摆。这里和 `audibleTick` 一样按出声时刻发布。
    @Published public private(set) var lastTick: TickInfo?
    /// 最近一次**已经到达出声时刻**的非细分 tick，驱动小节读数、摆锤与训练速度。
    ///
    /// 引擎会提前约 0.25s 排 tick，若直接使用调度结果会让读数提前跳动；
    /// 这里按 uptime 延迟到出声时刻再更新，保证和听到的一致。
    @Published public private(set) var audibleTick: TickInfo?
    /// 是否处于预备拍阶段（开始前给练习者数拍）。
    @Published public private(set) var isCountingIn = false
    /// 需要向用户展示的暂停原因（如耳机/蓝牙断开）；为 nil 时不弹窗。
    @Published public private(set) var pauseNotice: String?

    private let engine = MetronomeEngine()
    private var tapCalculator = TapTempoCalculator()
    /// 光敏安全：无论节拍多快，屏幕闪光最多每秒 3 次。
    private var flashRateLimiter = FlashRateLimiter(maxPerSecond: 3)
    private let defaults: UserDefaults

    #if os(iOS)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private var interruptionCancellable: AnyCancellable?
    private var routeChangeCancellable: AnyCancellable?
    #endif

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = MetronomeSettings.load(defaults: defaults)
        self.presets = MetronomePreset.loadAll(defaults: defaults)
        engine.onTickScheduled = { [weak self] info in
            Task { @MainActor [weak self] in
                self?.handleTick(info)
            }
        }
        engine.onAutoStop = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
        // 音频会话不可用（被其他 App 占用等）时启动会失败：回到停止态，
        // 不能让界面停留在「播放中」却没有声音的状态。
        engine.onStartFailure = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
        #if os(iOS)
        // 用 Combine 订阅而非 block observer：block observer 的 handler 是
        // @Sendable，捕获 MainActor 的 self 在 Swift 6 下不合法。
        interruptionCancellable = NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                MainActor.assumeIsolated {
                    self?.handleInterruption(note)
                }
            }
        routeChangeCancellable = NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                MainActor.assumeIsolated {
                    self?.handleRouteChange(note)
                }
            }
        #endif
    }

    // MARK: - 播放控制

    public func toggle() {
        isPlaying ? stop() : start()
    }

    public func start() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTick = nil
        audibleTick = nil
        flashTick = nil
        flashRateLimiter.reset()
        isCountingIn = settings.countInMeasures > 0
        tapCalculator.reset()
        engine.start(settings: settings)
        #if os(iOS)
        impactLight.prepare()
        impactHeavy.prepare()
        #endif
    }

    public func stop() {
        guard isPlaying else { return }
        isPlaying = false
        isCountingIn = false
        lastTick = nil
        audibleTick = nil
        flashTick = nil
        engine.stop()
    }

    // MARK: - 设置修改（改动即持久化 + 同步引擎）

    /// 演出锁定：播放中禁止改变速度与拍号，避免误触打断演奏。
    public var isTempoLocked: Bool {
        settings.tempoLockEnabled && isPlaying
    }

    /// 当前实际使用的速度（变速训练时与滑杆值不同）。
    public var effectiveBPM: Double {
        audibleTick?.bpm ?? settings.bpm
    }

    public func setBPM(_ value: Double) {
        guard !isTempoLocked else { return }
        settings.bpm = MetronomeTempo.clamp(value)
        apply()
    }

    public func setTimeSignature(_ signature: MetronomeTimeSignature) {
        guard !isTempoLocked else { return }
        settings.beatsPerMeasure = signature.beatsPerMeasure
        settings.beatUnit = signature.beatUnit
        var pattern = settings.pattern
        pattern.resize(to: signature.beatsPerMeasure)
        settings.accents = pattern.accents
        apply()
    }

    public func setSubdivision(_ subdivision: MetronomeSubdivision) {
        settings.subdivision = subdivision
        apply()
    }

    public func cycleAccent(at beat: Int) {
        var pattern = settings.pattern
        pattern.cycleAccent(at: beat)
        settings.accents = pattern.accents
        apply()
    }

    public func setSoundSet(_ soundSet: ClickSoundSet) {
        settings.soundSet = soundSet
        apply()
    }

    public func setVolume(_ volume: Float) {
        settings.volume = min(max(volume, 0), 1)
        apply()
    }

    public func setFlashEnabled(_ enabled: Bool) {
        settings.flashEnabled = enabled
        apply()
    }

    public func setHapticsEnabled(_ enabled: Bool) {
        settings.hapticsEnabled = enabled
        apply()
    }

    /// 静音练习：只保留摆锤、拍点与闪光的视觉提示。
    public func setSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
        apply()
    }

    /// 演出锁定：播放中禁止改速度/拍号，下一次开始后生效。
    public func setTempoLockEnabled(_ enabled: Bool) {
        settings.tempoLockEnabled = enabled
        apply()
    }

    /// 开始前的预备小节数（0 = 关闭）。播放中修改在下次开始时生效。
    public func setCountInMeasures(_ measures: Int) {
        settings.countInMeasures = min(max(measures, 0), 2)
        apply()
    }

    // MARK: - 变速训练

    public func setTrainingEnabled(_ enabled: Bool) {
        mutateTraining { $0.isEnabled = enabled }
    }

    public func setTrainingTarget(_ targetBPM: Double) {
        mutateTraining { $0.targetBPM = targetBPM }
    }

    public func setTrainingStep(_ step: Double) {
        mutateTraining { $0.step = step }
    }

    public func setTrainingMeasuresPerStep(_ count: Int) {
        mutateTraining { $0.measuresPerStep = count }
    }

    public func setTrainingStopAtTarget(_ enabled: Bool) {
        mutateTraining { $0.stopAtTarget = enabled }
    }

    private func mutateTraining(_ body: (inout TempoTraining) -> Void) {
        var training = settings.training
        body(&training)
        // 重新构造以复用范围钳制（目标 30–300、步长 ≥1、每 N 小节 ≥1）。
        settings.training = TempoTraining(
            isEnabled: training.isEnabled,
            targetBPM: training.targetBPM,
            step: training.step,
            measuresPerStep: training.measuresPerStep,
            stopAtTarget: training.stopAtTarget
        )
        apply()
    }

    // MARK: - Tap Tempo

    public func tap() {
        guard !isTempoLocked else { return }
        guard let bpm = tapCalculator.tap() else { return }
        setBPM(bpm.rounded())
    }

    // MARK: - 预设

    public func savePreset(name: String) {
        let preset = MetronomePreset(name: name, settings: settings)
        presets.append(preset)
        MetronomePreset.saveAll(presets, defaults: defaults)
    }

    public func applyPreset(_ preset: MetronomePreset) {
        settings = preset.settings
        apply()
    }

    public func deletePreset(_ preset: MetronomePreset) {
        presets.removeAll { $0.id == preset.id }
        MetronomePreset.saveAll(presets, defaults: defaults)
    }

    // MARK: - 内部

    private func apply() {
        settings.save(defaults: defaults)
        if isPlaying {
            engine.update(settings: settings)
        }
    }

    private func handleTick(_ info: TickInfo) {
        // 拍点与闪光只跟随整拍；细分 tick 不参与视觉提示。
        guard !info.isSubdivision else { return }

        // 在预计出声时刻更新「已听到」状态并触发触觉；调度前瞻约 0.25s。
        let delay = max(0, info.uptime - ProcessInfo.processInfo.systemUptime)
        Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard let self, self.isPlaying else { return }
            self.lastTick = info
            self.audibleTick = info
            if info.accent == .accent,
               self.flashRateLimiter.shouldAllow(at: info.uptime) {
                self.flashTick = info
            }
            self.isCountingIn = info.isCountIn
            #if os(iOS)
            guard self.settings.hapticsEnabled else { return }
            if info.accent == .accent {
                self.impactHeavy.impactOccurred()
            } else {
                self.impactLight.impactOccurred()
            }
            #endif
        }
    }

    public func clearPauseNotice() {
        pauseNotice = nil
    }

    #if os(iOS)
    /// 耳机拔出或蓝牙设备断开时，音频会自动改从扬声器输出。
    /// 练琴时这属于私密场景被打断，直接暂停并告知，避免打扰他人。
    private func handleRouteChange(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable,
              isPlaying else { return }
        stop()
        pauseNotice = "耳机或蓝牙设备已断开，为避免声音从扬声器外放，节拍匠已暂停。"
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // 走完整 stop 流程：除暂停引擎外，还要清理小节读数、预备拍与
            // 变速训练的临时 BPM，避免中断后在停止态继续显示练习中的速度。
            stop()
        case .ended:
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                start()
            }
        @unknown default:
            break
        }
    }
    #endif
}
