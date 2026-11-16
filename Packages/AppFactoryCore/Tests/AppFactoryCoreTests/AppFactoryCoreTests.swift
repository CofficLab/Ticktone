import XCTest
import SwiftUI
import KernelCore
@testable import AppFactoryCore

// MARK: - Test doubles

private enum TestError: Error {
    case providerFailure
    case bootFailure
}

@MainActor
private final class TestPlugin: SuperPlugin {
    let id: String
    let policy: PluginEnablePolicy
    let dependencies: [String]
    var bootShouldThrow = false
    private(set) var onBootCalled = false
    private(set) var onShutdownCalled = false

    init(
        id: String,
        policy: PluginEnablePolicy = .required,
        dependencies: [String] = []
    ) {
        self.id = id
        self.policy = policy
        self.dependencies = dependencies
    }

    var metadata: PluginMetadata {
        PluginMetadata(id: id, policy: policy)
    }

    func onBoot(kernel: KernelCoreContainer) throws {
        onBootCalled = true
        if bootShouldThrow { throw TestError.bootFailure }
    }

    func onShutdown(kernel: KernelCoreContainer) throws {
        onShutdownCalled = true
    }
}

@MainActor
private struct EmptyProviderFactory: AppProviderFactory {
    func registerProviders(into kernel: KernelCoreContainer) throws {}
}

@MainActor
private struct ThrowingProviderFactory: AppProviderFactory {
    func registerProviders(into kernel: KernelCoreContainer) throws {
        throw TestError.providerFailure
    }
}

@MainActor
private struct TestPluginFactory: AppPluginFactory {
    let plugins: [any SuperPlugin]
    init(_ plugins: [any SuperPlugin]) { self.plugins = plugins }
    func makePlugins() -> [any SuperPlugin] { plugins }
}

// MARK: - Tests

@MainActor
final class AppFactoryCoreTests: XCTestCase {

    func testMakeKernelWithEmptyCatalogBecomesRunning() throws {
        let kernel = try AppKernelAssembler.makeKernel(
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([])
        )
        XCTAssertEqual(kernel.lifecycleState, .running)
    }

    func testMakeKernelBootsPlugins() throws {
        let plugin = TestPlugin(id: "test.plugin")
        let kernel = try AppKernelAssembler.makeKernel(
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([plugin])
        )
        XCTAssertEqual(kernel.lifecycleState, .running)
        XCTAssertTrue(plugin.onBootCalled)
        XCTAssertTrue(kernel.isPluginRegistered(id: "test.plugin"))
        XCTAssertTrue(kernel.isPluginEnabled(id: "test.plugin"))
    }

    func testDuplicatePluginIDThrows() {
        let pluginA = TestPlugin(id: "dup.plugin")
        let pluginB = TestPlugin(id: "dup.plugin")
        XCTAssertThrowsError(
            try AppKernelAssembler.makeKernel(
                providerFactory: EmptyProviderFactory(),
                pluginFactory: TestPluginFactory([pluginA, pluginB])
            )
        ) { error in
            guard case KernelCoreError.pluginAlreadyRegistered(let id) = error else {
                return XCTFail("expected pluginAlreadyRegistered, got \(error)")
            }
            XCTAssertEqual(id, "dup.plugin")
        }
    }

    func testMissingDependencyThrows() {
        let plugin = TestPlugin(id: "dep.plugin", dependencies: ["missing.plugin"])
        XCTAssertThrowsError(
            try AppKernelAssembler.makeKernel(
                providerFactory: EmptyProviderFactory(),
                pluginFactory: TestPluginFactory([plugin])
            )
        ) { error in
            guard case KernelCoreError.pluginDependencyMissing(let pluginID, let dependencyID) = error else {
                return XCTFail("expected pluginDependencyMissing, got \(error)")
            }
            XCTAssertEqual(pluginID, "dep.plugin")
            XCTAssertEqual(dependencyID, "missing.plugin")
        }
    }

    func testThrowingProviderFactoryPropagates() {
        XCTAssertThrowsError(
            try AppKernelAssembler.makeKernel(
                providerFactory: ThrowingProviderFactory(),
                pluginFactory: TestPluginFactory([])
            )
        ) { error in
            guard case TestError.providerFailure = error else {
                return XCTFail("expected providerFailure, got \(error)")
            }
        }
    }

    func testPluginBootFailureRollsBackKernelToFailed() {
        let plugin = TestPlugin(id: "fail.plugin")
        plugin.bootShouldThrow = true
        XCTAssertThrowsError(
            try AppKernelAssembler.makeKernel(
                providerFactory: EmptyProviderFactory(),
                pluginFactory: TestPluginFactory([plugin])
            )
        )
        XCTAssertTrue(plugin.onBootCalled, "onBoot 应被调用过")
        XCTAssertTrue(plugin.onShutdownCalled, "失败回滚应调用 onShutdown")
    }

    func testAsyncAssemblyBootsAsyncPlugins() async throws {
        let plugin = TestPlugin(id: "async.plugin")
        let kernel = try await AppKernelAssembler.makeKernelAsync(
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([plugin])
        )
        XCTAssertEqual(kernel.lifecycleState, .running)
        XCTAssertTrue(plugin.onBootCalled)
    }

    func testIndependentDataRootsByAppID() {
        let configA = AppAssemblyConfiguration(appID: "com.coffic.dotmine")
        let configB = AppAssemblyConfiguration(appID: "com.coffic.linkpod")

        XCTAssertNotEqual(
            configA.resolvedDataRootDirectory,
            configB.resolvedDataRootDirectory
        )
        XCTAssertEqual(
            configA.resolvedDataRootDirectory.lastPathComponent,
            "com.coffic.dotmine"
        )
        XCTAssertEqual(
            configB.resolvedDataRootDirectory.lastPathComponent,
            "com.coffic.linkpod"
        )
        XCTAssertNotEqual(
            configA.resolvedTemporaryDirectory,
            configB.resolvedTemporaryDirectory
        )
    }

    func testExplicitDataRootTakesPrecedence() {
        let custom = URL(fileURLWithPath: "/tmp/custom-root")
        let config = AppAssemblyConfiguration(
            appID: "com.coffic.dotmine",
            dataRootDirectory: custom
        )
        XCTAssertEqual(config.resolvedDataRootDirectory, custom)
    }

    func testPluginEnableOverridesCreateStateStore() throws {
        // enabledByDefault 插件被覆盖为禁用 → 注册但不 Boot
        let plugin = TestPlugin(id: "toggle.plugin", policy: .enabledByDefault)
        let config = AppAssemblyConfiguration(
            appID: "com.coffic.dotmine",
            pluginEnableOverrides: ["toggle.plugin": false]
        )
        let kernel = try AppKernelAssembler.makeKernel(
            configuration: config,
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([plugin])
        )
        XCTAssertNotNil(kernel.stateStore)
        XCTAssertTrue(kernel.isPluginRegistered(id: "toggle.plugin"))
        XCTAssertFalse(kernel.isPluginEnabled(id: "toggle.plugin"))
        XCTAssertFalse(plugin.onBootCalled)
    }

    func testLegacyPluginIDAliasesApplied() throws {
        let plugin = TestPlugin(id: "new.plugin")
        let config = AppAssemblyConfiguration(
            appID: "com.coffic.dotmine",
            legacyPluginIDAliases: ["new.plugin": "old.plugin"]
        )
        let kernel = try AppKernelAssembler.makeKernel(
            configuration: config,
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([plugin])
        )
        XCTAssertEqual(kernel.legacyPluginIDAliases["new.plugin"], "old.plugin")
    }

    func testAppKernelReferenceBootstrapSucceeds() async {
        let reference = AppKernelReference(
            configuration: AppAssemblyConfiguration(appID: "com.coffic.test"),
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([TestPlugin(id: "ref.plugin")])
        )
        XCTAssertNil(reference.kernel)
        XCTAssertNil(reference.errorMessage)

        await reference.bootstrap()

        XCTAssertNotNil(reference.kernel)
        XCTAssertEqual(reference.kernel?.lifecycleState, .running)
        XCTAssertNil(reference.errorMessage)
    }

    func testAppKernelReferenceBootstrapIsIdempotent() async {
        let reference = AppKernelReference(
            configuration: AppAssemblyConfiguration(appID: "com.coffic.test"),
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([])
        )
        await reference.bootstrap()
        let first = reference.kernel
        await reference.bootstrap()
        XCTAssertTrue(reference.kernel === first, "bootstrap 应只执行一次")
    }

    func testAppKernelReferenceReportsError() async {
        let reference = AppKernelReference(
            configuration: AppAssemblyConfiguration(appID: "com.coffic.test"),
            providerFactory: ThrowingProviderFactory(),
            pluginFactory: TestPluginFactory([])
        )
        await reference.bootstrap()
        XCTAssertNil(reference.kernel)
        XCTAssertNotNil(reference.errorMessage)
    }

    func testDefaultAppViewFactoryReturnsUnsupportedSettings() throws {
        let kernel = try AppKernelAssembler.makeKernel(
            providerFactory: EmptyProviderFactory(),
            pluginFactory: TestPluginFactory([])
        )
        let factory = DefaultAppViewFactory(appName: "ChessPod") { _ in
            AnyView(Text("main"))
        }
        let settings = try factory.makeSettingsView(kernel: kernel)
        // 无法直接断言 AnyView 内容，仅验证不抛错即可
        _ = settings
    }
}
