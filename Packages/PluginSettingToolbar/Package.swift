// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingToolbar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginSettingToolbar",
            targets: ["PluginSettingToolbar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.12.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "PluginSettingToolbar",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
        .testTarget(
            name: "PluginSettingToolbarTests",
            dependencies: [
                "PluginSettingToolbar",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests/PluginSettingToolbarTests"
        ),
    ]
)
