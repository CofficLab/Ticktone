import MetronomeCore
import SwiftUI

/// 节拍可视区：BPM 读数、摆锤、拍点指示灯与舞台屏幕闪光。
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
        // 用 overlay 而不是 ZStack：闪光层只为覆盖舞台，不能参与尺寸计算，
        // 否则它会把舞台撑满整列，macOS 上会把「开始」按钮挤出窗口。
        .overlay { flashOverlay }
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

    /// 强拍出声后 80ms 内在舞台区域闪一层与当前外观反差的色层（可在设置中关闭）。
    ///
    /// 用 `Color.primary` 而不是固定白色：浅色外观下为深色闪层、深色外观下为白色闪层，
    /// 避免白底上的白色闪光几乎不可见。这是纯视图层的屏幕视觉脉冲，不调用相机/设备闪光灯。
    @ViewBuilder
    private var flashOverlay: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60.0,
            paused: !viewModel.isPlaying || !viewModel.settings.flashEnabled
        )) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            Color.primary
                .opacity(flashOpacity(now: now))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func flashOpacity(now: TimeInterval) -> Double {
        guard viewModel.isPlaying,
              viewModel.settings.flashEnabled,
              let tick = viewModel.flashTick,
              tick.accent == .accent,
              !tick.isSubdivision else { return 0 }
        let elapsed = now - tick.uptime
        guard elapsed >= 0, elapsed < 0.08 else { return 0 }
        return 0.28 * (1 - elapsed / 0.08)
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
