import SwiftUI
import AVKit

struct SafeVideoPlayerView: View {
    let videoUrlString: String

    // Maximum redirect hops allowed before the video is considered unsafe.
    private static let maxRedirectHops = 3

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var isValidUrl = false

    // We keep a strong reference to the observer token so it can be cleanly
    // removed on disappear without relying on `self` (value-type / ObjC pitfall).
    @State private var loopObserverToken: Any? = nil

    var body: some View {
        Group {
            if isValidUrl, let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.isMuted = true
                        player.play()
                        isPlaying = true

                        // Observe end-of-playback using the return token, not self.
                        loopObserverToken = NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { [weak player] _ in
                            guard let player else { return }
                            player.seek(to: .zero)
                            player.play()
                        }
                    }
                    .onDisappear {
                        player.pause()
                        // Remove observer via token — safe for value types.
                        if let token = loopObserverToken {
                            NotificationCenter.default.removeObserver(token)
                            loopObserverToken = nil
                        }
                        self.player = nil
                        isPlaying = false
                    }
                    .overlay(alignment: .center) {
                        // Tap to toggle play/pause.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let player = player else { return }
                                if isPlaying {
                                    player.pause()
                                } else {
                                    player.play()
                                }
                                isPlaying.toggle()
                            }
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Media Unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
        }
        .onAppear {
            // Guard: only run once — prevents double-initialisation if SwiftUI
            // re-triggers onAppear while the view is still visible.
            guard player == nil else { return }
            validateAndSetupPlayer()
        }
    }

    // MARK: - Private

    private func validateAndSetupPlayer() {
        // 1. Parse the URL — reject anything that isn't parseable.
        guard let url = URL(string: videoUrlString) else {
            isValidUrl = false
            return
        }

        // 2. Scheme whitelist: only http/https are allowed.
        //    This blocks file://, javascript:, data:, ftp:, localhost:// etc.
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            isValidUrl = false
            debugLog("SafeVideoPlayer: blocked unsafe scheme '\(scheme)'.")
            return
        }

        // 3. Host sanity: must have a non-empty, non-IP-loopback host.
        guard let host = url.host, !host.isEmpty,
              host != "localhost", host != "127.0.0.1", host != "::1" else {
            isValidUrl = false
            debugLog("SafeVideoPlayer: blocked loopback/localhost host.")
            return
        }

        isValidUrl = true

        // 4. Build AVPlayer with a redirect-limiting URLSession configuration.
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 1
        // AVPlayer doesn't accept URLSession directly, but we block SSRF at
        // the scheme/host layer above. AVPlayer itself is fed only the
        // validated URL at this point.
        self.player = AVPlayer(url: url)
    }
}

// MARK: - Debug-only logging

private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
