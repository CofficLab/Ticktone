import Foundation
import Testing
@testable import PluginSettingGeneral

/// 「设置 → 通用 → 关于我们」分组的配置与渲染条件。
///
/// 回归重点：
/// 1. 三个法律链接（官网 / 隐私政策 / 服务条款）必须各自独立注入 —— 只配一个
///    时不能连带把另外两个也画出来。
/// 2. 一个都没配时整组不画 —— 空分组看起来就是渲染错误。
/// 3. 官网从「网站」分组搬到「关于我们」分组后，「支持」分组里不应再残留官网行。
@Suite("GeneralSettings 关于我们分组")
@MainActor
struct GeneralSettingsAboutUsTests {

    // MARK: - 配置承载

    @Test("三个法律链接各自独立注入")
    func configurationCarriesEachLegalLink() {
        let configuration = GeneralSettingsConfiguration(
            websiteURL: URL(string: "https://example.com"),
            privacyPolicyURL: URL(string: "https://example.com/privacy"),
            termsOfServiceURL: URL(string: "https://example.com/terms")
        )

        #expect(configuration.websiteURL?.absoluteString == "https://example.com")
        #expect(configuration.privacyPolicyURL?.absoluteString == "https://example.com/privacy")
        #expect(configuration.termsOfServiceURL?.absoluteString == "https://example.com/terms")
    }

    @Test("未注入法律链接时默认为 nil")
    func configurationDefaultsToNoLegalLinks() {
        let configuration = GeneralSettingsConfiguration()

        #expect(configuration.websiteURL == nil)
        #expect(configuration.privacyPolicyURL == nil)
        #expect(configuration.termsOfServiceURL == nil)
    }

    // MARK: - 渲染条件

    @Test("只配官网时「关于我们」分组出现")
    func aboutUsGroupAppearsWithWebsiteOnly() {
        let configuration = GeneralSettingsConfiguration(
            websiteURL: URL(string: "https://example.com")
        )

        #expect(GeneralSettingsDetailView.hasAboutLinks(in: configuration))
    }

    @Test("只配隐私政策时「关于我们」分组出现")
    func aboutUsGroupAppearsWithPrivacyPolicyOnly() {
        let configuration = GeneralSettingsConfiguration(
            privacyPolicyURL: URL(string: "https://example.com/privacy")
        )

        #expect(GeneralSettingsDetailView.hasAboutLinks(in: configuration))
    }

    @Test("只配服务条款时「关于我们」分组出现")
    func aboutUsGroupAppearsWithTermsOnly() {
        let configuration = GeneralSettingsConfiguration(
            termsOfServiceURL: URL(string: "https://example.com/terms")
        )

        #expect(GeneralSettingsDetailView.hasAboutLinks(in: configuration))
    }

    @Test("三个链接都没配时不画「关于我们」分组")
    func aboutUsGroupIsAbsentWithoutAnyLink() {
        let configuration = GeneralSettingsConfiguration(
            privacyDescription: "Your documents stay on this device."
        )

        #expect(!GeneralSettingsDetailView.hasAboutLinks(in: configuration))
    }

    @Test("官网不再算作「支持」分组的内容")
    func websiteIsNotSupportContent() {
        // 只有官网时：「支持」分组没有条目，但「关于我们」分组有。
        let configuration = GeneralSettingsConfiguration(
            websiteURL: URL(string: "https://example.com")
        )

        #expect(!GeneralSettingsDetailView.hasSupportContent(in: configuration, hasManuals: false))
        #expect(GeneralSettingsDetailView.hasAboutLinks(in: configuration))
    }

    @Test("说明书仍然算作「支持」分组的内容")
    func manualsRemainSupportContent() {
        // 说明书来自宿主的 docsProvider，不在配置里，因此单独传入。
        let configuration = GeneralSettingsConfiguration()

        #expect(GeneralSettingsDetailView.hasSupportContent(in: configuration, hasManuals: true))
        #expect(!GeneralSettingsDetailView.hasSupportContent(in: configuration, hasManuals: false))
    }

    @Test("更新检查回调仍然算作「支持」分组的内容")
    func checkForUpdatesRemainsSupportContent() {
        let configuration = GeneralSettingsConfiguration(
            onCheckForUpdates: {}
        )

        #expect(GeneralSettingsDetailView.hasSupportContent(in: configuration, hasManuals: false))
    }
}
