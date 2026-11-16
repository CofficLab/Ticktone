import Foundation

/// Tap Tempo 计算器：根据连续点击间隔估算 BPM。
///
/// 只保留最近 `maxIntervals` 个间隔取平均；某次点击与上次间隔超过
/// `resetInterval` 秒视为新的序列，清空历史。
public struct TapTempoCalculator: Sendable {
    /// 与上次点击间隔超过该值时重置序列。
    public var resetInterval: TimeInterval = 2.0
    /// 参与平均的最大间隔数（即最近 5 次点击产生 4 个间隔）。
    public var maxIntervals = 4

    private var lastTap: TimeInterval?
    private var intervals: [TimeInterval] = []

    public init() {}

    /// 记录一次点击，返回估算的 BPM；首次点击或重置后返回 nil。
    public mutating func tap(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Double? {
        defer { lastTap = time }
        guard let last = lastTap else { return nil }
        let interval = time - last
        guard interval > 0 else { return nil }
        if interval > resetInterval {
            intervals = []
            return nil
        }
        intervals.append(interval)
        if intervals.count > maxIntervals {
            intervals.removeFirst()
        }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        return MetronomeTempo.clamp(60.0 / average)
    }

    public mutating func reset() {
        lastTap = nil
        intervals = []
    }
}
