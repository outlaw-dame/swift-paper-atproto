import SwiftUI
import SwiftPaperATProtoCore

struct FeedView: View {
    @EnvironmentObject var client: ATProtoClient
    @EnvironmentObject var store: LocalStore
    
    @State private var posts: [FeedViewPost] = []
    @State private var selectedPost: FeedViewPost? = nil
    @State private var isRefreshing = false
    @State private var loadingError: String? = nil
    
    // HIG Gesture States for Card Transitions
    @State private var isCardExpanded = false
    @State private var cardDragOffset: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar (Hidden when card is fully expanded for full-screen immersive reading)
                if !isCardExpanded {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paper-ATProto")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(brandGradient)
                            
                            if client.useMockData {
                                Text("Offline Demo Mode")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                Text("@\(client.session?.handle ?? "anonymous")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            refreshTimeline()
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .disabled(isRefreshing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if isRefreshing && posts.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.accentColor)
                    Spacer()
                } else if posts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No posts available.")
                            .font(.headline)
                        Text("Pull down or tap refresh above to pull content.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            // Top Highlight Panel (Hero Card with Drag Gesture Expansion)
                            if let selected = selectedPost {
                                HeroPostCard(feedItem: selected, isExpanded: isCardExpanded)
                                    .frame(height: isCardExpanded ? geo.size.height : geo.size.height * 0.65)
                                    .offset(y: cardDragOffset)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let dragHeight = value.translation.height
                                                if isCardExpanded {
                                                    // Only allow pulling down when expanded
                                                    if dragHeight > 0 {
                                                        cardDragOffset = dragHeight
                                                    }
                                                } else {
                                                    // Only allow pulling up when collapsed
                                                    if dragHeight < 0 {
                                                        cardDragOffset = dragHeight
                                                    }
                                                }
                                            }
                                            .onEnded { value in
                                                let dragHeight = value.translation.height
                                                let velocity = value.predictedEndTranslation.height - value.translation.height
                                                
                                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                                    if isCardExpanded {
                                                        // Pull down to collapse
                                                        if dragHeight > 100 || velocity > 120 {
                                                            isCardExpanded = false
                                                        }
                                                    } else {
                                                        // Pull up to expand
                                                        if dragHeight < -100 || velocity < -120 {
                                                            isCardExpanded = true
                                                        }
                                                    }
                                                    cardDragOffset = 0.0
                                                }
                                            }
                                    )
                                    .id(selected.id)
                            } else {
                                ContentUnavailableView("Select a Story", systemImage: "hand.tap", description: Text("Tap a story card below to inspect content details."))
                            }
                            
                            if !isCardExpanded {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Bottom horizontal cards deck
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Timeline Stories")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("Swipe up on card to expand")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(posts) { item in
                                                PostCardThumbnail(feedItem: item, isSelected: item.id == selectedPost?.id)
                                                    .onTapGesture {
                                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                            selectedPost = item
                                                            store.markAsRead(uri: item.post.uri)
                                                        }
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.bottom, 16)
                                    }
                                }
                                .background(Color.white.opacity(0.01))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadInitialTimeline()
        }
        .navigationBarHidden(true)
    }
    
    private func loadInitialTimeline() {
        if !store.cachedFeed.isEmpty {
            self.posts = store.cachedFeed
            self.selectedPost = self.posts.first
        } else {
            refreshTimeline()
        }
    }
    
    private func refreshTimeline() {
        isRefreshing = true
        loadingError = nil
        
        Task {
            do {
                let response = try await client.fetchTimeline()
                store.cacheFeed(response.feed)
                self.posts = response.feed
                if self.selectedPost == nil || !self.posts.contains(where: { $0.id == self.selectedPost?.id }) {
                    self.selectedPost = self.posts.first
                }
            } catch {
                self.loadingError = error.localizedDescription
            }
            isRefreshing = false
        }
    }
}
