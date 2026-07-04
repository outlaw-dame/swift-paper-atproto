import SwiftUI
import WebKit
import SwiftPaperATProtoCore

#if os(iOS)
import SafariServices
#endif

/// A secure in-app web browser that handles external links safely.
/// Gated to HTTPS links only and blocks private loopbacks / metadata hosts.
struct BrowserSheetView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "shield.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Blocked Secure Link")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Dismiss") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    #if os(iOS)
                    SafariViewControllerRepresentable(url: url)
                        .ignoresSafeArea()
                    #else
                    WKWebViewRepresentable(url: url)
                        .ignoresSafeArea()
                    #endif
                }
            }
            .navigationTitle("Secure Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                validateURL()
            }
        }
    }

    private func validateURL() {
        let rawString = url.absoluteString
        
        // 1. Enforce HTTPS only (unless localhost is resolved, but loopback is blocked)
        guard url.scheme?.lowercased() == "https" else {
            loadError = "Only secure HTTPS connections are allowed."
            return
        }

        // 2. Run through ATProtoURLValidator external link gate (blocks loopbacks, RFC-1918 private space, metadata services)
        guard ATProtoURLValidator.isAllowedExternalURL(rawString) else {
            loadError = "Access blocked: This host is unsafe or restricted."
            return
        }
    }
}

// MARK: - iOS Safari representation

#if os(iOS)
struct SafariViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: configuration)
        vc.preferredControlTintColor = .systemBlue
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif

// MARK: - macOS WKWebView fallback representation

struct WKWebViewRepresentable: ViewRepresentable {
    let url: URL

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #else
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #endif
}

// MARK: - Cross-Platform ViewRepresentable protocol alias

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#else
typealias ViewRepresentable = UIViewRepresentable
#endif
