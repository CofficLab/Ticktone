import SwiftUI

/// 应用入口：按平台选择对应的实现。
/// - macOS: MetronomeMacApp
/// - iOS / iPadOS: MetronomeIOSApp
@main
struct MetronomeApp: App {
    var body: some Scene {
        #if os(macOS)
        MetronomeMacApp().body
        #else
        MetronomeIOSApp().body
        #endif
    }
}
