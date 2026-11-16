import MetronomeCore
import XCTest
@testable import PluginMetronome

/// 音频引擎的集成测试：验证「开始 → 按采样时间调度 tick → 回调」
/// 与「停止后不再调度」这两条关键链路，而非只测纯算术。
final class MetronomeEngineTests: XCTestCase {
    func testStartEmitsTicksAndStopSilences() throws {
        let engine = MetronomeEngine()
        let started = expectation(description: "tick scheduled")
        started.assertForOverFulfill = false
        var received = 0

        engine.onTickScheduled = { info in
            XCTAssertFalse(info.isSubdivision)
            XCTAssertEqual(info.accent, .accent)
            received += 1
            started.fulfill()
        }

        var settings = MetronomeSettings(bpm: 120, beatsPerMeasure: 4)
        settings.volume = 0
        engine.start(settings: settings)
        wait(for: [started], timeout: 2)

        engine.stop()
        let afterStop = received
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertEqual(received, afterStop, "停止后不应再有 tick 回调")
        XCTAssertGreaterThan(received, 0)
    }

    func testSubdivisionTicks() throws {
        let engine = MetronomeEngine()
        let subdivisionSeen = expectation(description: "subdivision tick")
        subdivisionSeen.assertForOverFulfill = false

        engine.onTickScheduled = { info in
            if info.isSubdivision {
                subdivisionSeen.fulfill()
            }
        }

        var settings = MetronomeSettings(bpm: 60, beatsPerMeasure: 2, subdivision: .eighth)
        settings.volume = 0
        engine.start(settings: settings)
        wait(for: [subdivisionSeen], timeout: 2)
        engine.stop()
    }

    /// 预备拍先按整拍走完，再进入正式小节。
    func testCountInPrecedesPlaying() throws {
        let engine = MetronomeEngine()
        let countInSeen = expectation(description: "count-in tick")
        let playingSeen = expectation(description: "first playing tick")
        countInSeen.assertForOverFulfill = false
        playingSeen.assertForOverFulfill = false
        let lock = NSLock()
        var ticks: [TickInfo] = []

        engine.onTickScheduled = { info in
            lock.lock()
            ticks.append(info)
            lock.unlock()
            if info.isCountIn {
                countInSeen.fulfill()
            } else {
                playingSeen.fulfill()
            }
        }

        // 300 BPM、每小节 1 拍：预备 1 小节只需 0.2s，测试跑得快。
        var settings = MetronomeSettings(bpm: 300, beatsPerMeasure: 1, countInMeasures: 1)
        settings.volume = 0
        engine.start(settings: settings)
        wait(for: [countInSeen, playingSeen], timeout: 3)
        engine.stop()

        lock.lock()
        let snapshot = ticks
        lock.unlock()
        let first = try XCTUnwrap(snapshot.first)
        XCTAssertTrue(first.isCountIn)
        XCTAssertEqual(first.measure, 0)
        XCTAssertEqual(first.beat, 0)
        XCTAssertEqual(first.beatOrdinal, 0)
        let second = try XCTUnwrap(snapshot.dropFirst().first)
        XCTAssertFalse(second.isCountIn)
        XCTAssertEqual(second.beat, 0)
        XCTAssertEqual(second.ordinal, 1)
        XCTAssertEqual(second.beatOrdinal, 1, "预备拍的拍序号要接到正式第 1 拍")
    }

    /// 摆锤用的拍长必须是「拍」的周期，不能被细分缩短；
    /// 且相邻两拍序号连续，视图才能左右交替衔接。
    func testBeatIntervalIgnoresSubdivision() throws {
        let engine = MetronomeEngine()
        let beatsSeen = expectation(description: "two beat ticks")
        beatsSeen.expectedFulfillmentCount = 2
        beatsSeen.assertForOverFulfill = false
        let lock = NSLock()
        var beatTicks: [TickInfo] = []

        engine.onTickScheduled = { info in
            guard !info.isSubdivision else { return }
            lock.lock()
            beatTicks.append(info)
            lock.unlock()
            beatsSeen.fulfill()
        }

        // 150 BPM：拍长 0.4s；八分细分后的 tick 间隔是 0.2s。
        var settings = MetronomeSettings(bpm: 150, beatsPerMeasure: 2, subdivision: .eighth)
        settings.volume = 0
        engine.start(settings: settings)
        wait(for: [beatsSeen], timeout: 3)
        engine.stop()

        lock.lock()
        let snapshot = beatTicks
        lock.unlock()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[0].beatInterval, 0.4, accuracy: 1e-6)
        XCTAssertEqual(snapshot[1].beatInterval, 0.4, accuracy: 1e-6)
        XCTAssertEqual(snapshot[0].beatOrdinal, 0)
        XCTAssertEqual(snapshot[1].beatOrdinal, 1)
    }

    /// 回传的出声时刻必须落在真实时间轴上。
    ///
    /// 曾经把 `playerTime.sampleTime` 当作「距开机秒数」换算 host time，
    /// 导致 uptime ≈ 0；相位视图据此计算时永远被钳在端点，每拍硬翻一次。
    func testTickUptimeTracksWallClock() throws {
        let engine = MetronomeEngine()
        let tick = expectation(description: "tick with plausible uptime")
        tick.assertForOverFulfill = false

        engine.onTickScheduled = { info in
            let delta = info.uptime - ProcessInfo.processInfo.systemUptime
            XCTAssertLessThan(delta, 0.6, "tick 出声时刻不应落在遥远未来")
            XCTAssertGreaterThan(delta, -0.2, "tick 出声时刻不应退化成开机时刻")
            tick.fulfill()
        }

        var settings = MetronomeSettings(bpm: 240, beatsPerMeasure: 4)
        settings.volume = 0
        engine.start(settings: settings)
        wait(for: [tick], timeout: 2)
        engine.stop()
    }

    /// 静音只关掉音频，视觉 tick 仍然照常调度。
    func testMutedStillEmitsTicks() throws {
        let engine = MetronomeEngine()
        let tick = expectation(description: "visual tick while muted")
        tick.assertForOverFulfill = false

        engine.onTickScheduled = { info in
            XCTAssertEqual(info.accent, .accent)
            tick.fulfill()
        }

        var settings = MetronomeSettings(bpm: 300, beatsPerMeasure: 4)
        settings.soundEnabled = false
        engine.start(settings: settings)
        wait(for: [tick], timeout: 2)
        engine.stop()
    }

    /// 变速训练到达目标后自动停止。
    func testTrainingAutoStopsAtTarget() throws {
        let engine = MetronomeEngine()
        let stopped = expectation(description: "auto stop")
        stopped.assertForOverFulfill = false
        let lock = NSLock()
        var bpms: [Double] = []

        engine.onTickScheduled = { info in
            lock.lock()
            bpms.append(info.bpm)
            lock.unlock()
        }
        engine.onAutoStop = { stopped.fulfill() }

        // 118 → 120，每 1 小节 +2，1 拍/小节：第二个小节播完即停。
        var settings = MetronomeSettings(bpm: 118, beatsPerMeasure: 1)
        settings.volume = 0
        settings.training = TempoTraining(
            isEnabled: true,
            targetBPM: 120,
            step: 2,
            measuresPerStep: 1,
            stopAtTarget: true
        )
        engine.start(settings: settings)
        wait(for: [stopped], timeout: 4)

        lock.lock()
        let snapshot = bpms
        lock.unlock()
        XCTAssertEqual(snapshot.first, 118)
        XCTAssertEqual(snapshot.last, 120, "到位小节应按目标速度播放")
    }
}
