import Foundation

/// 节拍调度的纯计算部分：把「BPM + 拍号 + 细分 + 采样率」换算成
/// 每个 tick 的采样间隔与小节内位置。
///
/// 音频引擎只负责按采样时刻调度，所有算术都在这里，便于单元测试覆盖
/// 漂移、细分与拍序等核心逻辑。
public struct MetronomeTimeline: Sendable, Equatable {
    public let bpm: Double
    public let beatsPerMeasure: Int
    public let subdivision: MetronomeSubdivision
    public let sampleRate: Double

    public init(bpm: Double, beatsPerMeasure: Int, subdivision: MetronomeSubdivision, sampleRate: Double) {
        self.bpm = MetronomeTempo.clamp(bpm)
        self.beatsPerMeasure = max(1, beatsPerMeasure)
        self.subdivision = subdivision
        self.sampleRate = sampleRate
    }

    /// 每个 tick（含细分）之间的秒数。
    public var secondsPerTick: Double {
        60.0 / (bpm * Double(subdivision.multiplier))
    }

    /// 每个 tick 之间的采样数。以 Double 累加可避免长时运行累积舍入误差。
    public var samplesPerTick: Double {
        sampleRate * secondsPerTick
    }

    /// 第 `ordinal` 个 tick 落在小节内的第几拍、是否是拍内细分点。
    public func beatInfo(tickOrdinal: Int) -> (beat: Int, isSubdivision: Bool) {
        let multiplier = subdivision.multiplier
        let beat = (tickOrdinal / multiplier) % beatsPerMeasure
        let isSubdivision = tickOrdinal % multiplier != 0
        return (beat, isSubdivision)
    }
}
