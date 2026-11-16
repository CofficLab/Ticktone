import Foundation
import LumiLocalizationKit

/// 宿主共享文案（macOS 与 iOS 共用同一份 catalog）。
///
/// 取词只认本模块自带的 catalog：宿主 App bundle 自己没有 Localizable 表，
/// 查别的 bundle 查不到 key 时，`LumiLocalization` 会按设计回退成 key 本身
/// （英文原文），中文界面下就显示成英文。
public enum MetronomeSharedText {
    /// 文案所在 bundle（宿主自有，不依赖任何插件的 catalog）。
    public static var bundle: Bundle { .module }

    /// 按语言解析宿主共享文案（跟随系统语言偏好）。
    public static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, table: "Localizable", locale: locale)
    }
}
