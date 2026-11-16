import Foundation

/// 变速训练：按小节自动调整 BPM（提速练习的核心工具）。
///
/// 例如从 80 BPM 起、每 2 小节加 5、目标 120：练习者不用反复手动拖滑杆，
/// 也不会因为「改速度」打断练习节奏。算法放在 Core 里，引擎只负责按
/// 小节边界取用，便于单元测试。
public struct TempoTraining: Equatable, Codable, Sendable {
    public var isEnabled: Bool
    /// 目标速度。
    public var targetBPM: Double
    /// 每次调整的幅度（BPM）。
    public var step: Double
    /// 每多少个完整小节调整一次。
    public var measuresPerStep: Int
    /// 到达目标后自动停止。
    public var stopAtTarget: Bool

    public init(
        isEnabled: Bool = false,
        targetBPM: Double = 120,
        step: Double = 5,
        measuresPerStep: Int = 2,
        stopAtTarget: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.targetBPM = MetronomeTempo.clamp(targetBPM)
        self.step = max(1, step)
        self.measuresPerStep = max(1, measuresPerStep)
        self.stopAtTarget = stopAtTarget
    }

    /// 第 `measure` 个完整小节（0 起）应使用的 BPM。
    /// 目标低于起始速度时自动转为减速；到达目标后保持。
    public func bpm(base: Double, measure: Int) -> Double {
        guard isEnabled else { return base }
        // 解码旧存档时不会经过 init 的钳制，这里再兜底一次，避免除零或原地踏步。
        let measuresPerStep = max(1, measuresPerStep)
        let step = max(1, step)
        let direction: Double = targetBPM >= base ? 1 : -1
        let steps = measure / measuresPerStep
        let candidate = base + direction * step * Double(steps)
        let clamped = direction > 0 ? min(candidate, targetBPM) : max(candidate, targetBPM)
        return MetronomeTempo.clamp(clamped)
    }

    /// 当前 BPM 是否已经到达目标（用于自动停止与 UI 提示）。
    public func hasReachedTarget(base: Double, currentBPM: Double) -> Bool {
        guard isEnabled else { return false }
        return abs(currentBPM - targetBPM) < 0.0001
    }
}
