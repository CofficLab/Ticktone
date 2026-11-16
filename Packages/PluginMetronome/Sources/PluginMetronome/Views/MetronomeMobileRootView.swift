#if os(iOS)
import LumiUI
import MetronomeCore
import SwiftUI

/// iOS 根视图：导航栈 + 可视区 + 控件面板。
///
/// 导航栈由本视图自己创建，插件贡献的导航栏项（设置齿轮）必须挂在
/// **栈级** toolbar 上，外层 `.toolbar` 传不进来。
public struct MetronomeMobileRootView: View {
    @ObservedObject private var feature: MetronomeMobileFeature
    @ObservedObject private var viewModel: MetronomeViewModel
    private let trailingToolbarItems: [AnyView]

    public init(
        feature: MetronomeMobileFeature,
        trailingToolbarItems: [AnyView] = []
    ) {
        _feature = ObservedObject(wrappedValue: feature)
        _viewModel = ObservedObject(wrappedValue: feature.viewModel)
        self.trailingToolbarItems = trailingToolbarItems
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MetronomeStageView(viewModel: viewModel)
                    MetronomePlayButton(viewModel: viewModel, height: 58)
                    MetronomeControlPanel(viewModel: viewModel)
                }
                // iPad 上限制内容宽度并居中：避免滑杆与分段控件被拉成整屏宽。
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(MetronomeLocalization.string("Metronome"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 面板较长，滚动到下方时仍能直接开始/停止。
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggle()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    }
                    .accessibilityLabel(viewModel.isPlaying ? "停止" : "开始")
                    .accessibilityHint(viewModel.isPlaying ? "停止节拍" : "开始节拍")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(Array(trailingToolbarItems.enumerated()), id: \.offset) { _, item in
                        item
                    }
                }
            }
        }
        .appThemedAppearance()
        .alert("节拍匠已暂停", isPresented: Binding(
            get: { viewModel.pauseNotice != nil },
            set: { isPresented in
                if !isPresented { viewModel.clearPauseNotice() }
            }
        )) {
            Button("知道了", role: .cancel) {
                viewModel.clearPauseNotice()
            }
        } message: {
            Text(viewModel.pauseNotice ?? "")
        }
    }
}
#endif
