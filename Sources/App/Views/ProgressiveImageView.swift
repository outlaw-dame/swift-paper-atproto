import SwiftUI
import SwiftPaperATProtoCore

struct ProgressiveImageView: View {
    let imageUrlString: String
    
    @State private var uiImage: UIImage? = nil
    @State private var isDownloading = false
    @State private var showFullScreen = false
    
    // Zoom Gesture States
    @State private var zoomScale: CGFloat = 1.0
    
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
                                    if zoomScale > 1.0 {
                                        zoomScale = 1.0
                                    } else {
                                        zoomScale = 2.5
                                    }
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
                .frame(minHeight: 200)
            }
        }
        .onAppear {
            loadImageData()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenMediaView(uiImage: uiImage, isPresented: $showFullScreen)
        }
    }
    
    private func loadImageData() {
        guard let url = URL(string: imageUrlString) else { return }
        
        // Gate URL scheme (only http/https)
        guard url.scheme == "http" || url.scheme == "https" else { return }
        
        // 1. Try reading from secure local cache
        if let cachedData = try? SecureMediaCache.shared.getCachedMedia(url: url),
           let image = UIImage(data: cachedData) {
            self.uiImage = image
            return
        }
        
        // 2. Download from remote if not cached
        isDownloading = true
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    isDownloading = false
                    return
                }
                
                // Save to cache
                try SecureMediaCache.shared.cacheMedia(url: url, data: data)
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.uiImage = image
                    }
                }
            } catch {
                print("Failed to download or cache media image: \(error.localizedDescription)")
            }
            await MainActor.run {
                isDownloading = false
            }
        }
    }
}

// MARK: - Full Screen Interactive Media Zoom View (Tactile Paper Style)

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
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                self.scale = max(0.8, min(4.0, value))
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Only swipe down to dismiss if not highly zoomed in
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
                                        self.dragOffset = .zero
                                        self.scale = 1.0
                                    }
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    )
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            // Close Button
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
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
