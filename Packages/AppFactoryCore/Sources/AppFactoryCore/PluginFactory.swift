import KernelCore

/// 所有 App 共用的 Plugin 装配契约（平台中立）。
///
/// 每个 App 的 Factory 通过本协议声明它实际需要的插件目录；
/// 依赖排序与生命周期由 `KernelCoreContainer.start(plugins:)` /
/// `startAsync(plugins:)` 负责，本协议不做自动发现。
@MainActor
public protocol AppPluginFactory {
    /// 产出本宿主实际需要启动的插件。
    ///
    /// catalog 必须：顺序稳定、由 metadata dependency 表达真实依赖、
    /// 对可选 Plugin 标注 `.optional`、对不可运行时缺失的业务 Plugin
    /// 标注 `.required`。
    func makePlugins() -> [any SuperPlugin]
}
