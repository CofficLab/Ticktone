import KernelCore
import PluginToast
import ProviderPluginControl
import ProviderPluginManaging

/// 内核装配器 —— 所有 App 共用的内核创建路径。
///
/// 只做三件事：创建隔离的 `KernelCoreContainer` → 注入 context（状态存储、
/// 插件 ID 兼容映射）→ 注册 Provider → 启动 Plugin。**不持有任何静态状态**，
/// 每次调用返回独立实例。
@MainActor
public enum AppKernelAssembler {
    /// 同步装配内核（适用于轻量 App）。
    ///
    /// - Parameters:
    ///   - configuration: App 级装配上下文。
    ///   - providerFactory: 本 App 的 Provider 装配。
    ///   - pluginFactory: 本 App 的 Plugin catalog。
    /// - Returns: 已装配的内核容器（Provider 已注册、Plugin 已启动）。
    public static func makeKernel(
        configuration: AppAssemblyConfiguration = .default,
        providerFactory: any AppProviderFactory,
        pluginFactory: any AppPluginFactory
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        apply(configuration, to: kernel)
        try providerFactory.registerProviders(into: kernel)
        try registerPluginManagement(into: kernel)
        try kernel.start(plugins: pluginFactory.makePlugins() + [ToastSuperPlugin()])
        return kernel
    }

    /// 异步装配内核（适用于需要资源初始化或外部进程的 App）。
    ///
    /// 复用 `KernelCoreContainer.startAsync` 的错误、超时与失败回滚语义。
    ///
    /// - Parameters:
    ///   - configuration: App 级装配上下文。
    ///   - providerFactory: 本 App 的 Provider 装配。
    ///   - pluginFactory: 本 App 的 Plugin catalog。
    ///   - timeout: 每阶段生命周期超时；`nil` 表示不设限。
    /// - Returns: 已装配的内核容器。
    public static func makeKernelAsync(
        configuration: AppAssemblyConfiguration = .default,
        providerFactory: any AppProviderFactory,
        pluginFactory: any AppPluginFactory,
        timeout: KernelLifecycleTimeout? = .default
    ) async throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        apply(configuration, to: kernel)
        try providerFactory.registerProviders(into: kernel)
        try registerPluginManagement(into: kernel)
        try await kernel.startAsync(
            plugins: pluginFactory.makePlugins() + [ToastSuperPlugin()],
            timeout: timeout
        )
        return kernel
    }

    /// 注册插件启停与插件管理 Provider。
    ///
    /// 共享插件包 `LumiPluginPluginManager` 的数据源是 `PluginManaging`
    /// Provider：没有它，设置里的「插件管理」页拿不到插件列表。这里统一
    /// 在所有 App 的公共装配路径上注册，宿主无需各自重复装配。
    ///
    /// `PluginControlling` 负责运行时启停，`PluginManaging` 在其之上提供
    /// 枚举 / 查询 / 卸载 / 重载。二者共享同一个内核实例，状态一致。
    ///
    /// 宿主若已自行注册同名 Provider（例如 Gomoku），保持宿主的实现不动，
    /// 避免重复注册抛 `providerAlreadyRegistered`。
    private static func registerPluginManagement(into kernel: KernelCoreContainer) throws {
        if !kernel.isProviderRegistered((any PluginControlling).self) {
            try kernel.registerProvider(
                (any PluginControlling).self,
                DefaultPluginControlling(kernel: kernel)
            )
        }

        if kernel.isProviderRegistered((any PluginManaging).self) {
            return
        }

        let controlling = kernel.resolveProvider((any PluginControlling).self)
            ?? DefaultPluginControlling(kernel: kernel)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel, controlling: controlling)
        )
    }

    private static func apply(
        _ configuration: AppAssemblyConfiguration,
        to kernel: KernelCoreContainer
    ) {
        if let store = configuration.pluginStateStore {
            kernel.stateStore = store
        } else if !configuration.pluginEnableOverrides.isEmpty {
            kernel.stateStore = InMemoryPluginStateStore(
                initial: configuration.pluginEnableOverrides
            )
        }
        for (newID, legacyID) in configuration.legacyPluginIDAliases {
            kernel.legacyPluginIDAliases[newID] = legacyID
        }
    }
}
