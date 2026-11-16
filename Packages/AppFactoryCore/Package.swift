// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppFactoryCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AppFactoryCore",
            targets: ["AppFactoryCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiPluginToast.git", from: "1.2.3"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "AppFactoryCore",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "PluginToast", package: "LumiPluginToast"),
                .product(name: "ProviderPluginControl", package: "LumiProviders"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ]
        ),
        .testTarget(
            name: "AppFactoryCoreTests",
            dependencies: ["AppFactoryCore"]
        ),
    ]
)
