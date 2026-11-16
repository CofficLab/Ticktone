#if os(macOS)
import AppFactoryCore
import KernelCore
import SwiftUI

/// Metronome 的 macOS 组装入口：内核、主视图与设置视图。
@MainActor
public enum FactoryMetronomeMac {
    /// 设置窗口 ID（宿主用）。
    public static let settingsWindowID = "metronome.settings"

    /// Metronome 的默认装配上下文。
    public static var defaultConfiguration: AppAssemblyConfiguration {
        AppAssemblyConfiguration(appID: "com.coffic.metronome")
    }

    /// 装配内核（Provider + Plugin 目录）。
    public static func makeKernel(
        configuration: AppAssemblyConfiguration? = nil
    ) throws -> KernelCoreContainer {
        try KernelFactory.makeKernel(configuration: configuration)
    }

    /// 使用已装配的内核组装主视图。
    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        AppToastPresentation.overlay(try KernelFactory.makeMainView(kernel: kernel), kernel: kernel)
    }

    /// 使用已装配的内核组装设置视图。
    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}
#endif
