import SwiftUI
import SwiftPaperATProtoCore

struct ExploreView: View {
    @State private var searchQuery = ""
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Topics", "Media", "Feeds", "People"]
    
    let stories = [
        GroupedStory(
            title: "Decentralized Social Ecosystem Gains Momentum",
            summary: "Developers are building local-first, safety-aware applications utilizing the AT Protocol and custom server-side pipelines.",
            category: "Topics",
            imageName: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600",
            sources: [
                ProfileViewBasic(did: "did:1", handle: "alice.bsky.social", displayName: "Alice", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100"),
                ProfileViewBasic(did: "did:2", handle: "bob_dev.bsky.social", displayName: "Bob", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100")
            ],
            postCount: 8
        ),
        GroupedStory(
            title: "WWDC Swift & SwiftUI Gesture Paradigms",
            summary: "Apple engineering teams introduce interactive animation transitions and responsive scroll behaviors for fluid layouts.",
            category: "Media",
            imageName: "https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=600",
            sources: [
                ProfileViewBasic(did: "did:3", handle: "tech_insider.bsky.social", displayName: "Tech Insider", avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100")
            ],
            postCount: 5
        ),
        GroupedStory(
            title: "Nature Resets & Yosemite Trails",
            summary: "Travel enthusiasts emphasize Yosemite National Valley highlights and offline nature walks as the ultimate lifestyle restore.",
            category: "Feeds",
            imageName: "https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=600",
            sources: [
                ProfileViewBasic(did: "did:4", handle: "nature_pics.bsky.social", displayName: "Nature Daily", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100")
            ],
            postCount: 3
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Explore")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(brandGradient)
                        
                        Text("Grouped developments resolved from your graph")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search topics, feeds, DIDs...", text: $searchQuery)
                            .textFieldStyle(.plain)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedFilter = filter
                                    }
                                } label: {
                                    Text(filter)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? Color.accentColor : Color.white.opacity(0.06))
                                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(selectedFilter == filter ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Stories For You")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let filteredStories = stories.filter {
                            selectedFilter == "All" || $0.category == selectedFilter
                        }
                        
                        ForEach(filteredStories) { story in
                            StoryCardView(story: story)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
    }
}

struct GroupedStory: Identifiable {
    var id: String { title }
    let title: String
    let summary: String
    let category: String
    let imageName: String
    let sources: [ProfileViewBasic]
    let postCount: Int
}

struct StoryCardView: View {
    let story: GroupedStory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = URL(string: story.imageName) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.05))
                }
                .frame(height: 140)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(story.category.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
                
                Text(story.title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(story.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    HStack(spacing: -8) {
                        ForEach(story.sources) { profile in
                            if let avatar = profile.avatar, let avatarURL = URL(string: avatar) {
                                AsyncImage(url: avatarURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle().fill(Color.gray)
                                }
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            }
                        }
                    }
                    
                    Text("\(story.postCount) related references")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
