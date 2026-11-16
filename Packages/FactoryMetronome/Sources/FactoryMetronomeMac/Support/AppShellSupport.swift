#if os(macOS)
import Foundation
import ProviderSettingView

/// Metronome 薄壳 App 支撑。
///
/// 把设置导航的跨层通知名暴露给 App 壳层，使 App 入口无需直接
/// `import ProviderSettingView`（架构检查 D 规则：App 入口不得导入
/// Plugin/Provider 包）。条目选中逻辑已下沉到
/// `DefaultViewFactory.makeSettingsView` 内的 `onReceive` 处理，
/// 壳层只需监听同一通知打开设置窗口。
public enum MetronomeAppShell {
    /// 打开设置窗口的通知（与 `SettingViewNavigation.openSettingsNotification` 同值）。
    public static let openSettingsNotification = SettingViewNavigation.openSettingsNotification
}
#endif
