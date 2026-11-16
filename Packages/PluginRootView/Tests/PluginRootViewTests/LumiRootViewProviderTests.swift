import Foundation
import KernelCore
import ProviderRailView
import ProviderRootView
import SwiftUI
import Testing

@testable import PluginRootView

/// 记录根视图事件，便于断言状态变化是否被正确广播。
@MainActor
final class RootEventRecorder {
    private(set) var events: [RootViewEvent] = []
    private var handle: (any RootViewObserverHandle)?

    func attach(to provider: LumiRootViewProvider) {
        handle = provider.addRootViewObserver { [weak self] event in
            self?.events.append(event)
        }
    }

    func count(where predicate: (RootViewEvent) -> Bool) -> Int {
        events.filter(predicate).count
    }
}

/// 内容底栏高度存储的内存替身。
@MainActor
final class FooterHeightStoreStub: ContentFooterHeightStoring {
    private(set) var values: [String: CGFloat] = [:]
    private(set) var removed: [String] = []

    init(values: [String: CGFloat] = [:]) {
        self.values = values
    }

    func loadHeight(ownerID: String) -> CGFloat? {
        values[ownerID]
    }

    func saveHeight(_ height: CGFloat, ownerID: String) {
        values[ownerID] = height
    }

    func removeHeight(ownerID: String) {
        values.removeValue(forKey: ownerID)
        removed.append(ownerID)
    }
}

/// 根视图 Provider：覆盖层、Rail 可见性/宽度、内容底栏高度与活跃内容判定
@Suite("LumiRootViewProvider / 根视图 Provider", .serialized)
@MainActor
struct LumiRootViewProviderTests {
    // MARK: - 覆盖层

    @Test("覆盖层按 order 排序且忽略重复 id")
    func overlaysAreSortedAndDeduplicated() {
        let provider = LumiRootViewProvider()

        provider.addOverlays([
            RootOverlayItem(id: "b", order: 20) { $0 },
            RootOverlayItem(id: "a", order: 10) { $0 },
            RootOverlayItem(id: "b", order: 5) { $0 },
        ])

        #expect(provider.overlays.map(\.id) == ["a", "b"])
        #expect(provider.overlays.map(\.order) == [10, 20])
    }

    @Test("覆盖层集合变化时广播事件")
    func overlayChangesEmitEvents() {
        let provider = LumiRootViewProvider()
        let recorder = RootEventRecorder()
        recorder.attach(to: provider)

        provider.addOverlays([RootOverlayItem(id: "a") { $0 }])
        #expect(recorder.count { event in if case .overlaysChanged = event { return true }; return false } == 1)

        provider.addOverlays([RootOverlayItem(id: "a") { $0 }])
        #expect(recorder.count { event in if case .overlaysChanged = event { return true }; return false } == 1, "重复 id 不应重复广播")

        provider.removeOverlays(ids: ["a"])
        #expect(recorder.count { event in if case .overlaysChanged = event { return true }; return false } == 2)

        provider.removeOverlays(ids: ["missing"])
        #expect(recorder.count { event in if case .overlaysChanged = event { return true }; return false } == 2, "空删除不应广播")
    }

    // MARK: - Rail 可见性

    @Test("Rail 可见性变化会更新状态并广播")
    func railVisibilityIsTracked() {
        let provider = LumiRootViewProvider()
        let recorder = RootEventRecorder()
        recorder.attach(to: provider)

        provider.setRailViewVisible(false)

        #expect(provider.isRailViewVisible == false)
        #expect(recorder.count { event in if case .railViewVisibilityChanged(let visible) = event { return visible == false }; return false } == 1)

        provider.setRailViewVisible(false)
        #expect(recorder.count { event in if case .railViewVisibilityChanged(let visible) = event { return visible == false }; return false } == 1, "相同状态不应重复广播")
    }

    @Test("绑定 Rail 后跟随 Provider 的可见状态")
    func railVisibilityFollowsBoundProvider() {
        let provider = LumiRootViewProvider()
        let rail = DefaultRailViewProviding()

        provider.bindRailViewVisibility(to: rail)
        #expect(provider.isRailViewVisible == rail.hasVisibleTabs)

        rail.registerTabs([
            RailTabItem(id: "tab-1", category: .general, title: "Tab", systemImage: "square") {
                Text("Tab")
            },
        ])
        #expect(provider.isRailViewVisible == true)
    }

    // MARK: - Rail 宽度

    @Test("绑定 Rail 宽度后采用 Provider 当前宽度")
    func railWidthAdoptsBoundProviderValue() {
        let provider = LumiRootViewProvider()
        let rail = DefaultRailViewProviding()

        provider.bindRailViewWidth(to: rail, onResize: { _ in })

        #expect(provider.railWidth == rail.railWidth)
    }

    @Test("保存 Rail 宽度会调用回调")
    func savingRailWidthInvokesCallback() {
        let provider = LumiRootViewProvider()
        let rail = DefaultRailViewProviding()
        var resized: CGFloat?

        provider.bindRailViewWidth(to: rail, onResize: { resized = $0 })
        provider.saveRailViewWidth(321)

        #expect(resized == 321)
    }

    // MARK: - 内容底栏高度

    @Test("空 ownerID 不会激活高度档案")
    func emptyOwnerIDDoesNotActivateProfile() {
        let provider = LumiRootViewProvider()

        provider.activateContentFooterHeightProfile(
            ownerID: "",
            recommended: .standard,
            store: FooterHeightStoreStub()
        )

        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("激活档案时恢复已存储的高度")
    func activatingProfileRestoresStoredHeight() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub(values: ["owner": 220])

        provider.activateContentFooterHeightProfile(
            ownerID: "owner",
            recommended: .standard,
            store: store
        )

        #expect(provider.contentFooterHeight.idealHeight == 220)
    }

    @Test("恢复的高度会被限制在允许区间内")
    func restoredHeightIsClamped() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub(values: ["owner": 5_000])
        let recommended = ContentFooterHeight(minHeight: 100, idealHeight: 280, maxHeight: 400)

        provider.activateContentFooterHeightProfile(
            ownerID: "owner",
            recommended: recommended,
            store: store
        )

        #expect(provider.contentFooterHeight.idealHeight == 400)
    }

    @Test("停用档案后高度回到标准值")
    func deactivatingProfileResetsHeight() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub(values: ["owner": 220])
        provider.activateContentFooterHeightProfile(
            ownerID: "owner",
            recommended: .standard,
            store: store
        )

        provider.deactivateContentFooterHeightProfile(ownerID: "owner")

        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("停用档案时 owner 不匹配则忽略")
    func deactivatingWithMismatchedOwnerIsIgnored() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub(values: ["owner": 220])
        provider.activateContentFooterHeightProfile(
            ownerID: "owner",
            recommended: .standard,
            store: store
        )

        provider.deactivateContentFooterHeightProfile(ownerID: "other")

        #expect(provider.contentFooterHeight.idealHeight == 220)
    }

    @Test("保存当前底栏高度会持久化并限制区间")
    func savingFooterHeightPersistsClampedValue() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub()
        provider.activateContentFooterHeightProfile(
            ownerID: "owner",
            recommended: .standard,
            store: store
        )

        provider.saveCurrentContentFooterHeight(150)

        #expect(store.values["owner"] == 150)
        #expect(provider.contentFooterHeight.idealHeight == 150)
    }

    @Test("没有激活档案时保存高度不会写入存储")
    func savingFooterHeightWithoutProfileIsNoop() {
        let provider = LumiRootViewProvider()
        let store = FooterHeightStoreStub()

        provider.saveCurrentContentFooterHeight(150)

        #expect(store.values.isEmpty)
    }

    // MARK: - 活跃内容

    @Test("注入内容视图后判定存在活跃内容")
    func activeContentFollowsInjectedViews() {
        let provider = LumiRootViewProvider()
        #expect(provider.hasActiveContent == false)

        provider.setContentView(AnyView(Text("content")))
        #expect(provider.hasActiveContent == true)
    }

    @Test("尾部面板可见时判定存在活跃内容")
    func activeContentFollowsTrailingPane() {
        let provider = LumiRootViewProvider()
        let pane = RootViewPane(id: "pane", isVisible: true, content: AnyView(Text("pane")))

        provider.setTrailingPane(pane)

        #expect(provider.hasActiveContent == true)
    }

    @Test("尾部面板不可见时不算活跃内容")
    func hiddenTrailingPaneIsNotActiveContent() {
        let provider = LumiRootViewProvider()
        let pane = RootViewPane(id: "pane", isVisible: false, content: AnyView(Text("pane")))

        provider.setTrailingPane(pane)

        #expect(provider.hasActiveContent == false)
    }

    // MARK: - 注入守卫

    @Test("相同状态的重复注入不会重复广播")
    func repeatedInjectionOfSameStateIsSkipped() {
        let provider = LumiRootViewProvider()
        let recorder = RootEventRecorder()
        recorder.attach(to: provider)

        provider.setContentView(AnyView(Text("content")))
        #expect(recorder.count { event in if case .contentViewChanged = event { return true }; return false } == 1)

        provider.setContentView(AnyView(Text("other")))
        #expect(
            recorder.count { event in if case .contentViewChanged = event { return true }; return false } == 1,
            "非 nil 视图重复注入应被守卫跳过"
        )
    }

    @Test("尾部面板替换会广播事件")
    func trailingPaneChangeEmitsEvent() {
        let provider = LumiRootViewProvider()
        let recorder = RootEventRecorder()
        recorder.attach(to: provider)
        let pane = RootViewPane(id: "pane", content: AnyView(Text("pane")))

        provider.setTrailingPane(pane)
        #expect(recorder.count { event in if case .trailingPaneChanged = event { return true }; return false } == 1)

        provider.setTrailingPane(pane)
        #expect(recorder.count { event in if case .trailingPaneChanged = event { return true }; return false } == 1, "同一实例不应重复广播")
    }
}

/// 视图注入与 Rail 交互的补充用例
@Suite("LumiRootViewProvider / 视图注入", .serialized)
@MainActor
struct LumiRootViewInjectionTests {
    @Test("注入工具栏与活动栏视图")
    func toolbarAndActivityBarInjection() {
        let provider = LumiRootViewProvider()

        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setActivityBarView(AnyView(Text("activity")))

        #expect(provider.view(for: .toolbar) != nil)
        #expect(provider.view(for: .activityBar) != nil)
    }

    @Test("清空 Rail 视图会隐藏 Rail，重新注入时恢复上次可见性")
    func clearingRailViewHidesAndRestoringRecoversVisibility() {
        let provider = LumiRootViewProvider()
        provider.setRailViewVisible(true)

        provider.setRailView(AnyView(Text("rail")))
        #expect(provider.isRailViewVisible == true)

        provider.setRailView(nil)
        #expect(provider.isRailViewVisible == false, "清空 Rail 视图应隐藏 Rail")

        provider.setRailView(AnyView(Text("rail-again")))
        #expect(provider.isRailViewVisible == true, "重新注入 Rail 应恢复上次可见性")
    }

    @Test("Rail 宽度变化会同步到根视图 Provider")
    func railWidthChangePropagatesToProvider() async {
        let provider = LumiRootViewProvider()
        let rail = DefaultRailViewProviding()
        provider.bindRailViewWidth(to: rail, onResize: { _ in })

        let recommended = RailViewWidth(minWidth: 120, idealWidth: 200, maxWidth: 360)
        rail.activateWidthProfile(ownerID: "owner", recommended: recommended, store: nil)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(provider.railWidth.idealWidth == 200)
    }
}

/// RootView 生命周期插件
@Suite("RootViewPlugin / 根视图插件", .serialized)
@MainActor
struct RootViewPluginTests {
    @Test("插件元信息稳定")
    func pluginMetadataIsStable() {
        let plugin = RootViewPlugin()

        #expect(plugin.id == RootViewPlugin.pluginID)
        #expect(plugin.id == "com.coffic.lumi.plugin.root-view")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(plugin.order == 0)
    }

    @Test("默认构造使用 LumiRootViewProvider")
    func defaultProviderIsLumiRootViewProvider() {
        let plugin = RootViewPlugin()

        #expect(plugin.provider is LumiRootViewProvider)
    }

    @Test("onBoot 注册根视图 Provider")
    func bootRegistersRootViewProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = RootViewPlugin()

        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any RootViewProviding).self) is LumiRootViewProvider)
    }

    @Test("onBoot 覆盖宿主预注册的根视图 Provider")
    func bootOverridesHostRegisteredProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProviding())

        try RootViewPlugin().onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any RootViewProviding).self) is LumiRootViewProvider)
    }

    @Test("onShutdown 撤回根视图 Provider")
    func shutdownUnregistersRootViewProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = RootViewPlugin()
        try plugin.onBoot(kernel: kernel)

        try plugin.onShutdown(kernel: kernel)

        #expect(kernel.resolveProvider((any RootViewProviding).self) == nil)
    }
}
