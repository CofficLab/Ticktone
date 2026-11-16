import Combine
import Foundation
import KernelCore

/// 异步内核持有器 —— 需要资源初始化或外部进程的 App 使用。
///
/// 只包装 `KernelCoreContainer`（不包装任何私有内核）。App 壳层持有本
/// 引用，`bootstrap()` 完成后用 `kernel` 交给 Factory 组装主/设置视图；
/// 失败时 `errorMessage` 可观测，App 壳层只负责显示启动失败状态。
@MainActor
public final class AppKernelReference: ObservableObject {
    /// 装配完成后的内核；未完成或失败时为 nil。
    @Published public private(set) var kernel: KernelCoreContainer?

    /// 启动失败信息（`LocalizedError.errorDescription` 优先）。
    @Published public private(set) var errorMessage: String?

    /// 是否已开始装配（幂等保护）。
    public private(set) var hasStarted: Bool = false

    private let configuration: AppAssemblyConfiguration
    private let providerFactory: any AppProviderFactory
    private let pluginFactory: any AppPluginFactory
    private let timeout: KernelLifecycleTimeout?

    public init(
        configuration: AppAssemblyConfiguration = .default,
        providerFactory: any AppProviderFactory,
        pluginFactory: any AppPluginFactory,
        timeout: KernelLifecycleTimeout? = .default
    ) {
        self.configuration = configuration
        self.providerFactory = providerFactory
        self.pluginFactory = pluginFactory
        self.timeout = timeout
    }

    /// 异步装配内核（幂等：只执行一次）。
    public func bootstrap() async {
        guard !hasStarted else { return }
        hasStarted = true
        do {
            kernel = try await AppKernelAssembler.makeKernelAsync(
                configuration: configuration,
                providerFactory: providerFactory,
                pluginFactory: pluginFactory,
                timeout: timeout
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
