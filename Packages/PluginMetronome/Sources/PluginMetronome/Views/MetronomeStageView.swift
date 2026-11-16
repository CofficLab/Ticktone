import MetronomeCore
import SwiftUI

/// 节拍可视区：BPM 读数、摆锤与拍点指示灯。
///
/// macOS 与 iOS 共用，保证两端的节拍反馈完全一致。
struct MetronomeStageView: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(Int(viewModel.effectiveBPM))")
                    .font(.system(size: 76, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("BPM · \(MetronomeTempo(bpm: viewModel.effectiveBPM).marking)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(Int(viewModel.effectiveBPM)) BPM，\(MetronomeTempo(bpm: viewModel.effectiveBPM).marking)"
            )
            .accessibilityValue(statusText.trimmingCharacters(in: .whitespaces))
            .accessibilityIdentifier("metronome.bpmReadout")

            PendulumView(viewModel: viewModel)

            BeatDotsView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity)
    }

    /// 播放中的小节进度 / 预备拍提示；空闲时留空占位，避免布局跳动。
    private var statusText: String {
        guard viewModel.isPlaying else { return " " }
        if viewModel.isCountingIn {
            let total = viewModel.settings.countInMeasures
            let current = min((viewModel.audibleTick?.measure ?? 0) + 1, max(1, total))
            return "预备 \(current)/\(total)"
        }
        let measure = (viewModel.audibleTick?.measure ?? 0) + 1
        if viewModel.settings.training.isEnabled {
            return "第 \(measure) 小节 · 目标 \(Int(viewModel.settings.training.targetBPM)) BPM"
        }
        return "第 \(measure) 小节"
    }
}

/// 开始 / 停止按钮。
struct MetronomePlayButton: View {
    @ObservedObject var viewModel: MetronomeViewModel
    var height: CGFloat = 52

    var body: some View {
        Button {
            viewModel.toggle()
        } label: {
            Label(
                playLabel,
                systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(MetronomePlayButtonStyle(isPlaying: viewModel.isPlaying))
        .accessibilityHint(viewModel.isPlaying ? "停止节拍" : "开始节拍")
        #if os(macOS)
        .keyboardShortcut(.space, modifiers: [])
        .help("空格键开始或停止")
        #endif
        .accessibilityIdentifier("metronome.playToggle")
    }

    private var playLabel: String {
        if viewModel.isPlaying, viewModel.isCountingIn { return "预备中（点按取消）" }
        return viewModel.isPlaying ? "停止" : "开始"
    }
}

private struct MetronomePlayButtonStyle: ButtonStyle {
    let isPlaying: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isPlaying ? Color.red.opacity(configuration.isPressed ? 0.8 : 1) : Color.accentColor)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
