import SwiftUI
import SwiftPaperATProtoCore

struct DiscoveryView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var client: ATProtoClient
    
    @State private var searchText = ""
    @State private var selectedIntent: SearchIntent = .tagSearch
    @State private var stories: [GroupedStory] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Search Input Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search topics, handles, or intents...", text: $searchText)
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { oldVal, newVal in
                                updateIntentClassification(for: newVal)
                            }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                updateIntentClassification(for: "")
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    
                    // Search Intent Classifier Status Badge
                    HStack {
                        Text("Detected Search Intent:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(selectedIntent.rawValue)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Gist Intent Pills selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SearchIntent.allCases, id: \.self) { intent in
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedIntent = intent
                                }
                            } label: {
                                Text(intent.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedIntent == intent ? Color.accentColor : Color.white.opacity(0.05))
                                    .foregroundColor(selectedIntent == intent ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Grouped Narrative List
                ScrollView {
                    VStack(spacing: 16) {
                        let filteredStories = getFilteredStories()
                        
                        if filteredStories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No story clusters found.")
                                    .font(.headline)
                                Text("Try changing filters or search values.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredStories) { story in
                                NavigationLink(destination: StoryDetailView(story: story)) {
                                    StoryGistCard(story: story)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Explore & Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStories()
        }
    }
    
    private func loadStories() {
        // Collect all posts cached locally in the ObjectBox store
        let posts = store.cachedFeed.map { $0.post }
        self.stories = StoryClustering.compileStories(from: posts)
    }
    
    private func updateIntentClassification(for query: String) {
        if query.isEmpty {
            selectedIntent = .tagSearch
        } else {
            selectedIntent = StoryClustering.classifyQuery(query)
        }
    }
    
    private func getFilteredStories() -> [GroupedStory] {
        var baseStories = stories
        
        // Filter by text search if matching
        if !searchText.isEmpty {
            let term = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            baseStories = baseStories.filter { story in
                story.headline.lowercased().contains(term) ||
                story.summary.lowercased().contains(term) ||
                story.contributingAuthors.contains(where: { $0.handle.lowercased().contains(term) })
            }
        }
        
        // Filter layout items based on selected Gist Intent Pill category
        switch selectedIntent {
        case .profileSearch:
            // Stories containing matches for direct profile handles
            return baseStories.filter { $0.contributingAuthors.count == 1 }
        case .tagSearch:
            // Dialogues grouped by trending hashtags
            return baseStories.filter { $0.headline.contains("Dialogue") }
        case .feedSearch:
            // Media news feeds clustered by URL domains
            return baseStories.filter { $0.headline.contains("Perspective") }
        case .textSearch:
            // Show all general story topics
            return baseStories
        }
    }
}

// MARK: - Components

struct StoryGistCard: View {
    let story: GroupedStory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.headline)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Text(story.summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            HStack {
                OverlappingAvatarsView(authors: story.contributingAuthors)
                Spacer()
                Text("\(story.relatedPosts.count) reference\(story.relatedPosts.count == 1 ? "" : "s")")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct OverlappingAvatarsView: View {
    let authors: [ProfileViewBasic]
    
    var body: some View {
        HStack(spacing: -8) {
            ForEach(authors.prefix(4), id: \.self) { author in
                if let avatar = author.avatar, let avatarURL = URL(string: avatar) {
                    AsyncImage(url: avatarURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.gray)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                }
            }
            if authors.count > 4 {
                Text("+\(authors.count - 4)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
            }
        }
    }
}

struct StoryDetailView: View {
    let story: GroupedStory
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gist Outline")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        
                        Text(story.headline)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text(story.summary)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                    
                    Text("Related References")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    ForEach(story.relatedPosts, id: \.self) { post in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if let avatar = post.author.avatar, let avatarURL = URL(string: avatar) {
                                    AsyncImage(url: avatarURL) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle().fill(Color.gray)
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(post.author.displayName ?? post.author.handle)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text("@\(post.author.handle)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Text(post.record.text)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Narrative Detail")
    }
}
