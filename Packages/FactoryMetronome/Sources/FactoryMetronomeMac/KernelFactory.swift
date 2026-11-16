#if os(macOS)
import AppFactoryCore
import KernelCore
import PluginRootView
import SwiftUI

/// KernelFactory —— 内核工厂。
///
/// 负责创建 KernelCore 内核：通过 `AppKernelAssembler` 这一统一路径装配
/// Metronome 所需的 Provider，并启动专用插件目录。视图组装委托
/// `DefaultViewFactory`。
@MainActor
public enum KernelFactory {
    /// 创建 KernelCore 内核，装配并注册 Metronome 所需 Provider。
    ///
    /// - Parameter configuration: App 级装配上下文（默认使用 Metronome 的 appID）。
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    public static func makeKernel(
        configuration: AppAssemblyConfiguration? = nil
    ) throws -> KernelCoreContainer {
        let providerFactory = DefaultProviderFactory()
        return try AppKernelAssembler.makeKernel(
            configuration: configuration ?? FactoryMetronomeMac.defaultConfiguration,
            providerFactory: providerFactory,
            pluginFactory: RootViewPluginFactory(providerFactory: providerFactory)
        )
    }

    /// 异步插件目录的装配入口。
    public static func makeKernelAsync(
        configuration: AppAssemblyConfiguration? = nil
    ) async throws -> KernelCoreContainer {
        let providerFactory = DefaultProviderFactory()
        return try await AppKernelAssembler.makeKernelAsync(
            configuration: configuration ?? FactoryMetronomeMac.defaultConfiguration,
            providerFactory: providerFactory,
            pluginFactory: RootViewPluginFactory(providerFactory: providerFactory)
        )
    }

    // MARK: - Main View Assembly

    /// 创建内核并组装完整主视图。
    public static func makeMainView() throws -> AnyView {
        try makeMainView(kernel: makeKernel())
    }

    /// 使用已装配的内核组装主视图（共享内核时使用）。
    public static func makeMainView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory = DefaultViewFactory()
    ) throws -> AnyView {
        try viewFactory.makeMainView(kernel: kernel)
    }

    // MARK: - Settings View Assembly

    /// 创建内核并返回设置视图。
    public static func makeSettingsView() throws -> AnyView {
        try makeSettingsView(kernel: makeKernel())
    }

    /// 使用已装配的内核返回设置视图。
    public static func makeSettingsView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory = DefaultViewFactory()
    ) throws -> AnyView {
        try viewFactory.makeSettingsView(kernel: kernel)
    }
}

@MainActor
private struct RootViewPluginFactory: AppPluginFactory {
    let providerFactory: DefaultProviderFactory

    func makePlugins() -> [any SuperPlugin] {
        [RootViewPlugin(provider: providerFactory.makeRootViewProvider())]
            + DefaultPluginFactory().makePlugins()
    }
}
#endif
