import SwiftUI
import SwiftPaperATProtoCore

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var client: ATProtoClient
    
    @State private var showSplash = true
    @State private var splashScale: CGFloat = 0.85
    @State private var splashOpacity: Double = 1.0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    FeedView()
                }
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                }
                .tag(0)
                
                NavigationStack {
                    DiscoveryView()
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
            .opacity(showSplash ? 0.0 : 1.0)
            
            if showSplash {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundStyle(brandGradient)
                        .scaleEffect(splashScale)
                        .opacity(splashOpacity)
                    
                    Text("Paper-ATProto")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(splashOpacity)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        splashScale = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            splashOpacity = 0.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation {
                            showSplash = false
                        }
                    }
                }
            }
        }
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
