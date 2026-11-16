import Foundation
import LumiLocalizationKit

/// 「设置 → 通用 → 隐私」里的隐私说明文案。
///
/// macOS 与 iOS 是同一款 App（universal purchase），两端的隐私说明必须是
/// 同一句话、同一份译文，因此文案与取词都收敛到这一层共享代码里。
///
/// 取词只认宿主自有的 catalog：查不到 key 时 `LumiLocalization` 会按设计
/// 回退成 key 本身（英文原文），中文界面下就显示成一段英文。
public enum MetronomePrivacyCopy {
    /// catalog key。英文原文，同时是「查不到译文时」的回退值。
    public static let key = "Your tempo settings and presets stay on this device. Nothing is uploaded."

    /// 文案所在的 bundle（宿主自有，不依赖任何插件的 catalog）。
    public static var bundle: Bundle { MetronomeSharedText.bundle }

    /// 按语言解析隐私说明（跟随系统语言偏好）。
    public static func description(locale: Locale = .current) -> String {
        MetronomeSharedText.string(key, locale: locale)
    }
}
