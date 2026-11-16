import Foundation

/// 节拍器完整设置，可持久化。
public struct MetronomeSettings: Equatable, Codable, Sendable {
    public var bpm: Double
    public var beatsPerMeasure: Int
    public var beatUnit: Int
    public var subdivision: MetronomeSubdivision
    public var accents: [BeatAccent]
    public var soundSet: ClickSoundSet
    public var volume: Float
    public var hapticsEnabled: Bool
    /// 静音练习：只保留摆锤等视觉提示，不调度音频。
    public var soundEnabled: Bool
    /// 演出锁定：播放中禁用速度/拍号编辑。
    public var tempoLockEnabled: Bool
    /// 开始前的预备小节数（0 = 关闭）。
    public var countInMeasures: Int
    /// 变速训练配置。
    public var training: TempoTraining

    public init(
        bpm: Double = 100,
        beatsPerMeasure: Int = 4,
        beatUnit: Int = 4,
        subdivision: MetronomeSubdivision = .none,
        accents: [BeatAccent]? = nil,
        soundSet: ClickSoundSet = .classic,
        volume: Float = 0.8,
        hapticsEnabled: Bool = true,
        soundEnabled: Bool = true,
        tempoLockEnabled: Bool = false,
        countInMeasures: Int = 0,
        training: TempoTraining = TempoTraining()
    ) {
        self.bpm = MetronomeTempo.clamp(bpm)
        self.beatsPerMeasure = max(1, beatsPerMeasure)
        self.beatUnit = beatUnit
        self.subdivision = subdivision
        // 旧存档/预设里重音数组长度可能与拍号不一致，统一按拍号补齐或截断，
        // 否则多出来的拍点既点不动，也和引擎的小节边界对不上。
        var pattern = BeatPattern(
            accents: accents ?? BeatPattern.default(beatsPerMeasure: max(1, beatsPerMeasure)).accents
        )
        pattern.resize(to: self.beatsPerMeasure)
        self.accents = pattern.accents
        self.soundSet = soundSet
        self.volume = min(max(volume, 0), 1)
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
        self.tempoLockEnabled = tempoLockEnabled
        self.countInMeasures = min(max(countInMeasures, 0), 2)
        self.training = training
    }

    /// 兼容旧版本存档：新增字段缺失时使用默认值，避免升级后丢设置。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            bpm: try container.decodeIfPresent(Double.self, forKey: .bpm) ?? 100,
            beatsPerMeasure: try container.decodeIfPresent(Int.self, forKey: .beatsPerMeasure) ?? 4,
            beatUnit: try container.decodeIfPresent(Int.self, forKey: .beatUnit) ?? 4,
            subdivision: try container.decodeIfPresent(MetronomeSubdivision.self, forKey: .subdivision) ?? .none,
            accents: try container.decodeIfPresent([BeatAccent].self, forKey: .accents),
            soundSet: try container.decodeIfPresent(ClickSoundSet.self, forKey: .soundSet) ?? .classic,
            volume: try container.decodeIfPresent(Float.self, forKey: .volume) ?? 0.8,
            hapticsEnabled: try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true,
            soundEnabled: try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true,
            tempoLockEnabled: try container.decodeIfPresent(Bool.self, forKey: .tempoLockEnabled) ?? false,
            countInMeasures: try container.decodeIfPresent(Int.self, forKey: .countInMeasures) ?? 0,
            training: try container.decodeIfPresent(TempoTraining.self, forKey: .training) ?? TempoTraining()
        )
    }

    public var timeSignature: MetronomeTimeSignature {
        MetronomeTimeSignature(beatsPerMeasure: beatsPerMeasure, beatUnit: beatUnit)
    }

    public var pattern: BeatPattern {
        BeatPattern(accents: accents)
    }

    // MARK: - UserDefaults 存取

    public static let storeKey = "com.coffic.metronome.settings"

    public static func load(defaults: UserDefaults = .standard) -> MetronomeSettings {
        guard let data = defaults.data(forKey: storeKey),
              let settings = try? JSONDecoder().decode(MetronomeSettings.self, from: data) else {
            return MetronomeSettings()
        }
        return settings
    }

    public func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storeKey)
    }
}
