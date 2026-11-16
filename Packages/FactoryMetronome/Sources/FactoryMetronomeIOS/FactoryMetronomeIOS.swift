#if os(iOS)
import AppFactoryCore
import FactoryMetronomeShared
import KernelCore
import LumiThemePack
import LumiUI
import MetronomeCore
import PluginAbout
import PluginMetronome
import PluginPluginManager
import PluginRootView
import PluginSettingGeneral
import PluginSettingToolbar
import PluginSettingView
import PluginStorage
import PluginThemePack
import ProviderContentView
import ProviderDocsView
import ProviderRootView
import ProviderSettingView
import ProviderSettingsHost
import ProviderTheme
import ProviderToolbar
import SwiftUI

/// Metronome 的 iOS 组装入口：移动端业务 façade。
///
/// App 只调用组装入口；移动会话在根视图中以 `@StateObject` 持有，
/// 设置页、主题、关于/帮助与插件管理统一由 Lumi Kernel 提供。
@MainActor
public enum FactoryMetronomeIOS {
    public static let settingsWindowID = "metronome.settings"

    public static func makeMobileAppRootView() -> AnyView {
        let feature = MetronomeMobileFeature()
        do {
            let kernel = try makeSettingsKernel(viewModel: feature.viewModel)
            guard let navigationBar = kernel.resolveProvider((any IOSNavigationBarProviding).self) else {
                return AppToastPresentation.overlay(
                    AnyView(MetronomeMobileRootView(feature: feature)),
                    kernel: kernel
                )
            }
            let navigationItems = IOSNavigationBarItemsBridge(provider: navigationBar)
            return AnyView(IOSSettingsAppShell(
                title: MetronomeSharedText.string("Metronome"),
                mainView: AppToastPresentation.overlay(
                    AnyView(MetronomeNavigationHost(
                        navigationItems: navigationItems,
                        feature: feature
                    )),
                    kernel: kernel
                ),
                settingsView: makeSettingsView(kernel: kernel),
                navigationBarProvider: navigationBar,
                navigationBarMode: .host
            ))
        } catch {
            return AnyView(MetronomeMobileRootView(feature: feature))
        }
    }

    private static func makeSettingsKernel(viewModel: MetronomeViewModel) throws -> KernelCoreContainer {
        try AppKernelAssembler.makeKernel(
            configuration: AppAssemblyConfiguration(appID: "com.coffic.metronome"),
            providerFactory: IOSSettingsProviderFactory(),
            pluginFactory: IOSSettingsPluginFactory(viewModel: viewModel)
        )
    }

    private static func makeSettingsView(kernel: KernelCoreContainer) -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text(MetronomeSharedText.string("Settings unavailable")))
        }
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return AnyView(settings.makeSettingView())
        }
        Self.syncLumiTheme(theme)
        return AnyView(
            IOSSettingsThemedHost(
                theme: theme,
                content: AnyView(settings.makeSettingView())
            )
        )
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
}

// MARK: - Navigation Host

/// 把插件贡献的 iOS 导航栏项挂到 App 自己的导航栈。
@MainActor
private struct MetronomeNavigationHost: View {
    @ObservedObject private var navigationItems: IOSNavigationBarItemsBridge
    let feature: MetronomeMobileFeature

    init(
        navigationItems: IOSNavigationBarItemsBridge,
        feature: MetronomeMobileFeature
    ) {
        _navigationItems = ObservedObject(wrappedValue: navigationItems)
        self.feature = feature
    }

    var body: some View {
        MetronomeMobileRootView(
            feature: feature,
            trailingToolbarItems: navigationItems.items
        )
    }
}

// MARK: - Settings Theme Host

@MainActor
private struct IOSSettingsThemedHost: View {
    let theme: any ThemeProviding
    let content: AnyView

    @StateObject private var observation: ThemeObservationModel
    @State private var refreshTick = false

    init(theme: any ThemeProviding, content: AnyView) {
        self.theme = theme
        self.content = content
        _observation = StateObject(wrappedValue: ThemeObservationModel(theme: theme))
    }

    var body: some View {
        content
            .appThemedAppearance()
            .onAppear { FactoryMetronomeIOS.syncLumiTheme(theme) }
            .onReceive(observation.$revision) { _ in
                refreshTick.toggle()
                FactoryMetronomeIOS.syncLumiTheme(theme)
            }
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

@MainActor
private struct IOSSettingsProviderFactory: AppProviderFactory {
    func registerProviders(into kernel: KernelCoreContainer) throws {
        try kernel.registerProvider((any SettingViewProviding).self, DefaultSettingViewProviding())
        try kernel.registerProvider((any DocsViewProviding).self, DefaultDocsViewProviding())
        try kernel.registerProvider((any ThemeProviding).self, DefaultThemeProviding())
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try kernel.registerProvider((any RootViewProviding).self, LumiRootViewProvider())
        try kernel.registerProvider(
            (any IOSNavigationBarProviding).self,
            DefaultIOSNavigationBarProviding()
        )
    }
}

@MainActor
private struct IOSSettingsPluginFactory: AppPluginFactory {
    let viewModel: MetronomeViewModel

    func makePlugins() -> [any SuperPlugin] {
        [
            PluginSettingView(id: "com.coffic.lumi.plugin.setting-view"),
            SettingGeneralPlugin(
                configuration: GeneralSettingsConfiguration(
                    privacyDescription: MetronomePrivacyCopy.description(),
                    websiteURL: MetronomeLegalLinks.website,
                    privacyPolicyURL: MetronomeLegalLinks.privacyPolicy,
                    termsOfServiceURL: MetronomeLegalLinks.termsOfService
                )
            ),
            ThemePackPlugin(
                themeIDs: [
                    "lumi",
                    "sky",
                    "winter",
                    "river",
                    "midnight",
                    "vscode-light",
                ]
            ),
            PluginPluginManager(),
            SettingsToolbarPlugin(settingsWindowID: FactoryMetronomeIOS.settingsWindowID),
            // 共享远程包 LumiPluginAbout：设置界面的「关于」入口。
            // 页面含 Coffic Lab 旗下产品 + Metronome 自己的官网与法律链接。
            AboutPlugin(
                id: "com.coffic.metronome.plugin.about",
                configuration: AboutConfiguration(
                    officialWebsiteURLString: MetronomeLegalLinks.website.absoluteString,
                    privacyPolicyURLString: MetronomeLegalLinks.privacyPolicy.absoluteString,
                    termsOfServiceURLString: MetronomeLegalLinks.termsOfService.absoluteString
                )
            ),
            // Metronome 是此宿主的核心能力，不能被用户关闭；
            // 与主界面共享同一个 ViewModel，避免状态分叉。
            MetronomePlugin(policy: .required, viewModel: viewModel),
        ]
    }
}
#endif
