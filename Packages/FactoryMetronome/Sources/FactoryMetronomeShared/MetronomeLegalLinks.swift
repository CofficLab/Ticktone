import Foundation

/// Metronome 的对外法律链接。
///
/// macOS 与 iOS 是同一款 App（universal purchase），两端的
/// 「设置 → 通用 → 关于我们」必须指向同一组地址，因此链接集中在这里，
/// 装配层（Factory*）只负责传给共享设置插件。
public enum MetronomeLegalLinks {
    /// 官方网站。
    public static let website = URL(string: "https://coffic.cn/metronome")!

    /// 隐私政策。
    public static let privacyPolicy = URL(string: "https://coffic.cn/privacy")!

    /// 服务条款。
    public static let termsOfService = URL(string: "https://coffic.cn/terms")!
}
