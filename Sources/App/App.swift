import SwiftUI
import SwiftPaperATProtoCore

@main
struct SwiftPaperATProtoApp: App {
    @StateObject private var client = ATProtoClient()
    @StateObject private var store = LocalStore()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if client.isAuthenticated {
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: client.isAuthenticated)
            .environmentObject(client)
            .environmentObject(store)
            .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        #endif
    }
}
