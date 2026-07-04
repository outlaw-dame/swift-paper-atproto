import SwiftUI
import SwiftPaperATProtoCore

/// A form-based profile editor that writes to `app.bsky.actor.profile` via `putRecord`.
///
/// Design principles:
/// - Display name capped to 64 characters (server enforces; we also enforce locally).
/// - Bio capped to 256 characters.
/// - All input is sanitised server-side via `ATProtoClient.sanitizeProfileText`.
/// - `isUpdatingProfile` spinner prevents double-submission races.
/// - Avatar display uses `ProgressiveImageView` for cache-first secure rendering.
struct ProfileEditView: View {
    @EnvironmentObject var client: ATProtoClient
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants (must match ATProtoClient.sanitizeProfileText limits)
    private static let displayNameMaxLength = 64
    private static let descriptionMaxLength = 256

    // MARK: - State
    @State private var displayName: String = ""
    @State private var description:  String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var profile: ProfileViewDetailed? = nil
    @State private var isLoadingProfile = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoadingProfile {
                    ProgressView("Loading profile…")
                        .tint(.accentColor)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            profileHeader

                            editFields

                            if let error = errorMessage {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            if let success = successMessage {
                                Label(success, systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            saveButton
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    // MARK: - Subviews

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar display — uses secure progressive image loader.
            if let avatar = profile?.avatar ?? client.session?.avatar,
               ATProtoURLValidator.isAllowedMediaURL(avatar) {
                ProgressiveImageView(imageUrlString: avatar)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    )
            }

            if let handle = client.session?.handle {
                Text("@\(handle)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Display Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Your display name", text: $displayName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(displayName.count > Self.displayNameMaxLength
                                    ? Color.red.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    // Hard cap at the character limit.
                    .onChange(of: displayName) { _, new in
                        if new.count > Self.displayNameMaxLength {
                            displayName = String(new.prefix(Self.displayNameMaxLength))
                        }
                    }
                    .autocorrectionDisabled()

                HStack {
                    Spacer()
                    Text("\(displayName.count) / \(Self.displayNameMaxLength)")
                        .font(.caption2)
                        .foregroundColor(displayName.count > Self.displayNameMaxLength - 5 ? .orange : .secondary)
                }
            }

            // Bio / Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Bio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(description.count > Self.descriptionMaxLength
                                    ? Color.red.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .onChange(of: description) { _, new in
                        if new.count > Self.descriptionMaxLength {
                            description = String(new.prefix(Self.descriptionMaxLength))
                        }
                    }
                    .scrollContentBackground(.hidden)

                HStack {
                    Spacer()
                    Text("\(description.count) / \(Self.descriptionMaxLength)")
                        .font(.caption2)
                        .foregroundColor(description.count > Self.descriptionMaxLength - 20 ? .orange : .secondary)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            Group {
                if client.isUpdatingProfile {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Saving…")
                    }
                } else {
                    Text("Save Changes")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(saveButtonBackground)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(client.isUpdatingProfile || !hasChanges)
        .animation(.easeInOut(duration: 0.2), value: client.isUpdatingProfile)
    }

    private var saveButtonBackground: LinearGradient {
        let isActive = hasChanges && !client.isUpdatingProfile
        return LinearGradient(
            colors: isActive
                ? [Color(hue: 0.58, saturation: 0.8, brightness: 0.85),
                   Color(hue: 0.63, saturation: 0.9, brightness: 0.75)]
                : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Logic

    /// True only if the user actually changed something from the loaded profile.
    private var hasChanges: Bool {
        let loadedName = profile?.displayName ?? ""
        let loadedDesc = profile?.description ?? ""
        return displayName != loadedName || description != loadedDesc
    }

    private func loadProfile() async {
        isLoadingProfile = true
        errorMessage = nil
        do {
            let p = try await client.fetchProfile()
            self.profile     = p
            self.displayName = p.displayName ?? ""
            self.description = p.description ?? ""
        } catch {
            self.errorMessage = "Failed to load profile. You can still edit and save."
            // Pre-fill from session cache as fallback.
            self.displayName  = client.session?.displayName ?? ""
        }
        isLoadingProfile = false
    }

    private func save() async {
        errorMessage  = nil
        successMessage = nil

        // Local pre-validation before the network round-trip.
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.count > Self.displayNameMaxLength {
            errorMessage = "Display name exceeds \(Self.displayNameMaxLength) characters."
            return
        }
        if trimmedDesc.count > Self.descriptionMaxLength {
            errorMessage = "Bio exceeds \(Self.descriptionMaxLength) characters."
            return
        }

        do {
            try await client.updateProfile(
                displayName: trimmedName.isEmpty ? nil : trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc
            )
            successMessage = "Profile updated successfully."
            // Dismiss after a brief pause to let the user see the confirmation.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
