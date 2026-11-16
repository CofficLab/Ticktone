import KernelCore
import PluginToast
import ProviderToast
import SwiftUI

/// Renders shared Lumi Toast notices above an app's main window and exposes the
/// same provider to SwiftUI content that wants to send a toast.
@MainActor
public enum AppToastPresentation {
    public static func overlay<Content: View>(
        _ content: Content,
        kernel: KernelCoreContainer
    ) -> AnyView {
        let center = kernel.resolveProvider((any ToastProviding).self) as? ToastCenter

        guard let center else {
            return AnyView(content)
        }

        return AnyView(
            ToastOverlay(content: content, center: center)
                .environment(\.toastProviding, center)
        )
    }
}
