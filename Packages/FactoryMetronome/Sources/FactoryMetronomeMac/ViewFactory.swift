import LumiThemePack
import Foundation
import KernelCore
import LumiUI
import ProviderContentView
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import ProviderToolbar
import SwiftUI

#if os(macOS)
import ProviderActivityBar
import ProviderRailView
#endif

/// 默认 `ViewFactory` 实现：使用内核已注册的 Provider 组装主视图与设置视图。
///
/// 视图组装逻辑（工具栏 / ActivityBar / Rail / 内容区注入、LumiUI 主题桥接）
/// 集中在此；`KernelFactory.makeMainView(kernel:)` 等入口
/// 委托本实现，宿主可通过自定义 `ViewFactory` 覆盖视图组装行为。
@MainActor
public struct DefaultViewFactory: ViewFactory {
    public init() {}

    /// 使用已装配的内核组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    public func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text(ProviderPlaceholderText.rootViewNotRegistered))
        }

        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            Self.syncLumiTheme(theme)
        }

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            rootView.setToolbarView(toolbar.makeToolbarView())
        }
        #if os(macOS)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            rootView.setActivityBarView(activityBar.makeActivityBarView())
        }
        if let rail = kernel.resolveProvider((any RailViewProviding).self) {
            rootView.setRailView(rail.makeRailView())
            rootView.setRailViewVisible(rail.hasVisibleTabs)
            rootView.bindRailViewVisibility(to: rail)
            rootView.bindRailViewWidth(
                to: rail,
                onResize: { width in rail.saveCurrentWidth(width) }
            )
        }
        #endif
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            rootView.setContentView(contentView.makeContentView())
        }
        return themed(rootView.makeRootView(), kernel: kernel)
    }

    /// 使用已装配的内核返回设置视图。
    ///
    /// 先把选中主题桥接到 LumiUI 主题体系，避免首帧渲染时 LumiUI 组件读到
    /// 未配置的默认主题而闪烁。
    public func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text(ProviderPlaceholderText.settingViewNotRegistered))
        }

        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            Self.syncLumiTheme(theme)
        }

        // 跨层设置导航：`lumi.openSettings` 通知里的条目选中逻辑在本视图内处理，
        // App 壳层只需监听同一通知打开设置窗口。
        let settingsView = AnyView(settings.makeSettingView()
            .onReceive(NotificationCenter.default.publisher(
                for: SettingViewNavigation.openSettingsNotification
            )) { notification in
                guard let entryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String,
                      settings.entries.contains(where: { $0.id == entryID }) else { return }
                settings.selectEntry(id: entryID)
            })
        return themed(settingsView, kernel: kernel)
    }

    // MARK: - LumiUI Theme Bridging

    /// 把 `ThemeProviding` 选中的主题桥接到 LumiUI 主题体系。
    static func syncLumiTheme(_ provider: any ThemeProviding) {
        guard let selected = provider.selectedTheme else { return }
        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = SystemAppearanceResolver.effectiveColorScheme
        }

        ResolvedSystemColorScheme.current = colorScheme

        let chrome = LumiPaletteChromeTheme(theme: selected, colorScheme: colorScheme)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))
    }

    // MARK: - Theme Application

    private func themed(_ view: AnyView, kernel: KernelCoreContainer) -> AnyView {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return view
        }
        return AnyView(ThemeHostingView(theme: theme, content: view))
    }
}

/// 主题感知的视图包装。
@MainActor
private struct ThemeHostingView<Content: View>: View {
    let theme: any ThemeProviding
    let content: Content

    @StateObject private var themeObservation: ThemeObservationModel
    @State private var refreshTick = false

    init(theme: any ThemeProviding, content: Content) {
        self.theme = theme
        self.content = content
        _themeObservation = StateObject(wrappedValue: ThemeObservationModel(theme: theme))
    }

    var body: some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .background(backgroundColor)
            .onAppear { DefaultViewFactory.syncLumiTheme(theme) }
            .onReceive(themeObservation.$revision) { _ in
                refreshTick.toggle()
                DefaultViewFactory.syncLumiTheme(theme)
            }
    }

    private var preferredColorScheme: ColorScheme? {
        switch theme.selectedTheme?.appearanceKind ?? .system {
        case .dark: return .dark
        case .light: return .light
        case .system: return ResolvedSystemColorScheme.current
        }
    }

    private var backgroundColor: Color {
        guard let selected = theme.selectedTheme else {
            #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
            #else
            return Color(uiColor: .systemBackground)
            #endif
        }

        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = ResolvedSystemColorScheme.current
        }
        return selected.palette.backgroundMedium.color(colorScheme: colorScheme)
    }
}

@MainActor
private final class ThemeObservationModel: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ThemeProvidingObserverHandle)?

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }
}
