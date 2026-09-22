// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WikilayerClient",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "WikilayerClient", targets: ["WikilayerClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/botforge-pro/swift-embed", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "WikilayerClient",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WikilayerClientTests",
            dependencies: [
                "WikilayerClient",
                .product(name: "SwiftEmbed", package: "swift-embed")
            ],
            resources: [.process("Resources")]
        )
    ]
)
