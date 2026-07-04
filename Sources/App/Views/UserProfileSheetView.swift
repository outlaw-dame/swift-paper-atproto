import SwiftUI
import SwiftPaperATProtoCore

/// A modal sheet displaying details for any resolved user profile DID.
struct UserProfileSheetView: View {
    let did: String
    @EnvironmentObject var client: ATProtoClient
    @Environment(\.dismiss) private var dismiss

    @State private var profile: ProfileViewDetailed? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.accentColor)
                        Text("Fetching profile details…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.red.opacity(0.8))
                        Text("Failed to Load Profile")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await fetchUserProfile() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                    }
                } else if let profile = profile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            profileHeaderCard(profile)
                            
                            if let bio = profile.description, !bio.isEmpty {
                                bioCard(bio)
                            }
                            
                            statsCard(profile)
                            
                            identityFooter(profile)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Profile Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await fetchUserProfile()
            }
        }
    }

    // MARK: - Components

    private func profileHeaderCard(_ profile: ProfileViewDetailed) -> some View {
        HStack(spacing: 16) {
            if let avatar = profile.avatar,
               ATProtoURLValidator.isAllowedMediaURL(avatar) {
                ProgressiveImageView(imageUrlString: avatar)
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                if let dn = profile.displayName, !dn.isEmpty {
                    Text(dn)
                        .font(.headline)
                }
                Text("@\(profile.handle)")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                
                Text(profile.did)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func bioCard(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            Text(bio)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statsCard(_ profile: ProfileViewDetailed) -> some View {
        HStack {
            Spacer()
            statItem(label: "Posts", count: profile.postsCount ?? 0)
            Spacer()
            Divider().frame(height: 24).background(Color.white.opacity(0.12))
            Spacer()
            statItem(label: "Followers", count: profile.followersCount ?? 0)
            Spacer()
            Divider().frame(height: 24).background(Color.white.opacity(0.12))
            Spacer()
            statItem(label: "Following", count: profile.followsCount ?? 0)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statItem(label: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func identityFooter(_ profile: ProfileViewDetailed) -> some View {
        HStack {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.caption2)
            Text("Decentralized ATProto Identity Verified")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Operations

    private func fetchUserProfile() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await client.fetchProfile(for: did)
            self.profile = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
