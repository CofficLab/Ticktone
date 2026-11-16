import Foundation

/// 点击音色组。
///
/// 每组音色按「强拍 / 普通拍 / 细分」三个级别渲染不同的点击声。
public enum ClickSoundSet: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 经典机械节拍器声：短促高频 click。
    case classic
    /// 电子蜂鸣：柔和的正弦 beep。
    case electronic
    /// 木鱼/木块声：带噪声质感的敲击。
    case wood

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: return "经典"
        case .electronic: return "电子"
        case .wood: return "木鱼"
        }
    }
}

/// 点击声级别。
public enum ClickKind: String, Codable, Sendable {
    case accent
    case normal
    case subdivision
}
