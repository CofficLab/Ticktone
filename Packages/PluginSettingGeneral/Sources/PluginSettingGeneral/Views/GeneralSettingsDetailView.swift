#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import LumiUI
import ProviderDocsView
import SwiftUI

/// Shared General settings content assembled from kernel services and host options.
struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?
    let configuration: GeneralSettingsConfiguration

    @State private var isPresentingManuals = false
    private let bundleInfo = AppBundleInfo()

    private var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    private var appName: String {
        configuration.appName ?? bundleInfo.name
    }

    var body: some View {
        #if os(iOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                appSection
                if !manuals.isEmpty {
                    manualsSection
                }
                if configuration.onReplayOnboarding != nil {
                    onboardingSection
                }
                if let privacyDescription = configuration.privacyDescription {
                    privacySection(privacyDescription)
                }
                if hasAboutLinks {
                    aboutUsSection
                }
                if configuration.onCheckForUpdates != nil {
                    updatesSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingManuals) {
            if !manuals.isEmpty {
                ManualsBrowserView(manuals: manuals)
            }
        }
    }

    // MARK: - iOS

    /// iOS 通用页：原生分组列表。
    ///
    /// 桌面端用「图标 + 标题/描述 + 行尾小按钮」，在 iPhone 上既密集又点不中；
    /// iOS 改为「标签 + 灰色值 / 整行可点 + 行尾箭头」，并把说明文案放到分组页脚。
    private var iosBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 18) {
                AppSettingSection(title: SettingGeneralLocalization.string("App", bundle: .module)) {
                    AppSettingValueRow(
                        SettingGeneralLocalization.string("Version", bundle: .module),
                        value: version ?? bundleInfo.version ?? SettingGeneralLocalization.string("Not Set", bundle: .module)
                    )

                    AppSettingValueRow(
                        SettingGeneralLocalization.string("Build", bundle: .module),
                        value: bundleInfo.build ?? SettingGeneralLocalization.string("Not Set", bundle: .module)
                    )
                }

                if let privacyDescription = configuration.privacyDescription {
                    // 隐私说明是一段陈述，不是一个可点开的条目：做成带盾形图标的
                    // 「隐私政策」行会让人以为点得动，实际没有任何跳转。这里直接
                    // 把说明文字放进分组里，不画图标、不做成行。
                    AppSettingSection(title: SettingGeneralLocalization.string("Privacy", bundle: .module)) {
                        Text(privacyDescription)
                            .font(.footnote)
                            .foregroundStyle(Color.lumiSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }

                // 没有可用内容时不画这个分组 —— 一个只有标题的空分组在 iOS 上
                // 看起来就是渲染错误。
                if hasSupportContent {
                    AppSettingSection(title: SettingGeneralLocalization.string("Support", bundle: .module)) {
                        if !manuals.isEmpty {
                            AppSettingDisclosureRow(
                                SettingGeneralLocalization.string("Manuals", bundle: .module),
                                description: SettingGeneralLocalization.string("Browse the guides provided by this app.", bundle: .module),
                                icon: "book"
                            ) {
                                isPresentingManuals = true
                            }
                        }

                        if configuration.onCheckForUpdates != nil {
                            AppSettingDisclosureRow(
                                SettingGeneralLocalization.string("Check for Updates", bundle: .module),
                                description: SettingGeneralLocalization.string("Check whether a newer version is available.", bundle: .module),
                                icon: "arrow.down.circle"
                            ) {
                                configuration.onCheckForUpdates?()
                            }
                        }
                    }
                }

                if hasAboutLinks {
                    AppSettingSection(title: SettingGeneralLocalization.string("About Us", bundle: .module)) {
                        if let websiteURL = configuration.websiteURL {
                            AppSettingDisclosureRow(
                                SettingGeneralLocalization.string("Official Website", bundle: .module),
                                description: websiteURL.host ?? websiteURL.absoluteString,
                                icon: "globe"
                            ) {
                                openURL(websiteURL)
                            }
                        }

                        if let privacyPolicyURL = configuration.privacyPolicyURL {
                            AppSettingDisclosureRow(
                                SettingGeneralLocalization.string("Privacy Policy", bundle: .module),
                                description: privacyPolicyURL.host ?? privacyPolicyURL.absoluteString,
                                icon: "hand.raised"
                            ) {
                                openURL(privacyPolicyURL)
                            }
                        }

                        if let termsOfServiceURL = configuration.termsOfServiceURL {
                            AppSettingDisclosureRow(
                                SettingGeneralLocalization.string("Terms of Service", bundle: .module),
                                description: termsOfServiceURL.host ?? termsOfServiceURL.absoluteString,
                                icon: "doc.text"
                            ) {
                                openURL(termsOfServiceURL)
                            }
                        }
                    }
                }

                if configuration.onReplayOnboarding != nil {
                    AppSettingSection(title: SettingGeneralLocalization.string("Onboarding", bundle: .module)) {
                        AppSettingDisclosureRow(
                            SettingGeneralLocalization.string("Replay Onboarding", bundle: .module),
                            description: SettingGeneralLocalization.string("Show the app's first-run introduction again.", bundle: .module),
                            icon: "graduationcap"
                        ) {
                            configuration.onReplayOnboarding?()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingManuals) {
            if !manuals.isEmpty {
                ManualsBrowserView(manuals: manuals)
            }
        }
    }

    /// 「支持」分组是否有可展示的条目。
    ///
    /// 官网 / 隐私政策 / 服务条款归「关于我们」分组，不在这里。
    private var hasSupportContent: Bool {
        Self.hasSupportContent(in: configuration, hasManuals: !manuals.isEmpty)
    }

    /// 「关于我们」分组是否有可展示的条目。
    ///
    /// 三个法律链接一个都没有时不画这个分组 —— 一个只有标题的空分组看起来
    /// 就是渲染错误。
    private var hasAboutLinks: Bool {
        Self.hasAboutLinks(in: configuration)
    }

    /// 「支持」分组的内容判定（供测试直接验证分组归属规则）。
    ///
    /// 说明书数量由宿主的 docsProvider 决定，不在配置里，因此单独传入。
    static func hasSupportContent(
        in configuration: GeneralSettingsConfiguration,
        hasManuals: Bool
    ) -> Bool {
        hasManuals
            || configuration.onCheckForUpdates != nil
    }

    /// 「关于我们」分组的内容判定（供测试直接验证分组归属规则）。
    static func hasAboutLinks(in configuration: GeneralSettingsConfiguration) -> Bool {
        configuration.websiteURL != nil
            || configuration.privacyPolicyURL != nil
            || configuration.termsOfServiceURL != nil
    }

    // MARK: - App information

    private var appSection: some View {
        AppSettingSection(title: appName, titleAlignment: .leading) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: SettingGeneralLocalization.string("Name", bundle: .module),
                    description: appName,
                    icon: "app"
                ) {
                    EmptyView()
                }
                Divider().padding(.vertical, 8)
                AppSettingRow(
                    title: SettingGeneralLocalization.string("Bundle ID", bundle: .module),
                    description: bundleInfo.bundleIdentifier,
                    icon: "number"
                ) {
                    EmptyView()
                }
                Divider().padding(.vertical, 8)
                AppSettingRow(
                    title: SettingGeneralLocalization.string("Version", bundle: .module),
                    description: version ?? bundleInfo.version ?? SettingGeneralLocalization.string("Not Set", bundle: .module),
                    icon: "info.circle"
                ) {
                    EmptyView()
                }
                Divider().padding(.vertical, 8)
                AppSettingRow(
                    title: SettingGeneralLocalization.string("Build", bundle: .module),
                    description: bundleInfo.build ?? SettingGeneralLocalization.string("Not Set", bundle: .module),
                    icon: "hammer"
                ) {
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Manuals

    private var manualsSection: some View {
        AppSettingSection(
            title: SettingGeneralLocalization.string("Documentation", bundle: .module),
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: SettingGeneralLocalization.string("说明书", bundle: .module),
                description: SettingGeneralLocalization.string("Browse the guides provided by this app.", bundle: .module),
                icon: "book"
            ) {
                AppButton(
                    SettingGeneralLocalization.string("Open", bundle: .module),
                    systemImage: "book.pages",
                    style: .secondary,
                    size: .small
                ) {
                    isPresentingManuals = true
                }
            }
        }
    }

    // MARK: - Optional host capabilities

    private var onboardingSection: some View {
        AppSettingSection(
            title: SettingGeneralLocalization.string("Onboarding", bundle: .module),
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: SettingGeneralLocalization.string("Replay Onboarding", bundle: .module),
                description: SettingGeneralLocalization.string("Show the app's first-run introduction again.", bundle: .module),
                icon: "graduationcap"
            ) {
                AppButton(
                    SettingGeneralLocalization.string("Start", bundle: .module),
                    systemImage: "arrow.right",
                    style: .secondary,
                    size: .small
                ) {
                    configuration.onReplayOnboarding?()
                }
            }
        }
    }

    private func privacySection(_ description: String) -> some View {
        AppSettingSection(
            title: SettingGeneralLocalization.string("Privacy", bundle: .module),
            titleAlignment: .leading
        ) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text(description)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 关于我们

    /// 「关于我们」分组：官网 / 隐私政策 / 服务条款。
    ///
    /// 三个链接各自独立存在，宿主只配了哪个就显示哪个。
    @ViewBuilder
    private var aboutUsSection: some View {
        AppSettingSection(
            title: SettingGeneralLocalization.string("About Us", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                if let websiteURL = configuration.websiteURL {
                    AppSettingRow(
                        title: SettingGeneralLocalization.string("Official Website", bundle: .module),
                        description: websiteURL.host ?? websiteURL.absoluteString,
                        icon: "globe"
                    ) {
                        AppButton(
                            SettingGeneralLocalization.string("Open", bundle: .module),
                            systemImage: "arrow.up.forward.square",
                            style: .secondary,
                            size: .small
                        ) {
                            openURL(websiteURL)
                        }
                    }

                    if configuration.privacyPolicyURL != nil || configuration.termsOfServiceURL != nil {
                        Divider().padding(.vertical, 8)
                    }
                }

                if let privacyPolicyURL = configuration.privacyPolicyURL {
                    AppSettingRow(
                        title: SettingGeneralLocalization.string("Privacy Policy", bundle: .module),
                        description: privacyPolicyURL.host ?? privacyPolicyURL.absoluteString,
                        icon: "hand.raised"
                    ) {
                        AppButton(
                            SettingGeneralLocalization.string("Open", bundle: .module),
                            systemImage: "arrow.up.forward.square",
                            style: .secondary,
                            size: .small
                        ) {
                            openURL(privacyPolicyURL)
                        }
                    }

                    if configuration.termsOfServiceURL != nil {
                        Divider().padding(.vertical, 8)
                    }
                }

                if let termsOfServiceURL = configuration.termsOfServiceURL {
                    AppSettingRow(
                        title: SettingGeneralLocalization.string("Terms of Service", bundle: .module),
                        description: termsOfServiceURL.host ?? termsOfServiceURL.absoluteString,
                        icon: "doc.text"
                    ) {
                        AppButton(
                            SettingGeneralLocalization.string("Open", bundle: .module),
                            systemImage: "arrow.up.forward.square",
                            style: .secondary,
                            size: .small
                        ) {
                            openURL(termsOfServiceURL)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        if let onCheckForUpdates = configuration.onCheckForUpdates {
            AppSettingSection(
                title: SettingGeneralLocalization.string("Updates", bundle: .module),
                titleAlignment: .leading
            ) {
                AppSettingRow(
                    title: SettingGeneralLocalization.string("Check for Updates", bundle: .module),
                    description: SettingGeneralLocalization.string("Check whether a newer version is available.", bundle: .module),
                    icon: "arrow.down.circle"
                ) {
                    AppButton(
                        SettingGeneralLocalization.string("Check...", bundle: .module),
                        systemImage: "arrow.triangle.2.circlepath",
                        style: .secondary,
                        size: .small
                    ) {
                        onCheckForUpdates()
                    }
                }
            }
        }
    }

    /// 在默认浏览器中打开链接。
    private func openURL(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #elseif canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}
