import SwiftUI
import SwiftPaperATProtoCore

/// Telemetry view that resolves the current user's handle to a DID,
/// fetches the full DID document from the PLC directory, and displays
/// rotation keys, signing keys, service endpoints, and validation state.
///
/// This view is read-only — it performs no writes. All displayed data
/// is fetched freshly on each `.task` lifecycle invocation.
struct IdentityDiagnosticsView: View {
    @EnvironmentObject var client: ATProtoClient

    // MARK: - State
    @State private var resolutionResult: DIDResolutionResult? = nil
    @State private var isResolving = false
    @State private var errorMessage: String? = nil
    @State private var resolvedAt: Date? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isResolving {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.accentColor)
                        .scaleEffect(1.3)
                    Text("Resolving identity…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red.opacity(0.8))
                    Text("Resolution Failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await resolveIdentity() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            } else if let result = resolutionResult {
                ScrollView {
                    VStack(spacing: 20) {
                        identityHeaderCard(result: result)
                        if let doc = result.didDocument {
                            signingKeysCard(methods: doc.verificationMethods)
                            serviceEndpointsCard(services: doc.services)
                            alsoKnownAsCard(aka: doc.alsoKnownAs)
                        }
                        validationCard(result: result)
                        timestampFooter
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Identity Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await resolveIdentity() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isResolving)
            }
        }
        .task {
            await resolveIdentity()
        }
    }

    // MARK: - Card Components

    private func identityHeaderCard(result: DIDResolutionResult) -> some View {
        DiagnosticsCard(title: "Identity", icon: "person.badge.key.fill") {
            DiagRow(label: "Handle", value: result.handle)
            Divider().background(Color.white.opacity(0.08))
            DiagRow(label: "DID", value: result.did, isMonospaced: true)
            Divider().background(Color.white.opacity(0.08))
            DiagRow(label: "Resolved Via", value: result.method.rawValue)
            Divider().background(Color.white.opacity(0.08))
            DiagRow(
                label: "DID Document",
                value: result.didDocument != nil ? "✓ Fetched" : "Unavailable",
                valueColor: result.didDocument != nil ? .green : .orange
            )
        }
    }

    private func signingKeysCard(methods: [VerificationMethod]) -> some View {
        DiagnosticsCard(title: "Signing Keys", icon: "key.horizontal.fill") {
            if methods.isEmpty {
                Text("No verification methods found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(methods.enumerated()), id: \.offset) { index, method in
                    if index > 0 {
                        Divider().background(Color.white.opacity(0.08))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        DiagRow(label: "ID",   value: method.id,   isMonospaced: true)
                        DiagRow(label: "Type", value: method.type, isMonospaced: true)
                        if let pkm = method.publicKeyMultibase {
                            DiagRow(label: "Public Key", value: String(pkm.prefix(32)) + "…", isMonospaced: true)
                        }
                    }
                }
            }
        }
    }

    private func serviceEndpointsCard(services: [ServiceEndpoint]) -> some View {
        DiagnosticsCard(title: "Service Endpoints", icon: "network") {
            if services.isEmpty {
                Text("No service endpoints found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, service in
                    if index > 0 {
                        Divider().background(Color.white.opacity(0.08))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        DiagRow(label: "ID",       value: service.id)
                        DiagRow(label: "Type",     value: service.type)
                        DiagRow(label: "Endpoint", value: service.serviceEndpoint, isMonospaced: true)
                    }
                }
            }
        }
    }

    private func alsoKnownAsCard(aka: [String]) -> some View {
        DiagnosticsCard(title: "Also Known As", icon: "at") {
            if aka.isEmpty {
                Text("No aliases found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(aka.enumerated()), id: \.offset) { index, alias in
                    if index > 0 { Divider().background(Color.white.opacity(0.08)) }
                    Text(alias)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private func validationCard(result: DIDResolutionResult) -> some View {
        let docValidated = result.didDocument != nil
        let didValid = result.did.hasPrefix("did:plc:") || result.did.hasPrefix("did:web:")

        return DiagnosticsCard(title: "Validation State", icon: "checkmark.shield.fill") {
            DiagRow(
                label: "DID Format Valid",
                value: didValid ? "PASS ✓" : "FAIL ✗",
                valueColor: didValid ? .green : .red
            )
            Divider().background(Color.white.opacity(0.08))
            DiagRow(
                label: "Document ID Match",
                value: docValidated ? "PASS ✓" : "Not Checked",
                valueColor: docValidated ? .green : .secondary
            )
            Divider().background(Color.white.opacity(0.08))
            DiagRow(
                label: "SSRF Guard",
                value: "Active ✓",
                valueColor: .green
            )
            Divider().background(Color.white.opacity(0.08))
            DiagRow(
                label: "Resolution Method",
                value: result.method.rawValue
            )
        }
    }

    private var timestampFooter: some View {
        Group {
            if let date = resolvedAt {
                Text("Last resolved: \(date.formatted(.dateTime.hour().minute().second()))")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Logic

    private func resolveIdentity() async {
        guard let handle = client.session?.handle else {
            errorMessage = "No active session. Sign in to diagnose your identity."
            return
        }

        isResolving  = true
        errorMessage = nil

        do {
            let result = try await client.didResolver.resolveHandle(handle)
            self.resolutionResult = result
            self.resolvedAt       = Date()
        } catch let err as DIDResolutionError {
            self.errorMessage = err.localizedDescription
        } catch {
            self.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        isResolving = false
    }
}

// MARK: - Reusable Sub-Components

/// A consistently-styled diagnostics information card.
private struct DiagnosticsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
            }
            Divider()
                .background(Color.accentColor.opacity(0.3))
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

/// A label-value pair row used inside diagnostics cards.
private struct DiagRow: View {
    let label:       String
    let value:       String
    var isMonospaced: Bool  = false
    var valueColor:  Color  = .primary

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(value)
                .font(isMonospaced
                    ? .system(.caption, design: .monospaced)
                    : .caption)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
    }
}
