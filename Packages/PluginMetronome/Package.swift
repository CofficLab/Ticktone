// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMetronome",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // 纯领域逻辑：速度、拍号、细分、重音模式、预设。不依赖 Kernel / SwiftUI / AVFoundation。
        .library(name: "MetronomeCore", targets: ["MetronomeCore"]),
        // 插件层：采样级音频引擎 + SwiftUI 界面 + SuperPlugin，macOS 与 iOS 共用。
        .library(name: "PluginMetronome", targets: ["PluginMetronome"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.12.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "MetronomeCore",
            path: "Sources/MetronomeCore"
        ),
        .target(
            name: "PluginMetronome",
            dependencies: [
                "MetronomeCore",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: "Sources/PluginMetronome",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "MetronomeCoreTests",
            dependencies: ["MetronomeCore"],
            path: "Tests/MetronomeCoreTests"
        ),
        .testTarget(
            name: "PluginMetronomeTests",
            dependencies: [
                "MetronomeCore",
                "PluginMetronome",
            ],
            path: "Tests/PluginMetronomeTests"
        ),
    ]
)
