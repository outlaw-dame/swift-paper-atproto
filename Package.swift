// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Detect if we are building using the bare Command Line Tools (which lack SwiftUI macro support and XCTest)
let isCommandLineTools: Bool = {
    let process = Process()
    process.launchPath = "/usr/bin/xcode-select"
    process.arguments = ["-p"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do {
        try process.run()
        process.waitUntilExit()
        if let data = try pipe.fileHandleForReading.readToEnd(),
           let path = String(data: data, encoding: .utf8) {
            return path.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("CommandLineTools")
        }
    } catch {}
    return true
}()

var products: [Product] = [
    .library(name: "SwiftPaperATProtoCore", targets: ["SwiftPaperATProtoCore"])
]

var targets: [Target] = [
    .target(
        name: "SwiftPaperATProtoCore",
        dependencies: [
            .product(name: "ObjectBox.xcframework", package: "objectbox-swift-spm")
        ],
        path: "Sources/Core",
        exclude: ["model-SwiftPaperATProtoCore.json"]
    ),
    .testTarget(
        name: "SwiftPaperATProtoCoreTests",
        dependencies: ["SwiftPaperATProtoCore"],
        path: "Tests"
    )
]

// Only include the App executable target if Xcode is the active developer path,
// to prevent CLI swift build/test from failing due to missing SwiftUI macro plugins.
if !isCommandLineTools {
    products.append(.executable(name: "swift-paper-atproto", targets: ["swift-paper-atproto"]))
    targets.append(
        .executableTarget(
            name: "swift-paper-atproto",
            dependencies: ["SwiftPaperATProtoCore"],
            path: "Sources/App"
        )
    )
}

let package = Package(
    name: "swift-paper-atproto",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", from: "4.0.0")
    ],
    targets: targets
)
