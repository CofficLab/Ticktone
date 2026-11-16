#if os(iOS)
import Combine
import SwiftUI

/// Metronome 移动端会话层。
///
/// 拥有移动会话：共享业务状态（`MetronomeViewModel`）。
/// 所有局部页面只接收同一个 feature 实例。
@MainActor
public final class MetronomeMobileFeature: ObservableObject {
    public let viewModel: MetronomeViewModel
    private var observation: AnyCancellable?

    public init(viewModel: MetronomeViewModel = MetronomeViewModel()) {
        self.viewModel = viewModel
        observation = viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
#endif
