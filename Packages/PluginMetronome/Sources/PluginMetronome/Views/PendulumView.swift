import MetronomeCore
import SwiftUI

/// 摆锤视图：与节拍同步左右摆动。
///
/// 时基来自引擎回传的 `audibleTick`（已在拍点实际出声时更新），
/// 每帧按「这一拍到下一拍的相位」推导角度，不维护累加时间，
/// 因此不会与真实节拍漂移。
struct PendulumView: View {
    @ObservedObject var viewModel: MetronomeViewModel

    /// 最大摆角（度）。
    private let maxAngle = MetronomePendulum.defaultMaxAngleDegrees

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !viewModel.isPlaying)) { _ in
            // 只负责刷新画面，时间基准仍取自系统 uptime，与引擎同一坐标系。
            let angle = currentAngle(now: ProcessInfo.processInfo.systemUptime)
            Canvas { context, size in
                draw(context: &context, size: size, angle: angle)
            }
        }
        .frame(minHeight: 120, maxHeight: 170)
        .accessibilityHidden(true)
    }

    /// 当前摆角（弧度）：每拍从一侧端点摆到另一侧，拍点处自然反向。
    private func currentAngle(now: TimeInterval) -> Double {
        guard viewModel.isPlaying, let tick = viewModel.audibleTick else { return 0 }
        return MetronomePendulum.angle(
            now: now,
            tickUptime: tick.uptime,
            beatOrdinal: tick.beatOrdinal,
            beatInterval: tick.beatInterval,
            maxAngleDegrees: maxAngle
        )
    }

    private func draw(context: inout GraphicsContext, size: CGSize, angle: Double) {
        let pivot = CGPoint(x: size.width / 2, y: 14)
        let length = max(20, min(size.height - 34, size.width * 0.42))
        let tip = CGPoint(
            x: pivot.x + sin(angle) * length,
            y: pivot.y + cos(angle) * length
        )

        // 摆杆
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: tip)
        context.stroke(arm, with: .color(.secondary), lineWidth: 3)

        // 刻度弧（以轴心为圆心，向下摆动的轨迹）
        var arc = Path()
        arc.addArc(
            center: pivot,
            radius: length,
            startAngle: .degrees(90 + maxAngle + 6),
            endAngle: .degrees(90 - maxAngle - 6),
            clockwise: true
        )
        context.stroke(arc, with: .color(.secondary.opacity(0.25)), lineWidth: 1)

        // 锤头
        let ball = CGRect(x: tip.x - 11, y: tip.y - 11, width: 22, height: 22)
        context.fill(Path(ellipseIn: ball), with: .color(viewModel.settings.pattern.accent(at: 0) == .muted ? .secondary : .red))

        // 轴心
        let hub = CGRect(x: pivot.x - 4, y: pivot.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: hub), with: .color(.secondary))
    }
}
