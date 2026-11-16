import Foundation
import KernelCore

/// App 运行平台（平台中立枚举，避免在共享代码里依赖 AppKit/UIKit 条件编译）。
public enum AppPlatform: String, Sendable, CaseIterable {
    case macOS
    case iOS
    case visionOS
    case tvOS
    case watchOS

    /// 当前编译平台。
    public static var current: AppPlatform {
        #if os(macOS)
        .macOS
        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        .macOS
        #else
        .iOS
        #endif
        #elseif os(visionOS)
        .visionOS
        #elseif os(tvOS)
        .tvOS
        #elseif os(watchOS)
        .watchOS
        #else
        .macOS
        #endif
    }
}

/// App 运行环境（development / testing / production）。
public enum AppEnvironment: String, Sendable, CaseIterable {
    case development
    case testing
    case production

    /// 当前编译环境：DEBUG 视为 development，否则 production。
    public static var current: AppEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}

/// 插件启用状态的内存存储（可注入 `pluginStateStore` 或由装配器根据
/// `pluginEnableOverrides` 自动创建）。不同 App 使用不同实例，互不影响。
@MainActor
public final class InMemoryPluginStateStore: PluginStatePersisting {
    private var states: [String: Bool]

    public init(initial: [String: Bool] = [:]) {
        self.states = initial
    }

    public func enabledState(pluginID: String) -> Bool? {
        states[pluginID]
    }

    public func setEnabled(_ enabled: Bool, pluginID: String) {
        states[pluginID] = enabled
    }

    public func removeState(pluginID: String) {
        states.removeValue(forKey: pluginID)
    }
}

/// App 级装配上下文。
///
/// 统一承载 App 身份（appID / 数据命名空间）、数据根目录、平台、环境、
/// 插件启用覆盖与插件状态存储实现。**不依赖硬编码的全局 UserDefaults key**；
/// 默认 Provider 必须使用本 context 取得目录和命名空间。
@MainActor
public struct AppAssemblyConfiguration {
    /// App 标识 / 持久化命名空间，例如 `com.coffic.dotmine`。
    public var appID: String

    /// 运行平台。
    public var platform: AppPlatform

    /// 运行环境（影响默认数据目录与日志级别）。
    public var environment: AppEnvironment

    /// 插件启用状态覆盖（key 为插件 ID）。
    public var pluginEnableOverrides: [String: Bool]

    /// 新插件 ID → 旧插件 ID 的兼容映射（读取时先查新 ID 再回退旧 ID）。
    public var legacyPluginIDAliases: [String: String]

    /// 数据根目录；不设置时由 `resolvedDataRootDirectory` 按 appID 推导。
    public var dataRootDirectory: URL?

    /// 临时目录；不设置时由 `resolvedTemporaryDirectory` 按 appID 推导。
    public var temporaryDirectory: URL?

    /// 插件启用状态的持久化实现；不设置时装配器用 `pluginEnableOverrides` 建内存存储。
    public var pluginStateStore: (any PluginStatePersisting)?

    public init(
        appID: String,
        platform: AppPlatform = .current,
        environment: AppEnvironment = .current,
        pluginEnableOverrides: [String: Bool] = [:],
        legacyPluginIDAliases: [String: String] = [:],
        dataRootDirectory: URL? = nil,
        temporaryDirectory: URL? = nil,
        pluginStateStore: (any PluginStatePersisting)? = nil
    ) {
        self.appID = appID
        self.platform = platform
        self.environment = environment
        self.pluginEnableOverrides = pluginEnableOverrides
        self.legacyPluginIDAliases = legacyPluginIDAliases
        self.dataRootDirectory = dataRootDirectory
        self.temporaryDirectory = temporaryDirectory
        self.pluginStateStore = pluginStateStore
    }

    /// 中性默认配置（appID = "appfactory"）。各 App 应在自己的 Factory
    /// 公开入口中传入带真实 appID 的配置，保证数据目录按 App 隔离。
    public static var `default`: AppAssemblyConfiguration {
        AppAssemblyConfiguration(appID: "appfactory")
    }

    /// 解析后的数据根目录：显式设置优先，否则 `Application Support/<appID>`。
    public var resolvedDataRootDirectory: URL {
        if let dataRootDirectory { return dataRootDirectory }
        // 跨平台回退：`urls(for:in:)` 双端可用；仅当异常拿不到时才用临时目录兜底
        // （`homeDirectoryForCurrentUser` 是 macOS-only，不能用于 iOS 编译）。
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(appID, isDirectory: true)
    }

    /// 解析后的临时目录：显式设置优先，否则 `<NSTemporaryDirectory()>/<appID>`。
    public var resolvedTemporaryDirectory: URL {
        if let temporaryDirectory { return temporaryDirectory }
        let base = FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appID, isDirectory: true)
    }
}
