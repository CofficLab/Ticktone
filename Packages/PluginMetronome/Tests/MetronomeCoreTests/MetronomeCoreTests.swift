import XCTest
@testable import MetronomeCore

final class MetronomeCoreTests: XCTestCase {
    func testTempoClamp() {
        XCTAssertEqual(MetronomeTempo(bpm: 10).bpm, MetronomeTempo.minimum)
        XCTAssertEqual(MetronomeTempo(bpm: 500).bpm, MetronomeTempo.maximum)
        XCTAssertEqual(MetronomeTempo(bpm: 120).bpm, 120)
    }

    func testFlashRateLimiterCapsAtThreePerSecond() {
        var limiter = FlashRateLimiter(maxPerSecond: 3)
        // 300 BPM：每 0.2s 一次强拍候选。
        let allowed = stride(from: 0.0, through: 2.0, by: 0.2).filter {
            limiter.shouldAllow(at: $0)
        }
        XCTAssertEqual(allowed.count, 7)
        let rounded = allowed.map { ($0 * 10).rounded() / 10 }
        XCTAssertEqual(rounded, [0, 0.2, 0.4, 1.0, 1.2, 1.4, 2.0])
    }

    func testFlashRateLimiterDoesNotLimitSlowTempo() {
        var limiter = FlashRateLimiter(maxPerSecond: 3)
        XCTAssertTrue(limiter.shouldAllow(at: 0))
        XCTAssertTrue(limiter.shouldAllow(at: 1.0))
        XCTAssertTrue(limiter.shouldAllow(at: 2.0))
        XCTAssertTrue(limiter.shouldAllow(at: 3.0))
    }

    func testBeatInterval() {
        XCTAssertEqual(MetronomeTempo(bpm: 120).beatInterval, 0.5, accuracy: 1e-9)
    }

    func testPatternCycleAndResize() {
        var pattern = BeatPattern.default(beatsPerMeasure: 4)
        XCTAssertEqual(pattern.accent(at: 0), .accent)
        XCTAssertEqual(pattern.accent(at: 1), .normal)

        pattern.cycleAccent(at: 1)
        XCTAssertEqual(pattern.accent(at: 1), .muted)
        pattern.cycleAccent(at: 1)
        XCTAssertEqual(pattern.accent(at: 1), .accent)

        pattern.resize(to: 6)
        XCTAssertEqual(pattern.count, 6)
        pattern.resize(to: 2)
        XCTAssertEqual(pattern.count, 2)
        XCTAssertEqual(pattern.accent(at: 0), .accent)
    }

    func testResizeKeepsAtLeastOneAudibleBeat() {
        var pattern = BeatPattern(accents: [.muted, .muted, .muted])
        pattern.resize(to: 2)
        XCTAssertFalse(pattern.accents.allSatisfy { $0 == .muted })
    }

    func testSettingsPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "MetronomeCoreTests.settings")!
        defaults.removePersistentDomain(forName: "MetronomeCoreTests.settings")

        var settings = MetronomeSettings(bpm: 132, beatsPerMeasure: 7, beatUnit: 8, subdivision: .eighth)
        settings.flashEnabled = false
        settings.save(defaults: defaults)

        let loaded = MetronomeSettings.load(defaults: defaults)
        XCTAssertEqual(loaded, settings)
    }

    func testPresetPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "MetronomeCoreTests.presets")!
        defaults.removePersistentDomain(forName: "MetronomeCoreTests.presets")

        let presets = [MetronomePreset(name: "练习", settings: MetronomeSettings(bpm: 60))]
        MetronomePreset.saveAll(presets, defaults: defaults)
        XCTAssertEqual(MetronomePreset.loadAll(defaults: defaults), presets)
    }

    func testTapTempo() {
        var tap = TapTempoCalculator()
        XCTAssertNil(tap.tap(at: 0))
        let first = tap.tap(at: 0.5)
        XCTAssertNotNil(first)
        XCTAssertEqual(first!, 120, accuracy: 0.001)
        _ = tap.tap(at: 1.0)
        _ = tap.tap(at: 1.5)
        XCTAssertEqual(tap.tap(at: 2.0)!, 120, accuracy: 0.001)
    }

    func testTapTempoResetAfterPause() {
        var tap = TapTempoCalculator()
        _ = tap.tap(at: 0)
        _ = tap.tap(at: 0.5)
        // 间隔超过 2 秒，重置序列，不返回 BPM。
        XCTAssertNil(tap.tap(at: 5.0))
        let bpm = tap.tap(at: 5.4)
        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm!, 150, accuracy: 0.001)
    }

    // MARK: - 变速训练

    func testTempoTrainingAscending() {
        let training = TempoTraining(isEnabled: true, targetBPM: 120, step: 5, measuresPerStep: 2)
        XCTAssertEqual(training.bpm(base: 100, measure: 0), 100)
        XCTAssertEqual(training.bpm(base: 100, measure: 1), 100)
        XCTAssertEqual(training.bpm(base: 100, measure: 2), 105)
        XCTAssertEqual(training.bpm(base: 100, measure: 8), 120)
        // 到目标后保持，不越过目标。
        XCTAssertEqual(training.bpm(base: 100, measure: 12), 120)
        XCTAssertEqual(training.bpm(base: 100, measure: 40), 120)
    }

    func testTempoTrainingDescending() {
        let training = TempoTraining(isEnabled: true, targetBPM: 90, step: 5, measuresPerStep: 1)
        XCTAssertEqual(training.bpm(base: 120, measure: 0), 120)
        XCTAssertEqual(training.bpm(base: 120, measure: 2), 110)
        XCTAssertEqual(training.bpm(base: 120, measure: 6), 90)
        XCTAssertEqual(training.bpm(base: 120, measure: 10), 90)
    }

    func testTempoTrainingDisabledKeepsBase() {
        let training = TempoTraining(isEnabled: false, targetBPM: 200, step: 10, measuresPerStep: 1)
        XCTAssertEqual(training.bpm(base: 100, measure: 3), 100)
        XCTAssertFalse(training.hasReachedTarget(base: 100, currentBPM: 100))
    }

    func testTempoTrainingReachedTarget() {
        let training = TempoTraining(isEnabled: true, targetBPM: 120, step: 5, measuresPerStep: 2)
        XCTAssertFalse(training.hasReachedTarget(base: 100, currentBPM: 115))
        XCTAssertTrue(training.hasReachedTarget(base: 100, currentBPM: 120))
    }

    // MARK: - 旧存档兼容

    func testLegacySettingsDecodeKeepsDefaultsForNewFields() throws {
        // 升级前的存档没有 soundEnabled / tempoLockEnabled / countInMeasures / training。
        let json = """
        {"bpm":144,"beatsPerMeasure":3,"beatUnit":8,"subdivision":1,
         "accents":[2,1,1],"soundSet":"classic","volume":0.5,
         "flashEnabled":false,"hapticsEnabled":false}
        """
        let settings = try JSONDecoder().decode(MetronomeSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.bpm, 144)
        XCTAssertEqual(settings.beatsPerMeasure, 3)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertFalse(settings.tempoLockEnabled)
        XCTAssertEqual(settings.countInMeasures, 0)
        XCTAssertFalse(settings.training.isEnabled)
    }

    /// 「屏幕闪光」是视图层能力，macOS/iOS 都支持；旧存档缺少该字段时应回落为开启，
    /// 不能因为字段缺失导致整份设置解码失败。
    func testMissingFlashKeyKeepsScreenFlashDefault() throws {
        let json = """
        {"bpm":90,"beatsPerMeasure":4,"beatUnit":4,"subdivision":1,
         "accents":[2,1,1,1],"soundSet":"classic","volume":0.7}
        """
        let settings = try JSONDecoder().decode(MetronomeSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.bpm, 90)
        XCTAssertTrue(settings.flashEnabled)
    }

    // MARK: - 摆锤相位

    func testPendulumHitsAlternatingExtremesOnBeats() {
        let maxRadians = MetronomePendulum.defaultMaxAngleDegrees * .pi / 180
        XCTAssertEqual(
            MetronomePendulum.angle(now: 10, tickUptime: 10, beatOrdinal: 0, beatInterval: 0.5),
            maxRadians,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            MetronomePendulum.angle(now: 10, tickUptime: 10, beatOrdinal: 1, beatInterval: 0.5),
            -maxRadians,
            accuracy: 1e-9
        )
    }

    /// 下一拍开始时位置应正好接上一拍结束的位置，不能瞬移。
    func testPendulumIsContinuousAcrossBeats() {
        let beforeNextBeat = MetronomePendulum.angle(
            now: 10.5 - 1e-6,
            tickUptime: 10,
            beatOrdinal: 0,
            beatInterval: 0.5
        )
        let atNextBeat = MetronomePendulum.angle(
            now: 10.5,
            tickUptime: 10.5,
            beatOrdinal: 1,
            beatInterval: 0.5
        )
        XCTAssertEqual(beforeNextBeat, atNextBeat, accuracy: 1e-4)
    }

    /// 全速域（30–300 BPM）逐帧角度都没有跳变；跨入下一拍也连续。
    func testPendulumFrameStepsStaySmoothAcrossTempoRange() {
        let frameInterval = 1.0 / 60.0
        let maxRadians = MetronomePendulum.defaultMaxAngleDegrees * .pi / 180
        for bpm in [30.0, 40.0, 100.0, 200.0, 300.0] {
            let beatInterval = 60.0 / bpm
            // cos 摆动的最大角速度约为 A·π/T；60fps 下单帧变化不应超过这个理论值。
            let maxFrameStep = maxRadians * .pi * (frameInterval / beatInterval) * 1.05
            var previous = MetronomePendulum.angle(
                now: 0, tickUptime: 0, beatOrdinal: 0, beatInterval: beatInterval
            )
            var now = frameInterval
            while now < beatInterval {
                let current = MetronomePendulum.angle(
                    now: now, tickUptime: 0, beatOrdinal: 0, beatInterval: beatInterval
                )
                XCTAssertLessThan(abs(current - previous), maxFrameStep, "\(bpm) BPM 在 \(now)s 处跳变")
                previous = current
                now += frameInterval
            }
            let nextBeat = MetronomePendulum.angle(
                now: beatInterval, tickUptime: beatInterval, beatOrdinal: 1, beatInterval: beatInterval
            )
            XCTAssertLessThan(abs(nextBeat - previous), maxFrameStep, "\(bpm) BPM 跨拍跳变")
        }
    }

    /// 换速点：拍长取下一小节的实际间隔，位置仍然连续。
    func testPendulumHandlesTempoChangeAtMeasureBoundary() {
        // 60 → 120：最后一拍到下一拍只有 0.5s。
        let endOfSlowBeat = MetronomePendulum.angle(
            now: 0.5 - 1e-6, tickUptime: 0, beatOrdinal: 0, beatInterval: 0.5
        )
        let startOfFastBeat = MetronomePendulum.angle(
            now: 0.5, tickUptime: 0.5, beatOrdinal: 1, beatInterval: 0.5
        )
        XCTAssertEqual(endOfSlowBeat, startOfFastBeat, accuracy: 1e-4)

        // 120 → 60：最后一拍要等 1.0s 才进入下一拍，端点自然停住再反向。
        let endOfFastBeat = MetronomePendulum.angle(
            now: 1.0 - 1e-6, tickUptime: 0, beatOrdinal: 0, beatInterval: 1.0
        )
        let startOfSlowBeat = MetronomePendulum.angle(
            now: 1.0, tickUptime: 1.0, beatOrdinal: 1, beatInterval: 1.0
        )
        XCTAssertEqual(endOfFastBeat, startOfSlowBeat, accuracy: 1e-4)
    }

    // MARK: - 调度算术

    func testTimelineSamplesPerTick() {
        let timeline = MetronomeTimeline(bpm: 120, beatsPerMeasure: 4, subdivision: .none, sampleRate: 48000)
        XCTAssertEqual(timeline.samplesPerTick, 24000, accuracy: 1e-9)

        let eighth = MetronomeTimeline(bpm: 120, beatsPerMeasure: 4, subdivision: .eighth, sampleRate: 48000)
        XCTAssertEqual(eighth.samplesPerTick, 12000, accuracy: 1e-9)

        let triplet = MetronomeTimeline(bpm: 90, beatsPerMeasure: 3, subdivision: .triplet, sampleRate: 44100)
        XCTAssertEqual(triplet.secondsPerTick, 60.0 / (90 * 3), accuracy: 1e-9)
    }

    func testTimelineBeatWalk() {
        let timeline = MetronomeTimeline(bpm: 100, beatsPerMeasure: 4, subdivision: .eighth, sampleRate: 48000)
        // 八分细分：0 0 1 1 2 2 3 3，然后回到第 0 拍。
        let expected = [0, 0, 1, 1, 2, 2, 3, 3, 0]
        for (ordinal, beat) in expected.enumerated() {
            let info = timeline.beatInfo(tickOrdinal: ordinal)
            XCTAssertEqual(info.beat, beat, "ordinal \(ordinal)")
            XCTAssertEqual(info.isSubdivision, ordinal % 2 != 0, "ordinal \(ordinal)")
        }
    }

    /// 以 Double 累加 10 万个 tick，与理论总时长偏差应远小于 1 个采样。
    func testLongRunDoesNotDrift() {
        let timeline = MetronomeTimeline(bpm: 132, beatsPerMeasure: 7, subdivision: .triplet, sampleRate: 44100)
        var accumulated = 0.0
        let ticks = 100_000
        for _ in 0..<ticks {
            accumulated += timeline.samplesPerTick
        }
        let expected = timeline.secondsPerTick * Double(ticks) * timeline.sampleRate
        // 与理论总时长的偏差必须远小于一个采样（实测约 1e-3 个采样）。
        XCTAssertEqual(accumulated, expected, accuracy: 1.0)
    }
}
