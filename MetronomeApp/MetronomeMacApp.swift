#if os(macOS)
import FactoryMetronomeMac
import KernelCore
import SwiftUI

struct MetronomeMacApp: App {
    private let kernel: KernelCoreContainer
    private let mainView: AnyView
    private let settingsView: AnyView
    @Environment(\.openWindow) private var openWindow

    init() {
        if let assembledKernel = try? FactoryMetronomeMac.makeKernel() {
            kernel = assembledKernel
            mainView = (try? FactoryMetronomeMac.makeMainView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble main view"))
            settingsView = (try? FactoryMetronomeMac.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble settings view"))
        } else {
            kernel = KernelCoreContainer()
            mainView = AnyView(Text("Failed to assemble main view"))
            settingsView = AnyView(Text("Failed to assemble settings view"))
        }
    }

    var body: some Scene {
        WindowGroup("节拍匠", id: "metronome.main") {
            mainView
                .onReceive(NotificationCenter.default.publisher(
                    for: MetronomeAppShell.openSettingsNotification
                )) { _ in
                    openWindow(id: FactoryMetronomeMac.settingsWindowID)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 680)
        .commands {
            AppCommands(kernel: kernel)
        }

        Window("设置", id: FactoryMetronomeMac.settingsWindowID) {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1000, height: 600)
    }
}
#endif
