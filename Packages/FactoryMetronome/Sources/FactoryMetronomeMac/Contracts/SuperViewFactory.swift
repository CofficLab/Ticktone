import AppFactoryCore
import KernelCore
import SwiftUI

/// Metronome 宿主的视图工厂契约。
///
/// 集中管理视图组装逻辑：主窗口视图、设置窗口视图以及 LumiUI 主题桥接。
@MainActor
public protocol ViewFactory: AppViewFactory {
    func makeMainView(kernel: KernelCoreContainer) throws -> AnyView
    func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView
}
