// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadAloudKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReadAloudKit", targets: ["ReadAloudKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apakabarlabs/readalign-swift", from: "0.17.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0")
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
                .product(name: "Yams", package: "Yams")
            ],
            resources: [.process("Resources")]
        )
    ]
)
