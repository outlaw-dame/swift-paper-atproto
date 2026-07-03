import SwiftUI
import SwiftPaperATProtoCore

struct FeedView: View {
    @EnvironmentObject var client: ATProtoClient
    @EnvironmentObject var store: LocalStore
    
    @State private var posts: [FeedViewPost] = []
    @State private var selectedPost: FeedViewPost? = nil
    @State private var isRefreshing = false
    @State private var loadingError: String? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                    VStack(spacing: 0) {
                        if let selected = selectedPost {
                            HeroPostCard(feedItem: selected)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .id(selected.id)
                        } else {
                            ContentUnavailableView("Select a Story", systemImage: "hand.tap", description: Text("Tap a story card below to inspect content details."))
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline Stories")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 12)
                            
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
                                .padding(.bottom, 20)
                            }
                        }
                        .background(Color.white.opacity(0.02))
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

struct HeroPostCard: View {
    let feedItem: FeedViewPost
    @EnvironmentObject var store: LocalStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    if let avatar = feedItem.post.author.avatar, let avatarURL = URL(string: avatar) {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feedItem.post.author.displayName ?? feedItem.post.author.handle)
                            .font(.headline)
                        Text("@\(feedItem.post.author.handle)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        store.toggleSavePost(uri: feedItem.post.uri)
                    } label: {
                        Image(systemName: store.isSaved(uri: feedItem.post.uri) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(store.isSaved(uri: feedItem.post.uri) ? .yellow : .secondary)
                    }
                }
                
                Text(feedItem.post.record.text)
                    .font(.body)
                    .lineSpacing(4)
                
                if let embed = feedItem.post.embed {
                    if let images = embed.images, !images.isEmpty, let imageURL = URL(string: images[0].thumb) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxHeight: 220)
                        .cornerRadius(12)
                        .clipped()
                    } else if let external = embed.external {
                        Link(destination: URL(string: external.uri) ?? URL(string: "https://bsky.app")!) {
                            HStack(spacing: 12) {
                                if let thumb = external.thumb, let thumbURL = URL(string: thumb) {
                                    AsyncImage(url: thumbURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 70, height: 70)
                                    .cornerRadius(8)
                                    .clipped()
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(external.title)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                    Text(external.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Label("\(feedItem.post.likeCount ?? 0)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Label("\(feedItem.post.replyCount ?? 0)", systemImage: "bubble.right.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if let abuseScore = store.localAbuseScores[feedItem.post.uri] {
                        Text(String(format: "Local Safety: %.0f%%", (1.0 - abuseScore) * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(abuseScore > 0.3 ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(abuseScore > 0.3 ? .orange : .green)
                            .cornerRadius(6)
                    }
                }
                
                NavigationLink(destination: ThreadView(postUri: feedItem.post.uri)) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.and.down.and.sparkles")
                        Text("Analyze Full Conversation Thread")
                        Spacer()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                }
                .tint(.primary)
            }
            .padding()
        }
    }
}

struct PostCardThumbnail: View {
    let feedItem: FeedViewPost
    let isSelected: Bool
    @EnvironmentObject var store: LocalStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let avatar = feedItem.post.author.avatar, let avatarURL = URL(string: avatar) {
                    AsyncImage(url: avatarURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                
                Text(feedItem.post.author.displayName ?? feedItem.post.author.handle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Spacer()
                
                if !store.isRead(uri: feedItem.post.uri) {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.5, blue: 0.9))
                        .frame(width: 6, height: 6)
                }
            }
            
            Text(feedItem.post.record.text)
                .font(.caption2)
                .lineLimit(3)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(12)
        .frame(width: 170, height: 120)
        .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color(red: 0.1, green: 0.5, blue: 0.9) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}
