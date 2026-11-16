import MetronomeCore
import XCTest
@testable import PluginMetronome

/// 会话层测试：覆盖用户真正会做的操作（调速度、换拍号、切重音、开始/停止）。
@MainActor
final class MetronomeViewModelTests: XCTestCase {
    private func makeViewModel() -> MetronomeViewModel {
        let suite = "MetronomeViewModelTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return MetronomeViewModel(defaults: defaults)
    }

    func testBPMClampAndPersistence() {
        let viewModel = makeViewModel()
        viewModel.setBPM(10)
        XCTAssertEqual(viewModel.settings.bpm, MetronomeTempo.minimum)
        viewModel.setBPM(500)
        XCTAssertEqual(viewModel.settings.bpm, MetronomeTempo.maximum)
        viewModel.setBPM(120)
        XCTAssertEqual(MetronomeSettings.load(defaults: UserDefaults(suiteName: "MetronomeViewModelTests")!).bpm, 120)
    }

    func testTimeSignatureResizesAccents() {
        let viewModel = makeViewModel()
        viewModel.setTimeSignature(MetronomeTimeSignature(beatsPerMeasure: 7, beatUnit: 8))
        XCTAssertEqual(viewModel.settings.beatsPerMeasure, 7)
        XCTAssertEqual(viewModel.settings.accents.count, 7)
        XCTAssertEqual(viewModel.settings.accents.first, .accent)
    }

    func testCycleAccentAndPreset() {
        let viewModel = makeViewModel()
        viewModel.cycleAccent(at: 1)
        XCTAssertEqual(viewModel.settings.pattern.accent(at: 1), .muted)
        viewModel.savePreset(name: "练习")
        XCTAssertEqual(viewModel.presets.count, 1)
        viewModel.setBPM(200)
        viewModel.applyPreset(viewModel.presets[0])
        XCTAssertEqual(viewModel.settings.bpm, 100)
        viewModel.deletePreset(viewModel.presets[0])
        XCTAssertTrue(viewModel.presets.isEmpty)
    }

    func testStartEmitsTickAndStops() async throws {
        let viewModel = makeViewModel()
        viewModel.setVolume(0)
        viewModel.start()
        XCTAssertTrue(viewModel.isPlaying)

        // 等引擎回传第一拍（前瞻约 0.25s）。
        let deadline = Date().addingTimeInterval(2)
        while viewModel.lastTick == nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotNil(viewModel.lastTick)
        XCTAssertEqual(viewModel.lastTick?.beat, 0)
        XCTAssertEqual(viewModel.lastTick?.accent, .accent)

        viewModel.stop()
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertNil(viewModel.lastTick)
    }

    func testSoundAndCountInSettingsPersist() {
        let viewModel = makeViewModel()
        viewModel.setSoundEnabled(false)
        viewModel.setCountInMeasures(2)
        viewModel.setTempoLockEnabled(true)

        let reloaded = MetronomeSettings.load(defaults: UserDefaults(suiteName: "MetronomeViewModelTests")!)
        XCTAssertFalse(reloaded.soundEnabled)
        XCTAssertEqual(reloaded.countInMeasures, 2)
        XCTAssertTrue(reloaded.tempoLockEnabled)

        viewModel.setCountInMeasures(9)
        XCTAssertEqual(viewModel.settings.countInMeasures, 2, "预备小节上限为 2")
    }

    func testCountInMarksPlayingState() {
        let viewModel = makeViewModel()
        viewModel.setVolume(0)
        viewModel.setCountInMeasures(1)
        viewModel.start()
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertTrue(viewModel.isCountingIn)
        viewModel.stop()
        XCTAssertFalse(viewModel.isCountingIn)
    }

    func testTempoLockBlocksChangesWhilePlaying() {
        let viewModel = makeViewModel()
        viewModel.setVolume(0)
        viewModel.setBPM(100)
        viewModel.setTempoLockEnabled(true)
        viewModel.start()
        XCTAssertTrue(viewModel.isTempoLocked)

        viewModel.setBPM(200)
        XCTAssertEqual(viewModel.settings.bpm, 100, "锁定期间速度不应改变")
        viewModel.setTimeSignature(MetronomeTimeSignature(beatsPerMeasure: 7, beatUnit: 8))
        XCTAssertEqual(viewModel.settings.beatsPerMeasure, 4, "锁定期间拍号不应改变")

        viewModel.stop()
        // 停止后恢复可编辑。
        viewModel.setBPM(200)
        XCTAssertEqual(viewModel.settings.bpm, 200)
    }

    func testTrainingSettingsClamp() {
        let viewModel = makeViewModel()
        viewModel.setTrainingEnabled(true)
        viewModel.setTrainingTarget(500)
        XCTAssertEqual(viewModel.settings.training.targetBPM, MetronomeTempo.maximum)
        viewModel.setTrainingStep(0)
        XCTAssertEqual(viewModel.settings.training.step, 1)
        viewModel.setTrainingMeasuresPerStep(0)
        XCTAssertEqual(viewModel.settings.training.measuresPerStep, 1)
        XCTAssertTrue(viewModel.settings.training.isEnabled)
    }
}
