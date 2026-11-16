#if !os(macOS)
import FactoryMetronomeIOS
import SwiftUI

/// iOS 应用入口：只做组装，场景根视图由 Factory 提供。
struct MetronomeIOSApp: App {
    var body: some Scene {
        WindowGroup {
            FactoryMetronomeIOS.makeMobileAppRootView()
        }
    }
}
#endif
