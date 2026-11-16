import Foundation

/// 屏幕闪光的滚动限流：任意 1 秒内最多允许 N 次。
///
/// 用于高频节拍下的光敏安全保护：节拍再快，闪光也不会超过每秒 3 次。
public struct FlashRateLimiter {
    public let maxPerSecond: Int
    private var recentUptimes: [TimeInterval] = []

    public init(maxPerSecond: Int = 3) {
        self.maxPerSecond = max(1, maxPerSecond)
    }

    /// 传入一次闪光候选时刻；返回是否允许触发，并记录获准的时刻。
    public mutating func shouldAllow(at uptime: TimeInterval) -> Bool {
        recentUptimes.removeAll { uptime - $0 >= 1.0 }
        guard recentUptimes.count < maxPerSecond else { return false }
        recentUptimes.append(uptime)
        return true
    }

    public mutating func reset() {
        recentUptimes.removeAll()
    }
}
