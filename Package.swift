// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadAloudKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReadAloudKit", targets: ["ReadAloudKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apakabarlabs/readalign-swift", from: "0.5.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/botforge-pro/swift-embed", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "ReadAloudKit",
            dependencies: [.product(name: "ReadAlign", package: "readalign-swift")]
        ),
        .testTarget(
            name: "ReadAloudKitTests",
            dependencies: [
                "ReadAloudKit",
                .product(name: "SwiftEmbed", package: "swift-embed")
            ],
            resources: [.process("Resources")]
        )
    ]
)
