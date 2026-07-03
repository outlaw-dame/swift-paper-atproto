# Swift-Paper-ATProto

A native Swift/SwiftUI multiplatform client (macOS/iOS) for the AT Protocol (Bluesky),

This project is a Swift-based implementation mirroring the concepts of [Paper-ATProto](https://github.com/outlaw-dame/paper-atproto).

## Stack & Technologies
- **UI Framework:** SwiftUI for a modern, fluid user interface following Apple's Human Interface Guidelines (HIG).
- **Network Engine:** Native `URLSession` utilizing Swift's async/await structure for clean, performant API interactions without bloated dependencies.
- **Local Store:** Ultra-fast, transactional **ObjectBox** (objectbox.io) database engine for local-first caches, offline reliability, and fast object mapping.
- **Protocol Integration:** Full implementation of com.atproto server sessions and app.bsky feed timeline retrieval.

## Design Highlights
1. **Interactive Cards (Paper-style):** Fluid gesture-driven navigation with horizontal swipes for post details, large media integrations, and card transitions.
2. **One AI System Substrate:** A thread rendering pipeline that visualizes post salience scores, stance diversity, and verification states.
3. **Neeva Gist-style Discovery:** Grouped story cards, automated category filters, and search intent pills.
4. **App Settings & Telemetry:** Offline cache control, custom API endpoints, and a database diagnostics dashboard.

## Running the Project
This project is built using the Swift Package Manager (SPM).

### 1. Generate ObjectBox Bindings
Before building or running the target for the first time (or after changing any database models), run the ObjectBox code generator plugin command to compile the database schema bindings:
```bash
swift package --allow-writing-to-package-directory --allow-network-connections all objectbox-generator --target SwiftPaperATProtoCore
```

### 2. Run Using Xcode
1. Open Xcode.
2. Open File -> Open... and select the `swift-paper-atproto` folder.
3. Select your target scheme (`swift-paper-atproto`) and device (iOS Simulator or My Mac).
4. Build and Run (`Cmd + R`).

### 3. Run Using Command Line (macOS)
```bash
swift run
```
