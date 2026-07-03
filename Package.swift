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
    dependencies: [],
    targets: [
        .target(
            name: "SwiftPaperATProtoCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "swift-paper-atproto",
            dependencies: ["SwiftPaperATProtoCore"],
            path: "Sources/App"
        )
    ]
)
