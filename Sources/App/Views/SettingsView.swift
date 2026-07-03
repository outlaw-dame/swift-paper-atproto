import SwiftUI
import SwiftPaperATProtoCore

struct SettingsView: View {
    @EnvironmentObject var client: ATProtoClient
    @EnvironmentObject var store: LocalStore
    
    @State private var showingClearAlert = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Form {
                Section("Profile") {
                    HStack(spacing: 16) {
                        if let avatar = client.session?.avatar, let url = URL(string: avatar) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.session?.handle ?? "Guest Contributor")
                                .font(.headline)
                            Text(client.session?.did ?? "did:plc:unsigned-visitor")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.white.opacity(0.04))
                
                Section("Local-First Cache") {
                    HStack {
                        Text("Cached Stories")
                        Spacer()
                        Text("\(store.cachedFeed.count) Items")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bookmarks")
                        Spacer()
                        Text("\(store.savedPostUris.count) Items")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ObjectBox DB Write Latency")
                        Spacer()
                        Text(String(format: "%.2f ms", store.lastTransactionDurationMs))
                            .foregroundColor(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Text("Clear Cache & Bookmarks")
                    }
                }
                .listRowBackground(Color.white.opacity(0.04))
                
                Section("Connection Settings") {
                    Toggle("Mock Offline Database", isOn: $client.useMockData)
                        .tint(Color(red: 0.1, green: 0.5, blue: 0.9))
                }
                .listRowBackground(Color.white.opacity(0.04))
                
                Section("Local Intelligence Substrate") {
                    HStack {
                        Text("Active Classifiers")
                        Spacer()
                        Text("SafetyHeuristics, LocalAbuseV1")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    
                    HStack {
                        Text("Worker Status")
                        Spacer()
                        Text("Idle / Staged")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    
                    HStack {
                        Text("Last Resolution Latency")
                        Spacer()
                        Text("124 ms")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                }
                .listRowBackground(Color.white.opacity(0.04))
                
                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            client.logout()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out Session")
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.04))
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
        .alert("Clear Local Cache", isPresented: $showingClearAlert) {
            Button("Clear All", role: .destructive) {
                store.clearCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action removes cached post graphs and local bookmarks stored on your device.")
        }
    }
}
