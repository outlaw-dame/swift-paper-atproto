import SwiftUI
import AVKit

struct SafeVideoPlayerView: View {
    let videoUrlString: String
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var isValidUrl = false
    
    var body: some View {
        Group {
            if isValidUrl, let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.isMuted = true
                        player.play()
                        isPlaying = true
                        
                        // Setup loop playback notification
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                    }
                    .onDisappear {
                        player.pause()
                        self.player = nil
                        isPlaying = false
                        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                    }
                    .overlay(
                        Button {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 6)
                        }
                        .opacity(0.0) // Transparent overlay area to capture taps, showing indicator only briefly
                    )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Invalid Video Protocol")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
        }
        .onAppear {
            validateAndSetupPlayer()
        }
    }
    
    private func validateAndSetupPlayer() {
        guard let url = URL(string: videoUrlString) else {
            isValidUrl = false
            return
        }
        
        // Hardening Boundary: Only allow http / https schemes to prevent local resource execution
        guard url.scheme == "http" || url.scheme == "https" else {
            isValidUrl = false
            print("SafeVideoPlayer: Gated local/unsafe url connection attempt.")
            return
        }
        
        isValidUrl = true
        self.player = AVPlayer(url: url)
    }
}
