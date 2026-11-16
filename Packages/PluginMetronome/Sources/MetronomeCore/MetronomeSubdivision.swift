import Foundation

/// 拍内细分节奏。
public enum MetronomeSubdivision: Int, CaseIterable, Codable, Sendable, Identifiable {
    /// 不细分，只打拍点。
    case none = 1
    /// 八分音符（每拍 2 下）。
    case eighth = 2
    /// 三连音（每拍 3 下）。
    case triplet = 3
    /// 十六分音符（每拍 4 下）。
    case sixteenth = 4

    public var id: Int { rawValue }

    /// 每拍细分数（即 tick 频率相对拍频的倍数）。
    public var multiplier: Int { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "无"
        case .eighth: return "八分"
        case .triplet: return "三连音"
        case .sixteenth: return "十六分"
        }
    }
}
