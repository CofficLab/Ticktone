import Foundation

/// 摆锤角度模型。
///
/// 位置完全由引擎回传的「这一拍的出声时刻」与「到下一拍的时长」推导，
/// 不维护累加状态，也不依赖重复的 SwiftUI 动画，因此不会随时间漂移。
///
/// 每拍从一侧端点出发，用 `cos(π·phase)` 在端点自然减速、反向；
/// 相邻两拍的起始方向相反，所以拍点处位置与速度都连续，不会瞬移。
public enum MetronomePendulum {
    public static let defaultMaxAngleDegrees: Double = 26

    /// 当前摆角（弧度）。奇数拍朝负方向，偶数拍朝正方向。
    ///
    /// - Parameters:
    ///   - now: 当前系统 uptime（与 `tickUptime` 同一坐标系）。
    ///   - tickUptime: 这一拍的实际出声时刻。
    ///   - beatOrdinal: 从开始起的第几拍（含预备拍）。
    ///   - beatInterval: 从这一拍到下一拍的时长（换速段落取下一小节的实际间隔）。
    public static func angle(
        now: TimeInterval,
        tickUptime: TimeInterval,
        beatOrdinal: Int,
        beatInterval: TimeInterval,
        maxAngleDegrees: Double = defaultMaxAngleDegrees
    ) -> Double {
        guard beatInterval > 0 else { return 0 }
        let phase = min(max((now - tickUptime) / beatInterval, 0), 1)
        let direction: Double = beatOrdinal % 2 == 0 ? 1 : -1
        return direction * maxAngleDegrees * Double.pi / 180 * cos(Double.pi * phase)
    }
}
