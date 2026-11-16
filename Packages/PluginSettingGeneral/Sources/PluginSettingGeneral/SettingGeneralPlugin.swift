import KernelCore
import LumiUI
import ProviderCommand
import ProviderDocsView
import ProviderSettingView
import SwiftUI
import LumiLoggingKit
import os

/// 设置 - 通用 插件
///
/// 为共享内核中的 `SettingViewProviding` 注册「通用」入口。应用元数据与
/// 说明书从宿主和共享 Provider 读取；应用专属操作通过配置按需注入。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`
/// 与 `DocsViewProviding`，用 `addEntries(_:)`（追加语义）注册入口，
/// 不覆盖其他插件贡献的入口。
@MainActor
public final class SettingGeneralPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.shared.plugin.setting-general", category: "SettingGeneral")
    public let id = "com.coffic.shared.plugin.setting-general"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.shared.plugin.setting-general",
        name: "通用设置",
        description: "向共享设置视图注册通用入口，可注入应用专属信息与操作。",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 版本字符串提供器；默认读取 App bundle 版本，可注入以便测试。
    private let versionProvider: @MainActor () -> String?
    private let configuration: GeneralSettingsConfiguration

    public init(
        versionProvider: @escaping @MainActor () -> String? = { AppVersion.current },
        configuration: GeneralSettingsConfiguration = .init()
    ) {
        self.versionProvider = versionProvider
        self.configuration = configuration
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // Settings are host-owned; without a settings provider there is no
            // destination for either the entry or its menu command.
            return
        }

        kernel.resolveProvider((any CommandProviding).self)?.registerCommandGroup(
            CommandMenuGroup(
                id: "\(id).commands",
                name: "Settings",
                items: [
                    CommandItem(
                        id: "\(id).openSettings",
                        title: SettingGeneralLocalization.string("Settings...", bundle: .module),
                        shortcut: ",",
                        modifiers: .command
                    ) {
                        NotificationCenter.default.post(
                            name: SettingViewNavigation.openSettingsNotification,
                            object: nil,
                            userInfo: [
                                SettingViewNavigation.entryIDUserInfoKey: "general",
                            ]
                        )
                    },
                ],
                placement: .appMenu
            )
        )

        // 捕获 docs provider 引用，供详情视图读取。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)
        let configuration = self.configuration

        let entry = SettingEntryItem(
            id: "general",
            title: SettingGeneralLocalization.string("General", bundle: .module),
            systemImage: "gearshape",
            order: 1,
            group: SettingEntryGroup(
                id: "general",
                title: SettingGeneralLocalization.string("General", bundle: .module),
                order: 20
            )
        ) { [versionProvider, docsProvider, configuration] in
            GeneralSettingsDetailView(
                version: versionProvider(),
                docsProvider: docsProvider,
                configuration: configuration
            )
        }

        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any CommandProviding).self)?
            .unregisterCommandGroup(id: "\(id).commands")
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["general"])
    }
}
