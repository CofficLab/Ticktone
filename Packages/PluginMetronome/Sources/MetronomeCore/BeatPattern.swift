import Foundation

/// 单个拍点的重音级别。
public enum BeatAccent: Int, Codable, Sendable, CaseIterable {
    /// 强拍（重音）。
    case accent = 2
    /// 普通拍。
    case normal = 1
    /// 静音（该拍不出声，只保留视觉提示）。
    case muted = 0

    /// 点按拍点指示灯时在三个级别间循环。
    public var next: BeatAccent {
        switch self {
        case .accent: return .normal
        case .normal: return .muted
        case .muted: return .accent
        }
    }
}

/// 一小节内各拍的重音模式。
public struct BeatPattern: Equatable, Codable, Sendable {
    public private(set) var accents: [BeatAccent]

    public init(accents: [BeatAccent]) {
        self.accents = accents.isEmpty ? [.accent] : accents
    }

    /// 默认模式：首拍强音，其余普通。
    public static func `default`(beatsPerMeasure: Int) -> BeatPattern {
        BeatPattern(accents: [.accent] + Array(repeating: .normal, count: max(0, beatsPerMeasure - 1)))
    }

    public var count: Int { accents.count }

    public func accent(at beat: Int) -> BeatAccent {
        accents[beat % accents.count]
    }

    /// 循环切换某拍的重音级别。
    public mutating func cycleAccent(at beat: Int) {
        guard accents.indices.contains(beat) else { return }
        accents[beat] = accents[beat].next
    }

    /// 拍号变化时调整模式长度，尽量保留已有设置。
    public mutating func resize(to beatsPerMeasure: Int) {
        let count = max(1, beatsPerMeasure)
        if accents.count < count {
            accents += Array(repeating: .normal, count: count - accents.count)
        } else if accents.count > count {
            accents = Array(accents.prefix(count))
            // 保证小节内至少有一个出声的重拍。
            if accents.allSatisfy({ $0 == .muted }) {
                accents[0] = .accent
            }
        }
    }
}
