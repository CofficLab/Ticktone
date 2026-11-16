import PluginMetronome
import FactoryMetronomeShared
import KernelCore
import PluginAbout

#if os(macOS)
import PluginActivityBar
import PluginCommand
import PluginPluginManager
import PluginSettingGeneral
import PluginSettingView
import PluginSettingToolbar
import PluginStorage
import PluginThemePack
#endif

/// Metronome 的专用插件目录。
///
/// 只装配 Metronome 工作流和宿主 UI 所需的基础插件。Lumi 的 LLM、Agent、
/// 项目、聊天、开发工具和其他实验性插件不会进入这个应用的进程。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    /// 本宿主的插件标识。共享包默认使用 Lumi 的命名空间，这里显式覆盖，
    /// 以保持 Metronome 既有的设置项与数据目录不变。
    public nonisolated static let metronomePluginID =
        "com.coffic.metronome.plugin.metronome"

    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        #if os(iOS)
        return [MetronomePlugin(policy: .required)]
        #else
        [
            // 基础服务必须先于业务插件启动。
            try! StorageSuperPlugin(),
            CommandPlugin(),
            PluginSettingView(id: "com.coffic.lumi.plugin.setting-view"),
            SettingsToolbarPlugin(settingsWindowID: FactoryMetronomeMac.settingsWindowID),
            // 隐私说明走共享层的宿主 catalog（FactoryMetronomeShared 自带
            // Localizable 表）：macOS 与 iOS 是同一款 App，两端必须是同一句
            // 同一译。不要改回 PluginMetronome 的本地化 —— 那个 helper 查的是
            // PluginMetronome 的 Localizable 表，里面没有这个 key，
            // 缺失时会原样回退显示英文。
            SettingGeneralPlugin(
                configuration: GeneralSettingsConfiguration(
                    privacyDescription: MetronomePrivacyCopy.description(),
                    websiteURL: MetronomeLegalLinks.website,
                    privacyPolicyURL: MetronomeLegalLinks.privacyPolicy,
                    termsOfServiceURL: MetronomeLegalLinks.termsOfService
                )
            ),
            PluginActivityBar(),
            ThemePackPlugin(
                themeIDs: [
                    "lumi",          // 森林墨：低饱和暖色，跟随系统明暗（默认）
                    "sky",           // 清朗天蓝：通透浅底，跟随系统明暗
                    "winter",        // 静谧霜蓝：冷静克制，跟随系统明暗
                    "river",         // 通透水蓝：清爽，适合长时间排版
                    "midnight",      // 午夜幽蓝：固定暗色，夜间校对稿件
                    "vscode-light",  // 固定亮色：印刷稿校对的低干扰底色
                ]
            ),
            // 插件管理：向设置界面贡献"插件管理"入口，查看/启用/禁用已注册插件。
            //
            // 零配置即可：本宿主的插件策略全是 required / alwaysOn
            // （`isConfigurable` 为 false），插件管理页必然是一个永远为空的
            // 列表，共享插件包会自动跳过注册该入口。宿主将来加入可配置插件时，
            // 入口会自动出现，无需回来改这里。
            PluginPluginManager(),
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
            // Metronome 是此宿主的核心能力，不能被用户关闭。
            MetronomePlugin(policy: .required),
        ]
        #endif
    }
}
