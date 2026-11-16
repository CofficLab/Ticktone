import Foundation

/// Provider 未注册时展示的占位文案。
///
/// 文案取自本模块自带的 catalog：`pluginLocalization` 绑的是模块资源 bundle，
/// 里面才有这张 Localizable 表。不要改回 `pluginLocalizationMain`
/// （`Bundle.main`）——宿主 App bundle 自己没有 Localizable 表，查不到时
/// `LumiLocalization` 会按设计回退成 key 本身，中文界面下就显示英文。
public enum ProviderPlaceholderText {
    /// 主视图的 RootViewProviding 未注册。
    public static var rootViewNotRegistered: String {
        pluginLocalization.string("RootViewProviding not registered")
    }

    /// 设置视图的 SettingViewProviding 未注册。
    public static var settingViewNotRegistered: String {
        pluginLocalization.string("SettingViewProviding not registered")
    }
}
