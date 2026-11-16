import KernelCore
import ProviderContentView
import ProviderDocsView
import SwiftUI

/// 节拍器插件 —— 采样级精准的练习节拍器。
///
/// 插件在 `onBoot` 阶段把主视图注入 `ContentViewProviding` 的内容区；
/// 宿主（Metronome 专用 App）以 `.required` 策略装配本插件。
@MainActor
public final class MetronomePlugin: SuperPlugin {
    public nonisolated static let pluginID = "com.coffic.metronome.plugin.metronome"

    public let id: String
    public let order = 890
    public let metadata: PluginMetadata

    /// 插件级唯一的会话状态，主视图直接引用它。
    private let sharedViewModel: MetronomeViewModel

    public var name: String { MetronomeLocalization.string("Metronome") }

    /// - Parameters:
    ///   - policy: 启用策略由宿主决定。
    ///   - viewModel: 外部注入的会话状态；不传时插件自行创建。
    public init(
        policy: PluginEnablePolicy = .disabledByDefault,
        viewModel: MetronomeViewModel? = nil
    ) {
        id = Self.pluginID
        sharedViewModel = viewModel ?? MetronomeViewModel()
        metadata = PluginMetadata(
            id: Self.pluginID,
            name: MetronomeLocalization.string("Metronome"),
            description: "A precise metronome with subdivisions, accents and presets.",
            category: .feature,
            stage: .preview,
            policy: policy
        )
    }

    // MARK: - Lifecycle

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { MetronomeAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { MetronomeManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?
            .setContentView(AnyView(MetronomeMainView(viewModel: sharedViewModel)))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        sharedViewModel.stop()
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Mobile

    #if os(iOS)
    public func makeMobileRootView() -> AnyView {
        AnyView(MetronomeMobileRootView(feature: MetronomeMobileFeature(viewModel: sharedViewModel)))
    }
    #endif
}
