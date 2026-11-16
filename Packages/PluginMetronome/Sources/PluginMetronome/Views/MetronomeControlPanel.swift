import MetronomeCore
import SwiftUI

/// 主控件面板：速度、拍号、细分、音色、音量、选项与预设。
struct MetronomeControlPanel: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @State private var presetName = ""
    @State private var showsPresetNaming = false

    private var signatureBinding: Binding<MetronomeTimeSignature> {
        Binding(
            get: { viewModel.settings.timeSignature },
            set: { viewModel.setTimeSignature($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            tempoSection
            signatureSection
            subdivisionSection
            soundSection
            optionsSection
            practiceSection
            presetsSection
        }
    }

    // MARK: - 速度

    private var tempoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("速度").font(.subheadline.weight(.semibold))
                if viewModel.isTempoLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(tempoSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Button {
                    viewModel.setBPM(viewModel.settings.bpm - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: controlHitSize, height: controlHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("减小速度")

                Slider(
                    value: Binding(
                        get: { viewModel.settings.bpm },
                        set: { viewModel.setBPM($0) }
                    ),
                    in: MetronomeTempo.minimum...MetronomeTempo.maximum
                )
                .accessibilityLabel("速度")
                .accessibilityValue("\(Int(viewModel.settings.bpm)) BPM")

                Button {
                    viewModel.setBPM(viewModel.settings.bpm + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: controlHitSize, height: controlHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("增大速度")

                Button {
                    viewModel.tap()
                } label: {
                    Text("Tap")
                        .frame(minHeight: controlHitSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("敲击测速")
                .accessibilityHint("连续点按两次以上，用点击节奏设定速度")
            }
            .disabled(viewModel.isTempoLocked)
            .opacity(viewModel.isTempoLocked ? 0.5 : 1)

            if viewModel.isTempoLocked {
                Text("播放中已锁定速度与拍号，停止后可调整。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 图标类控件的点击区域边长：iOS 44pt，macOS 28pt。
    private var controlHitSize: CGFloat {
        #if os(iOS)
        44
        #else
        28
        #endif
    }

    private var tempoSummary: String {
        let bpm = Int(viewModel.settings.bpm)
        if viewModel.settings.training.isEnabled {
            return "起始 \(bpm) BPM"
        }
        return "\(bpm) BPM · \(MetronomeTempo(bpm: viewModel.settings.bpm).marking)"
    }

    // MARK: - 拍号

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("拍号").font(.subheadline.weight(.semibold))
            Picker("拍号", selection: signatureBinding) {
                ForEach(MetronomeTimeSignature.common, id: \.id) { signature in
                    Text(signature.displayName).tag(signature)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(viewModel.isTempoLocked)
        }
    }

    // MARK: - 细分

    private var subdivisionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("细分").font(.subheadline.weight(.semibold))
            Picker("细分", selection: Binding(
                get: { viewModel.settings.subdivision },
                set: { viewModel.setSubdivision($0) }
            )) {
                ForEach(MetronomeSubdivision.allCases) { subdivision in
                    Text(subdivision.displayName).tag(subdivision)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 音色

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("音色").font(.subheadline.weight(.semibold))
            Picker("音色", selection: Binding(
                get: { viewModel.settings.soundSet },
                set: { viewModel.setSoundSet($0) }
            )) {
                ForEach(ClickSoundSet.allCases) { set in
                    Text(set.displayName).tag(set)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 选项

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: viewModel.settings.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.volume) },
                        set: { viewModel.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("音量")
                .accessibilityValue("\(Int(viewModel.settings.volume * 100))%")
                .disabled(!viewModel.settings.soundEnabled)
            }
            Toggle("静音（只保留视觉）", isOn: Binding(
                get: { !viewModel.settings.soundEnabled },
                set: { viewModel.setSoundEnabled(!$0) }
            ))
            #if os(iOS)
            Toggle("触觉反馈", isOn: Binding(
                get: { viewModel.settings.hapticsEnabled },
                set: { viewModel.setHapticsEnabled($0) }
            ))
            #endif
            Toggle("演出锁定（播放中锁定速度与拍号）", isOn: Binding(
                get: { viewModel.settings.tempoLockEnabled },
                set: { viewModel.setTempoLockEnabled($0) }
            ))
        }
    }

    // MARK: - 练习辅助（预备拍 + 变速训练）

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("练习辅助").font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("开始前预备拍")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("开始前预备拍", selection: Binding(
                    get: { viewModel.settings.countInMeasures },
                    set: { viewModel.setCountInMeasures($0) }
                )) {
                    Text("关闭").tag(0)
                    Text("1 小节").tag(1)
                    Text("2 小节").tag(2)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("变速训练", isOn: Binding(
                    get: { viewModel.settings.training.isEnabled },
                    set: { viewModel.setTrainingEnabled($0) }
                ))

                Group {
                    HStack {
                        Text("目标速度").font(.caption)
                        Spacer()
                        Text("\(Int(viewModel.settings.training.targetBPM)) BPM")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.training.targetBPM },
                            set: { viewModel.setTrainingTarget($0) }
                        ),
                        in: MetronomeTempo.minimum...MetronomeTempo.maximum,
                        step: 1
                    )
                    HStack {
                        Text("每 \(viewModel.settings.training.measuresPerStep) 小节")
                            .font(.caption)
                        Spacer()
                        Stepper("", value: Binding(
                            get: { viewModel.settings.training.measuresPerStep },
                            set: { viewModel.setTrainingMeasuresPerStep($0) }
                        ), in: 1...8)
                        .labelsHidden()
                    }
                    HStack {
                        Text("每次调整 \(Int(viewModel.settings.training.step)) BPM")
                            .font(.caption)
                        Spacer()
                        Stepper("", value: Binding(
                            get: { viewModel.settings.training.step },
                            set: { viewModel.setTrainingStep($0) }
                        ), in: 1...20, step: 1)
                        .labelsHidden()
                    }
                    Text(trainingHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Toggle("到达目标后自动停止", isOn: Binding(
                        get: { viewModel.settings.training.stopAtTarget },
                        set: { viewModel.setTrainingStopAtTarget($0) }
                    ))
                    .font(.caption)
                }
                .disabled(!viewModel.settings.training.isEnabled)
                .opacity(viewModel.settings.training.isEnabled ? 1 : 0.5)
            }
            // 演出锁定同样覆盖变速训练，否则播放中仍能通过训练参数改变当前速度。
            .disabled(viewModel.isTempoLocked)
            .opacity(viewModel.isTempoLocked ? 0.5 : 1)
        }
    }

    private var trainingHint: String {
        let training = viewModel.settings.training
        let base = viewModel.settings.bpm
        if abs(training.targetBPM - base) < 0.0001 {
            return "目标与起始速度相同；拖动目标滑杆即可设置加速或减速。"
        }
        let sign = training.targetBPM > base ? "+" : "-"
        return "从 \(Int(base)) BPM 起，每 \(training.measuresPerStep) 小节 \(sign)\(Int(training.step))，至 \(Int(training.targetBPM)) BPM。"
    }

    // MARK: - 预设

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("预设").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    presetName = "预设 \(viewModel.presets.count + 1)"
                    showsPresetNaming = true
                } label: {
                    Text("保存当前")
                        .frame(minHeight: controlHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("命名并保存当前速度、拍号等设置")
            }
            if viewModel.presets.isEmpty {
                Text("还没有预设。调好速度与拍号后点「保存当前」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.presets) { preset in
                    HStack {
                        Button {
                            viewModel.applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                Text("\(Int(preset.settings.bpm)) BPM · \(preset.settings.timeSignature.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: controlHitSize, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("加载此预设")
                        Spacer()
                        Button {
                            viewModel.deletePreset(preset)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: controlHitSize, height: controlHitSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除预设「\(preset.name)」")
                    }
                }
            }
        }
        .alert("命名预设", isPresented: $showsPresetNaming) {
            TextField("名称", text: $presetName)
            Button("保存") {
                let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.savePreset(name: name.isEmpty ? "预设 \(viewModel.presets.count + 1)" : name)
            }
            Button("取消", role: .cancel) {}
        }
    }
}
