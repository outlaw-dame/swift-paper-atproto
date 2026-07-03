import SwiftUI
import SwiftPaperATProtoCore

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var client: ATProtoClient
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "newspaper")
            }
            .tag(0)
            
            NavigationStack {
                ExploreView()
            }
            .tabItem {
                Label("Explore", systemImage: "safari")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(.accentColor)
        #if os(macOS)
        .padding(.top, 10)
        #endif
    }
}

extension View {
    var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.5, green: 0.2, blue: 0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
