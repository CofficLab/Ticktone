import KernelCore
import SwiftUI

/// 所有 App 共用的视图装配契约（平台中立）。
///
/// 主窗口与设置窗口必须接收同一个 kernel 实例；本协议不包含任何
/// Lumi-specific RootView / Rail / Toolbar 逻辑——那些留在各 App 的
/// `ViewFactory` 具体实现中。
@MainActor
public protocol AppViewFactory {
    /// 使用已装配的内核组装完整主视图。
    ///
    /// - Parameter kernel: 已装配的 `KernelCoreContainer`（主/设置窗口共享同一实例）。
    /// - Returns: 已装配的根视图（`AnyView`）。
    func makeMainView(kernel: KernelCoreContainer) throws -> AnyView

    /// 使用已装配的内核返回设置视图。
    ///
    /// 无设置界面的 App 可返回 `UnsupportedSettingsView` 或由
    /// `AppViewFactory` 提供占位实现。
    ///
    /// - Parameter kernel: 已装配的 `KernelCoreContainer`。
    /// - Returns: 已装配的设置视图（`AnyView`）。
    func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView
}

/// 无设置界面的 App 使用的占位视图。
@MainActor
public struct UnsupportedSettingsView: View {
    public let appName: String

    public init(appName: String) {
        self.appName = appName
    }

    public var body: some View {
        Text("\(appName) has no settings")
            .frame(minWidth: 320, minHeight: 200)
    }
}

/// AppViewFactory 的默认实现：主视图必需，设置视图返回占位。
@MainActor
public struct DefaultAppViewFactory: AppViewFactory {
    public let appName: String
    private let mainViewProvider: @MainActor (KernelCoreContainer) throws -> AnyView

    public init(
        appName: String,
        mainViewProvider: @escaping @MainActor (KernelCoreContainer) throws -> AnyView
    ) {
        self.appName = appName
        self.mainViewProvider = mainViewProvider
    }

    public func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try mainViewProvider(kernel)
    }

    public func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        AnyView(UnsupportedSettingsView(appName: appName))
    }
}
