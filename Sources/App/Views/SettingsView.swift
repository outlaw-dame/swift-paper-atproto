import SwiftUI
import SwiftPaperATProtoCore

struct SettingsView: View {
    @EnvironmentObject var client: ATProtoClient
    @EnvironmentObject var store: LocalStore

    @State private var showingClearAlert   = false
    @State private var showProfileEdit     = false
    @State private var showIdentityDiag    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {

                    // MARK: - Profile Section (Phase 9)
                    Section("Profile") {
                        HStack(spacing: 16) {
                            // Avatar — validated URL before rendering.
                            if let avatar = client.session?.avatar,
                               ATProtoURLValidator.isAllowedMediaURL(avatar) {
                                ProgressiveImageView(imageUrlString: avatar)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                // Display name (Phase 9): show resolved name if available.
                                if let displayName = client.session?.displayName, !displayName.isEmpty {
                                    Text(displayName)
                                        .font(.headline)
                                }
                                Text(client.session?.handle ?? "Guest Contributor")
                                    .font(client.session?.displayName != nil ? .subheadline : .headline)
                                    .foregroundColor(client.session?.displayName != nil ? .secondary : .primary)

                                Text(client.session?.did ?? "did:plc:unsigned-visitor")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 8)

                        // Phase 9: Edit Profile button.
                        Button {
                            showProfileEdit = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil.circle")
                        }
                        .disabled(!client.isAuthenticated)

                        // Phase 9: Identity Diagnostics button.
                        Button {
                            showIdentityDiag = true
                        } label: {
                            Label("Identity Diagnostics", systemImage: "person.badge.key")
                        }
                        .disabled(!client.isAuthenticated)
                    }
                    .listRowBackground(Color.white.opacity(0.04))

                    // MARK: - Local-First Cache Section
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

                    // MARK: - Connection Settings
                    Section("Connection Settings") {
                        Toggle("Mock Offline Database", isOn: $client.useMockData)
                            .tint(Color(red: 0.1, green: 0.5, blue: 0.9))
                    }
                    .listRowBackground(Color.white.opacity(0.04))

                    // MARK: - Active Profiles Section
                    Section("Active Profiles") {
                        if client.loggedInAccounts.isEmpty {
                            Text("No active accounts. Sign in to add accounts.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(client.loggedInAccounts, id: \.self) { handle in
                                HStack {
                                    Text(handle)
                                        .font(.subheadline)
                                    Spacer()
                                    if client.session?.handle == handle {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if client.session?.handle != handle {
                                        withAnimation {
                                            client.switchAccount(to: handle)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))

                    // MARK: - Offline Outbox Queue
                    Section("Offline Outbox Queue") {
                        HStack {
                            Text("Pending Publications")
                            Spacer()
                            Text("\(store.pendingOutboxCount) posts queued")
                                .foregroundColor(.secondary)
                        }

                        if store.pendingOutboxCount > 0 {
                            Button {
                                Task {
                                    await client.flushOutbox(using: store)
                                }
                            } label: {
                                Label("Sync Outbox Queue Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(client.useMockData)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))

                    // MARK: - Local Intelligence Substrate
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

                    // MARK: - Sign Out
                    Section {
                        Button(role: .destructive) {
                            withAnimation {
                                // Uses the no-arg convenience overload (Phase 9 fix).
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
        }
        // Phase 9: Profile Edit sheet.
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView()
                .environmentObject(client)
        }
        // Phase 9: Identity Diagnostics push navigation.
        .navigationDestination(isPresented: $showIdentityDiag) {
            IdentityDiagnosticsView()
                .environmentObject(client)
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
