import Foundation

/// 拍号。
///
/// `beatsPerMeasure` 是每小节的拍数，`beatUnit` 是分母（4 = 四分音符为一拍，
/// 8 = 八分音符为一拍）。对节拍器而言只有拍数影响打点，分母仅作展示。
public struct MetronomeTimeSignature: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var beatsPerMeasure: Int
    public var beatUnit: Int

    public init(beatsPerMeasure: Int, beatUnit: Int) {
        self.beatsPerMeasure = max(1, beatsPerMeasure)
        self.beatUnit = beatUnit
    }

    public var id: String { "\(beatsPerMeasure)/\(beatUnit)" }

    public var displayName: String { id }

    /// 常用拍号预设（含复合拍 6/8、9/8、12/8 与混合拍 5/4、7/8）。
    public static let common: [MetronomeTimeSignature] = [
        .init(beatsPerMeasure: 2, beatUnit: 4),
        .init(beatsPerMeasure: 3, beatUnit: 4),
        .init(beatsPerMeasure: 4, beatUnit: 4),
        .init(beatsPerMeasure: 5, beatUnit: 4),
        .init(beatsPerMeasure: 6, beatUnit: 8),
        .init(beatsPerMeasure: 7, beatUnit: 8),
        .init(beatsPerMeasure: 9, beatUnit: 8),
        .init(beatsPerMeasure: 12, beatUnit: 8),
    ]
}
