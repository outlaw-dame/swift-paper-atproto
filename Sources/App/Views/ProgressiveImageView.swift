import SwiftUI
import SwiftPaperATProtoCore

struct ProgressiveImageView: View {
    let imageUrlString: String

    /// Maximum bytes allowed for a downloaded image (5 MB, same as cache limit).
    private static let maxDownloadBytes = 5 * 1024 * 1024

    @State private var uiImage: UIImage? = nil
    @State private var isDownloading = false
    @State private var showFullScreen = false
    @State private var zoomScale: CGFloat = 1.0

    // Task handle for cancellation when the view disappears.
    @State private var downloadTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(zoomScale)
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    zoomScale = zoomScale > 1.0 ? 1.0 : 2.5
                                }
                            }
                    )
                    .onTapGesture {
                        showFullScreen = true
                    }
            } else {
                ZStack {
                    Color.white.opacity(0.04)
                    if isDownloading {
                        ProgressView()
                            .tint(.accentColor)
                    } else {
                        Image(systemName: "photo.badge.arrow.down")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(minHeight: 120)
            }
        }
        .onAppear {
            guard uiImage == nil, downloadTask == nil else { return }
            loadImageData()
        }
        .onDisappear {
            // Cancel any in-flight download to prevent stale state writes.
            downloadTask?.cancel()
            downloadTask = nil
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenMediaView(uiImage: uiImage, isPresented: $showFullScreen)
        }
    }

    // MARK: - Private

    private func loadImageData() {
        // 1. Parse URL — reject unparseable strings outright.
        guard let url = URL(string: imageUrlString) else { return }

        // 2. Scheme whitelist — only http/https (case-insensitive).
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            debugLog("ProgressiveImageView: blocked unsafe scheme '\(scheme)'.")
            return
        }

        // 3. Loopback host rejection.
        if let host = url.host, host == "localhost" || host == "127.0.0.1" || host == "::1" {
            debugLog("ProgressiveImageView: blocked loopback host.")
            return
        }

        // 4. Cache-first read.
        if let cachedData = try? SecureMediaCache.shared.getCachedMedia(url: url),
           let image = UIImage(data: cachedData) {
            self.uiImage = image
            return
        }

        // 5. Remote download with size cap and Task-cancellation support.
        isDownloading = true
        downloadTask = Task {
            defer {
                Task { @MainActor in
                    self.isDownloading = false
                    self.downloadTask = nil
                }
            }

            do {
                // Use a dedicated ephemeral session: no credential/cookie sharing.
                let session = URLSession(configuration: .ephemeral)
                let (data, response) = try await session.data(from: url)

                // Check for Task cancellation after the await.
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    debugLog("ProgressiveImageView: non-2xx HTTP response.")
                    return
                }

                // Size cap: reject oversized payloads even if the server lied
                // about Content-Length.
                guard data.count <= Self.maxDownloadBytes else {
                    debugLog("ProgressiveImageView: response too large (\(data.count) bytes).")
                    return
                }

                // Validate that bytes are actually image data before caching.
                guard let image = UIImage(data: data) else {
                    debugLog("ProgressiveImageView: response is not a valid image.")
                    return
                }

                // Write to secure cache.
                try SecureMediaCache.shared.cacheMedia(url: url, data: data)

                await MainActor.run {
                    self.uiImage = image
                }
            } catch is CancellationError {
                debugLog("ProgressiveImageView: download task cancelled.")
            } catch {
                debugLog("ProgressiveImageView: download failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Full Screen Interactive Media Zoom View

struct FullScreenMediaView: View {
    let uiImage: UIImage?
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var dragOffset = CGSize.zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(dragOffset)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                // Clamp scale to a sensible range; prevents infinite zoom
                                // exploits via synthesised gesture events.
                                self.scale = max(0.8, min(4.0, value))
                            }
                            .onEnded { _ in
                                if scale < 1.0 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = 1.0
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale <= 1.2 {
                                    self.dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if scale <= 1.2, value.translation.height > 120 {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        isPresented = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = .zero
                                        // Don't snap scale back on drag end — only on pinch end.
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        dragOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    )
            } else {
                ProgressView().tint(.white)
            }

            // Close button — always on top.
            VStack {
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Debug-only logging

private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
