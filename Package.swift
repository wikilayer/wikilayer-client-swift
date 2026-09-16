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
    targets: [
        .target(name: "WikilayerClient"),
        .testTarget(name: "WikilayerClientTests", dependencies: ["WikilayerClient"])
    ]
)
