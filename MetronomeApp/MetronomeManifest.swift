import KernelCore
import LumiFactory
import PluginAbout
import PluginMetronome
import PluginPluginManager
import PluginSettingGeneral
import PluginSettingView
import PluginSettingToolbar
import PluginThemePack
import PluginToast
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import ProviderToast
import ProviderToolbar
import SwiftUI
import WorkbenchRootView

#if os(macOS)
import PluginActivityBar
import PluginCommand
import PluginStorage
import ProviderCommand
#endif

/// Ticktone 的宿主清单：App 与共享装配引擎 LumiFactory 之间的全部差异。
///
/// 装配流水线、窗口壳、启动失败归因由 `LumiFactory` 解释执行；
/// 这里只保留品牌身份、插件清单、存储/主题配置与 iOS 自有壳。
/// 插件 id、存储目录与窗口 id 沿用迁移前取值，延续既有用户数据。
@MainActor
enum MetronomeManifest {
    nonisolated static let settingsWindowID = "metronome.settings"

    /// 共享目录主题白名单（与 ThemePackPlugin 注册同一组）。
    nonisolated static let catalogThemeIDs = [
        "lumi", "sky", "winter", "river", "midnight", "vscode-light",
    ]

    /// 插件与 iOS 主界面共享同一会话状态，避免状态分叉。
    static let viewModel = MetronomeViewModel()

    static var manifest: HostManifest {
        let identity = HostIdentity(
            appName: String(localized: "Metronome", bundle: .main),
            loggerSubsystem: "com.coffic.metronome.app",
            mainWindowID: "metronome.main",
            settingsWindowID: settingsWindowID,
            accessibilityPrefix: "metronome",
            mainWindowMinimumSize: CGSize(width: 760, height: 560),
            mainWindowDefaultSize: CGSize(width: 900, height: 680),
            settingsWindowDefaultSize: CGSize(width: 1000, height: 600)
        )
        var manifest = HostManifest(
            identity: identity,
            makePlugins: { makePlugins() },
            storage: HostStorageConfiguration(stateStorePluginID: "PluginManager"),
            theme: HostThemeConfiguration(
                catalogThemeIDs: catalogThemeIDs,
                storageDirectoryName: "ThemeManager"
            ),
            rootViewLayout: RootViewLayoutConfiguration(showsToolbar: true),
            features: HostFeatures(
                // 齿轮由 SettingsToolbarPlugin 贡献（mac 工具栏 / iOS 导航栏），
                // 不再叠加壳自带的设置按钮。
                showsSettingsToolbarButton: false,
                quitsWhenLastWindowClosed: true
            )
        )
        #if os(macOS)
        manifest.registerProviders = { kernel in
            try kernel.registerProvider((any CommandProviding).self, DefaultCommandProviding())
        }
        #else
        // 移动端根视图自带 NavigationStack，标准壳会再包一层栈；
        // 与 Wakey 同模式：宿主自带完整壳（导航 + 设置 sheet）。
        manifest.makeMainView = { kernel in
            makeMobileMainView(kernel: kernel, identity: identity)
        }
        #endif
        return manifest
    }

    // MARK: - Plugins

    static func makePlugins() -> [any SuperPlugin] {
        var plugins: [any SuperPlugin] = []
        #if os(macOS)
        plugins.append(try! StorageSuperPlugin())
        plugins.append(CommandPlugin())
        #endif
        plugins.append(PluginSettingView(id: "com.coffic.lumi.plugin.setting-view"))
        #if os(macOS)
        plugins.append(SettingsToolbarPlugin(settingsWindowID: settingsWindowID))
        #endif
        plugins.append(SettingGeneralPlugin(configuration: generalSettingsConfiguration))
        #if os(macOS)
        plugins.append(PluginActivityBar())
        #endif
        plugins.append(ThemePackPlugin(themeIDs: catalogThemeIDs))
        plugins.append(PluginPluginManager())
        #if !os(macOS)
        plugins.append(SettingsToolbarPlugin(settingsWindowID: settingsWindowID))
        #endif
        plugins.append(
            AboutPlugin(
                id: "com.coffic.metronome.plugin.about",
                configuration: AboutConfiguration(
                    officialWebsiteURLString: legalWebsite.absoluteString,
                    privacyPolicyURLString: legalPrivacyPolicy.absoluteString,
                    termsOfServiceURLString: legalTermsOfService.absoluteString
                )
            )
        )
        // Metronome 是此宿主的核心能力，不能被用户关闭。
        plugins.append(MetronomePlugin(policy: .required, viewModel: viewModel))
        #if os(macOS)
        // Toast 浮层挂在根视图 overlay 上（装配期根视图已作为 host provider 注册）。
        plugins.append(
            ToastSuperPlugin(
                overlayInstaller: { kernel, center in
                    kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([
                        RootOverlayItem(id: ToastSuperPlugin.overlayID) { content in
                            ToastOverlay(content: content, center: center)
                        },
                    ])
                },
                overlayUninstaller: { kernel in
                    kernel.resolveProvider((any RootViewProviding).self)?
                        .removeOverlays(ids: [ToastSuperPlugin.overlayID])
                }
            )
        )
        #else
        plugins.append(ToastSuperPlugin())
        #endif
        return plugins
    }

    // MARK: - Branding

    nonisolated static let legalWebsite = URL(string: "https://coffic.cn/metronome")!
    nonisolated static let legalPrivacyPolicy = URL(string: "https://coffic.cn/privacy")!
    nonisolated static let legalTermsOfService = URL(string: "https://coffic.cn/terms")!

    private static var generalSettingsConfiguration: GeneralSettingsConfiguration {
        GeneralSettingsConfiguration(
            privacyDescription: String(
                localized: "Your tempo settings and presets stay on this device. Nothing is uploaded.",
                bundle: .main
            ),
            websiteURL: legalWebsite,
            privacyPolicyURL: legalPrivacyPolicy,
            termsOfServiceURL: legalTermsOfService
        )
    }

    // MARK: - iOS Shell

    #if !os(macOS)
    private static func makeMobileMainView(
        kernel: KernelCoreContainer,
        identity: HostIdentity
    ) -> AnyView {
        let feature = MetronomeMobileFeature(viewModel: viewModel)
        guard let navigationBar = kernel.resolveProvider((any IOSNavigationBarProviding).self) else {
            return toastOverlay(AnyView(MetronomeMobileRootView(feature: feature)), kernel: kernel)
        }
        return AnyView(
            IOSSettingsAppShell(
                title: identity.appName,
                mainView: toastOverlay(
                    AnyView(
                        MetronomeMobileNavigationHost(
                            navigationBar: navigationBar,
                            feature: feature
                        )
                    ),
                    kernel: kernel
                ),
                settingsView: makeMobileSettingsView(kernel: kernel),
                navigationBarProvider: navigationBar,
                navigationBarMode: .host
            )
        )
    }

    private static func makeMobileSettingsView(kernel: KernelCoreContainer) -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text(String(localized: "Settings unavailable", bundle: .main)))
        }
        let view = AnyView(settings.makeSettingView())
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return view
        }
        return AnyView(HostThemeView(theme: theme, content: view))
    }

    private static func toastOverlay(_ content: AnyView, kernel: KernelCoreContainer) -> AnyView {
        guard let center = kernel.resolveProvider((any ToastProviding).self) as? ToastCenter else {
            return content
        }
        return AnyView(
            ToastOverlay(content: content, center: center)
                .environment(\.toastProviding, center)
        )
    }
    #endif
}

#if !os(macOS)
/// 把插件贡献的导航栏项挂到移动根视图自己的导航栈内。
@MainActor
private struct MetronomeMobileNavigationHost: View {
    @StateObject private var navigationItems: IOSNavigationBarItemsBridge
    let feature: MetronomeMobileFeature

    init(navigationBar: any IOSNavigationBarProviding, feature: MetronomeMobileFeature) {
        _navigationItems = StateObject(
            wrappedValue: IOSNavigationBarItemsBridge(provider: navigationBar)
        )
        self.feature = feature
    }

    var body: some View {
        MetronomeMobileRootView(
            feature: feature,
            trailingToolbarItems: navigationItems.items
        )
    }
}
#endif