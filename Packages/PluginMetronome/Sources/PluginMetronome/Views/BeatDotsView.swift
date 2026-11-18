import MetronomeCore
import SwiftUI

/// 拍点指示灯：每拍一个圆点，首拍更大。
///
/// 当前拍在出声时刻短暂点亮（由引擎按采样时间调度的 tick 驱动）；
/// 点按圆点在「强 / 普通 / 静音」间循环。
struct BeatDotsView: View {
    @ObservedObject var viewModel: MetronomeViewModel

    /// iOS 上点与点之间留 2pt，把省下的宽度让给可点击区域。
    private var spacing: CGFloat {
        #if os(iOS)
        2
        #else
        10
        #endif
    }

    /// 每个拍点的最小点击区域：iOS 保证 44pt 高，macOS 指针精度足够，用 30pt。
    private var hitHeight: CGFloat {
        #if os(iOS)
        44
        #else
        30
        #endif
    }

    /// 12 拍时也要能在一行内放下（iPhone SE 宽 375pt）。
    private var hitWidth: CGFloat {
        #if os(iOS)
        26
        #else
        32
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !viewModel.isPlaying)) { _ in
            // 时间基准取自系统 uptime，与引擎回传的 tick.uptime 同一坐标系。
            let now = ProcessInfo.processInfo.systemUptime
            HStack(spacing: spacing) {
                ForEach(0..<viewModel.settings.beatsPerMeasure, id: \.self) { beat in
                    Button {
                        viewModel.cycleAccent(at: beat)
                    } label: {
                        dot(for: beat, now: now)
                    }
                    .buttonStyle(.plain)
                    .frame(width: hitWidth, height: hitHeight)
                    .contentShape(Rectangle())
                    .accessibilityLabel(helpText(beat: beat))
                    .accessibilityHint("点按在强、普通、静音之间切换")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func dot(for beat: Int, now: TimeInterval) -> some View {
        let accent = viewModel.settings.pattern.accent(at: beat)
        let isLit = isBeatLit(beat, now: now)
        let size: CGFloat = beat == 0 ? 22 : 16
        return Circle()
            .fill(fillColor(accent: accent, isLit: isLit))
            .overlay(
                Circle().stroke(borderColor(accent: accent), lineWidth: accent == .muted ? 1.5 : 0)
            )
            .frame(width: size, height: size)
            .opacity(accent == .muted && !isLit ? 0.35 : 1)
    }

    private func isBeatLit(_ beat: Int, now: TimeInterval) -> Bool {
        guard viewModel.isPlaying,
              let tick = viewModel.lastTick,
              !tick.isSubdivision,
              tick.beat == beat else { return false }
        let elapsed = now - tick.uptime
        return elapsed >= -0.02 && elapsed < 0.12
    }

    private func fillColor(accent: BeatAccent, isLit: Bool) -> Color {
        if isLit {
            return accent == .accent ? .red : .accentColor
        }
        switch accent {
        case .accent: return .red.opacity(0.55)
        case .normal: return .secondary.opacity(0.45)
        case .muted: return .clear
        }
    }

    private func borderColor(accent: BeatAccent) -> Color {
        accent == .muted ? .secondary : .clear
    }

    private func helpText(beat: Int) -> String {
        let level: String
        switch viewModel.settings.pattern.accent(at: beat) {
        case .accent: level = NSLocalizedString("强", bundle: .main, comment: "")
        case .normal: level = NSLocalizedString("普通", bundle: .main, comment: "")
        case .muted: level = NSLocalizedString("静音", bundle: .main, comment: "")
        }
        return String(format: NSLocalizedString("第 %lld 拍：%@（点按切换）", bundle: .main, comment: ""), beat + 1, level)
    }
}
