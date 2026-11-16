import MetronomeCore
import SwiftUI

/// macOS 主视图：可视区 + 控件面板。
struct MetronomeMainView: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 20) {
                    MetronomeStageView(viewModel: viewModel)
                    MetronomePlayButton(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity)

                Divider()

                MetronomeControlPanel(viewModel: viewModel)
                    .frame(width: 320)
            }
            .padding(28)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 760, minHeight: 560)
        .accessibilityIdentifier("metronome.mainView")
    }
}
