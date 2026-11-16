import KernelCore

/// 所有 App 共用的 Provider 装配契约（平台中立）。
///
/// 只负责“把该 App 需要的 Provider 注册进内核”，具体的 Provider 创建
/// 方法留在各 App 的 `ProviderFactory` 协议中（见 Task 3 迁移说明）。
/// 内核实例由 `AppKernelAssembler` 创建后传入；本协议不持有任何静态状态。
@MainActor
public protocol AppProviderFactory {
    /// 将本 App 需要的 Provider 注册进内核。
    ///
    /// 通过 `kernel.registerProvider(...)` 注册；重复注册会抛
    /// `KernelCoreError.providerAlreadyRegistered`。
    func registerProviders(into kernel: KernelCoreContainer) throws
}
