import Foundation

/// 节拍器速度（BPM）。
///
/// 取值范围 30–300：低于 30 没有实际练习意义，高于 300 的区分度
/// 对音乐练习没有可感知的价值，因此不向上扩展。
public struct MetronomeTempo: Equatable, Codable, Sendable {
    public static let minimum: Double = 30
    public static let maximum: Double = 300

    public private(set) var bpm: Double

    public init(bpm: Double) {
        self.bpm = Self.clamp(bpm)
    }

    public static func clamp(_ value: Double) -> Double {
        min(max(value, minimum), maximum)
    }

    public mutating func set(_ value: Double) {
        bpm = Self.clamp(value)
    }

    /// 每拍秒数。
    public var beatInterval: TimeInterval { 60.0 / bpm }

    /// 意大利速度术语（传统机械节拍器刻度）。
    public var marking: String {
        switch bpm {
        case ..<40: return "Grave"
        case ..<60: return "Largo"
        case ..<66: return "Larghetto"
        case ..<76: return "Adagio"
        case ..<108: return "Andante"
        case ..<120: return "Moderato"
        case ..<156: return "Allegro"
        case ..<176: return "Vivace"
        case ..<200: return "Presto"
        default: return "Prestissimo"
        }
    }
}
