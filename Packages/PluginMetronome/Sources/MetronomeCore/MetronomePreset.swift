import Foundation

/// 用户保存的预设。
public struct MetronomePreset: Equatable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var settings: MetronomeSettings

    public init(id: UUID = UUID(), name: String, settings: MetronomeSettings) {
        self.id = id
        self.name = name
        self.settings = settings
    }

    // MARK: - UserDefaults 存取

    public static let storeKey = "com.coffic.metronome.presets"

    public static func loadAll(defaults: UserDefaults = .standard) -> [MetronomePreset] {
        guard let data = defaults.data(forKey: storeKey),
              let presets = try? JSONDecoder().decode([MetronomePreset].self, from: data) else {
            return []
        }
        return presets
    }

    public static func saveAll(_ presets: [MetronomePreset], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: storeKey)
    }
}
