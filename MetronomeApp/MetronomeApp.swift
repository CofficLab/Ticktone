import LumiFactory
import SwiftUI

/// 应用入口：只持有启动器与场景拓扑，装配差异全部在 `MetronomeManifest`。
@main
struct MetronomeApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(HostAppDelegate.self) private var appDelegate
    #endif

    init() {
        #if os(macOS)
        HostAppDelegate.prepareForLaunch()
        appDelegate.bootstrapper = MetronomeAssembly.bootstrapper
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        HostMacScenes(bootstrapper: MetronomeAssembly.bootstrapper).body
        #else
        WindowGroup(String(localized: "Metronome", bundle: .main), id: "metronome.main") {
            HostRootWindowView(bootstrapper: MetronomeAssembly.bootstrapper)
        }
        #endif
    }
}

@MainActor
enum MetronomeAssembly {
    static let bootstrapper = KernelBootstrapper(manifest: MetronomeManifest.manifest)
}