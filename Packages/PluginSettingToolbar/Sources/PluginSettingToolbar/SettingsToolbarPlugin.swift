import KernelCore
import LumiUI
import ProviderSettingView
import ProviderToolbar
import SwiftUI

/// 设置工具栏插件（KernelCore 生态）。
///
/// 在宿主标题栏工具栏右侧注入一个「设置」按钮（齿轮图标），点击打开宿主
/// 指定的设置窗口。通过 `settingsWindowID` 解耦宿主窗口标识：
/// 任何 KernelCore 体系 App 装配本插件时传入自己的设置窗口 id 即可，
/// 因此插件可被多个 App 复用（五子棋、点格棋、国际象棋等）。
///
/// 按钮样式与 Lumi 工具栏的设置按钮（`AppIconButton(systemImage: "gearshape")`）
/// **完全一致**：复用 LumiUI 的 `AppIconButton`（默认 `.compact`：图标 +
/// 圆角背景 + hover/按压反馈 + 缩放动画）。hover 提示由工具栏宿主统一
/// 按 `ToolbarItem.title` 提供。
@MainActor
public final class SettingsToolbarPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.setting-toolbar"
    public let order = 950
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.setting-toolbar",
        name: "Settings Toolbar",
        description: "Adds a settings button to the host toolbar.",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    private let settingsWindowID: String

    public init(settingsWindowID: String) {
        self.settingsWindowID = settingsWindowID
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
#if os(macOS)
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            return
        }
        let itemID = "\(id).toolbar"
        toolbar.addToolbarItems([
            ToolbarItem(
                id: itemID,
                title: LumiUILocalization.string("Settings"),
                placement: .trailing,
                category: .global,
                order: 300
            ) {
                SettingsToolbarButton(windowID: self.settingsWindowID)
            }
        ])
#elseif os(iOS)
        guard let navigationBar = kernel.resolveProvider(
            (any IOSNavigationBarProviding).self
        ) else {
            return
        }
        let itemID = "\(id).navigation-bar"
        navigationBar.addNavigationBarItems([
            IOSNavigationBarItem(
                id: itemID,
                title: LumiUILocalization.string("Settings"),
                placement: .trailing,
                category: .global,
                order: 300
            ) {
                Button {
                    NotificationCenter.default.post(
                        name: SettingViewNavigation.openSettingsNotification,
                        object: nil
                    )
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(LumiUILocalization.string("Settings"))
            }
        ])
#endif
#if os(macOS)
        try kernel.trackContribution {
            toolbar.removeToolbarItems(ids: [itemID])
        }
#elseif os(iOS)
        try kernel.trackContribution {
            navigationBar.removeNavigationBarItems(ids: [itemID])
        }
#endif
    }
}

private struct SettingsToolbarButton: View {
    @Environment(\.openWindow) private var openWindow
    let windowID: String

    var body: some View {
        AppIconButton(systemImage: "gearshape") {
            openWindow(id: windowID)
        }
    }
}
