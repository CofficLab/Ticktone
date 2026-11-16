import Foundation

/// Host-owned details and actions shown by the shared General settings plugin.
///
/// Apps provide only the capabilities they support. App metadata and manuals
/// are read from the host bundle and registered shared providers by default.
///
/// The three legal links (`websiteURL` / `privacyPolicyURL` / `termsOfServiceURL`)
/// feed the "About Us" group. The group is rendered only when at least one of
/// them is present, so hosts that supply nothing keep the page exactly as it was.
@MainActor
public struct GeneralSettingsConfiguration {
    public let appName: String?
    public let privacyDescription: String?
    /// 官方网站。出现在「关于我们」分组。
    public let websiteURL: URL?
    /// 隐私政策。出现在「关于我们」分组。
    public let privacyPolicyURL: URL?
    /// 服务条款。出现在「关于我们」分组。
    public let termsOfServiceURL: URL?
    public let onReplayOnboarding: (@MainActor () -> Void)?
    public let onCheckForUpdates: (@MainActor () -> Void)?

    public init(
        appName: String? = nil,
        privacyDescription: String? = nil,
        websiteURL: URL? = nil,
        privacyPolicyURL: URL? = nil,
        termsOfServiceURL: URL? = nil,
        onReplayOnboarding: (@MainActor () -> Void)? = nil,
        onCheckForUpdates: (@MainActor () -> Void)? = nil
    ) {
        self.appName = appName
        self.privacyDescription = privacyDescription
        self.websiteURL = websiteURL
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
        self.onReplayOnboarding = onReplayOnboarding
        self.onCheckForUpdates = onCheckForUpdates
    }
}
