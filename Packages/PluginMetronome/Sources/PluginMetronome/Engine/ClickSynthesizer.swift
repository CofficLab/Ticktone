import AVFoundation
import MetronomeCore

/// 离线合成点击声 PCM buffer。
///
/// 采样级精度的前提是所有声音都预先渲染成 buffer，播放时只做
/// `scheduleBuffer`，避免运行时合成引入抖动。
enum ClickSynthesizer {
    /// 为当前采样率渲染全部音色 × 级别的点击声。
    /// - Parameter channelCount: 必须与 player node 的 output format 一致，
    ///   否则 `scheduleBuffer` 会因声道数不匹配直接触发断言。
    static func makeBuffers(sampleRate: Double, channelCount: AVAudioChannelCount) -> [ClickSoundSet: [ClickKind: AVAudioPCMBuffer]] {
        var result: [ClickSoundSet: [ClickKind: AVAudioPCMBuffer]] = [:]
        for set in ClickSoundSet.allCases {
            var perSet: [ClickKind: AVAudioPCMBuffer] = [:]
            for kind in [ClickKind.accent, .normal, .subdivision] {
                perSet[kind] = render(spec: spec(set: set, kind: kind), sampleRate: sampleRate, channelCount: channelCount)
            }
            result[set] = perSet
        }
        return result
    }

    private struct ClickSpec {
        /// 主频（Hz）。
        var frequency: Double
        /// 时长（秒）。
        var duration: Double
        /// 峰值增益。
        var gain: Float
        /// 指数衰减系数，越大衰减越快。
        var decay: Double
        /// 噪声混入比例（木鱼声用）。
        var noiseMix: Float
    }

    private static func spec(set: ClickSoundSet, kind: ClickKind) -> ClickSpec {
        switch (set, kind) {
        case (.classic, .accent):
            return ClickSpec(frequency: 4000, duration: 0.012, gain: 0.9, decay: 900, noiseMix: 0)
        case (.classic, .normal):
            return ClickSpec(frequency: 3000, duration: 0.012, gain: 0.7, decay: 900, noiseMix: 0)
        case (.classic, .subdivision):
            return ClickSpec(frequency: 2400, duration: 0.010, gain: 0.45, decay: 1000, noiseMix: 0)
        case (.electronic, .accent):
            return ClickSpec(frequency: 880, duration: 0.06, gain: 0.8, decay: 90, noiseMix: 0)
        case (.electronic, .normal):
            return ClickSpec(frequency: 660, duration: 0.05, gain: 0.65, decay: 100, noiseMix: 0)
        case (.electronic, .subdivision):
            return ClickSpec(frequency: 550, duration: 0.035, gain: 0.4, decay: 140, noiseMix: 0)
        case (.wood, .accent):
            return ClickSpec(frequency: 800, duration: 0.05, gain: 0.95, decay: 300, noiseMix: 0.5)
        case (.wood, .normal):
            return ClickSpec(frequency: 600, duration: 0.045, gain: 0.8, decay: 320, noiseMix: 0.5)
        case (.wood, .subdivision):
            return ClickSpec(frequency: 500, duration: 0.03, gain: 0.5, decay: 380, noiseMix: 0.5)
        }
    }

    private static func render(spec: ClickSpec, sampleRate: Double, channelCount: AVAudioChannelCount) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(spec.duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let fadeIn = max(1, Int(0.001 * sampleRate))
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-spec.decay * t))
            let tone = Float(sin(2 * .pi * spec.frequency * t))
            let noise = spec.noiseMix > 0 ? Float.random(in: -1...1) * spec.noiseMix : 0
            var sample = (tone + noise) * envelope * spec.gain
            if i < fadeIn {
                sample *= Float(i) / Float(fadeIn)
            }
            let clamped = max(-1, min(1, sample))
            for channel in 0..<Int(channelCount) {
                buffer.floatChannelData![channel][i] = clamped
            }
        }
        return buffer
    }
}
