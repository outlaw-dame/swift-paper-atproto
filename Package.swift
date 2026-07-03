// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-paper-atproto",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SwiftPaperATProtoCore", targets: ["SwiftPaperATProtoCore"]),
        .executable(name: "swift-paper-atproto", targets: ["swift-paper-atproto"])
    ],
    dependencies: [
        .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SwiftPaperATProtoCore",
            dependencies: [
                .product(name: "ObjectBox.xcframework", package: "objectbox-swift-spm")
            ],
            path: "Sources/Core",
            exclude: ["model-SwiftPaperATProtoCore.json"]
        ),
        .executableTarget(
            name: "swift-paper-atproto",
            dependencies: ["SwiftPaperATProtoCore"],
            path: "Sources/App"
        )
    ]
)
