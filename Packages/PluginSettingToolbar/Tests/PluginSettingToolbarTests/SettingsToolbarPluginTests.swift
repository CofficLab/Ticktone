import Foundation
import KernelCore
import LumiUI
import ProviderToolbar
import SwiftUI
import Testing

@testable import PluginSettingToolbar

/// 设置工具栏插件：向宿主工具栏贡献设置按钮
@Suite("SettingsToolbarPlugin / 设置工具栏插件", .serialized)
@MainActor
struct SettingsToolbarPluginTests {
    private let windowID = "test.host.settings"

    private func makePlugin() -> SettingsToolbarPlugin {
        SettingsToolbarPlugin(settingsWindowID: windowID)
    }

    @Test("插件元信息稳定")
    func metadataIsStable() {
        let plugin = makePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.setting-toolbar")
        #expect(plugin.order == 950)
        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.setting-toolbar")
        #expect(plugin.metadata.name == "Settings Toolbar")
        #expect(plugin.metadata.description == "Adds a settings button to the host toolbar.")
        #expect(plugin.metadata.category == .general)
        #expect(plugin.metadata.stage == .stable)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    @Test("缺少工具栏 Provider 时启动不报错也不注入任何项")
    func bootWithoutToolbarProviderIsSafe() throws {
        let kernel = KernelCoreContainer()

        try kernel.start(plugins: [makePlugin()])

        #expect(kernel.resolveProvider((any ToolbarProviding).self) == nil)
        #expect(kernel.registeredPluginCount == 1)
    }

    #if os(macOS)
    @Test("启动后向工具栏注入唯一的设置按钮项")
    func bootAddsSingleToolbarItem() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        try kernel.start(plugins: [makePlugin()])

        #expect(toolbar.toolbarItems.count == 1)
        let item = toolbar.toolbarItems.first
        #expect(item?.id == "com.coffic.lumi.plugin.setting-toolbar.toolbar")
        #expect(item?.title == LumiUILocalization.string("Settings"))
        #expect(item?.placement == .trailing)
        #expect(item?.category == .global)
        #expect(item?.order == 300)
    }

    @Test("停止后重启仍只保留一个工具栏项")
    func restartKeepsToolbarItemUnique() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])
        #expect(toolbar.toolbarItems.count == 1)

        try kernel.stop()
        #expect(toolbar.toolbarItems.isEmpty)

        try kernel.start(plugins: [plugin])
        #expect(toolbar.toolbarItems.count == 1)
    }

    @Test("停止内核时撤回工具栏贡献")
    func stopRemovesToolbarContribution() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        try kernel.start(plugins: [makePlugin()])
        #expect(toolbar.toolbarItems.count == 1)

        try kernel.stop()

        #expect(toolbar.toolbarItems.isEmpty)
    }
    #endif
}
