import Foundation

/// 插件级文案本地化 helper。
@MainActor
public enum MetronomeLocalization {
    /// 文案所在 bundle。
    public static var bundle: Bundle { .module }

    /// 按 key 取当前语言文案；找不到时回退 key 本身。
    public static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// 带格式参数的本地化。
    public static func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
