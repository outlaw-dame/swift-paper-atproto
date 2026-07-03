import Foundation

public enum SearchIntent: String, Codable, CaseIterable {
    case profileSearch = "Profile"
    case tagSearch = "Topic"
    case feedSearch = "Feeds"
    case textSearch = "Media & Text"
}

public struct GroupedStory: Codable, Identifiable, Hashable {
    public let id: UUID
    public let headline: String
    public let summary: String
    public let contributingAuthors: [ProfileViewBasic]
    public let relatedPosts: [Post]
    
    public init(id: UUID = UUID(), headline: String, summary: String, contributingAuthors: [ProfileViewBasic], relatedPosts: [Post]) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.contributingAuthors = contributingAuthors
        self.relatedPosts = relatedPosts
    }
}

public final class StoryClustering {
    
    // MARK: - Query Intent Classifier
    public static func classifyQuery(_ query: String) -> SearchIntent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmed.hasPrefix("@") || trimmed.hasPrefix("did:") {
            return .profileSearch
        } else if trimmed.hasPrefix("#") {
            return .tagSearch
        } else if trimmed.contains("feed") || trimmed.contains("timeline") || trimmed.contains("list") {
            return .feedSearch
        } else {
            return .textSearch
        }
    }
    
    // MARK: - Semantic Clustering Compiler
    public static func compileStories(from posts: [Post]) -> [GroupedStory] {
        guard !posts.isEmpty else { return [] }
        
        var stories: [GroupedStory] = []
        var processedPostUris = Set<String>()
        
        // Helper to parse domain hostnames
        func getDomain(from urlString: String) -> String? {
            guard let url = URL(string: urlString), let host = url.host else { return nil }
            return host.replacingOccurrences(of: "www.", with: "")
        }
        
        // Helper to extract hashtags
        func getHashtags(from text: String) -> [String] {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            return words.filter { $0.hasPrefix("#") && $0.count > 2 }
                .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased() }
        }
        
        // 1. Group by common External Embed Domains
        var domainGroups: [String: [Post]] = [:]
        for post in posts {
            if let externalUri = post.embed?.external?.uri, let domain = getDomain(from: externalUri) {
                domainGroups[domain, default: []].append(post)
            }
        }
        
        for (domain, groupPosts) in domainGroups where groupPosts.count >= 2 {
            let title = groupPosts.first?.embed?.external?.title ?? "Developments on \(domain.capitalized)"
            let headline = "Shared Perspective: \(title)"
            
            let summary = groupPosts.map { "• @\($0.author.handle): \"\($0.record.text.prefix(60))...\"" }.joined(separator: "\n")
            let authors = Array(Set(groupPosts.map { $0.author })).sorted(by: { $0.handle < $1.handle })
            
            stories.append(GroupedStory(
                headline: headline,
                summary: summary,
                contributingAuthors: authors,
                relatedPosts: groupPosts
            ))
            
            for p in groupPosts { processedPostUris.insert(p.uri) }
        }
        
        // 2. Group by Common Hashtags
        var tagGroups: [String: [Post]] = [:]
        for post in posts where !processedPostUris.contains(post.uri) {
            let tags = getHashtags(from: post.record.text)
            for tag in tags {
                tagGroups[tag, default: []].append(post)
            }
        }
        
        for (tag, groupPosts) in tagGroups where groupPosts.count >= 2 {
            let headline = "Trending Dialogue: #\(tag.uppercased())"
            let summary = groupPosts.map { "• @\($0.author.handle): \"\($0.record.text.prefix(60))...\"" }.joined(separator: "\n")
            let authors = Array(Set(groupPosts.map { $0.author })).sorted(by: { $0.handle < $1.handle })
            
            stories.append(GroupedStory(
                headline: headline,
                summary: summary,
                contributingAuthors: authors,
                relatedPosts: groupPosts
            ))
            
            for p in groupPosts { processedPostUris.insert(p.uri) }
        }
        
        // 3. Collect remaining individual highlights
        for post in posts where !processedPostUris.contains(post.uri) {
            let headline = post.embed?.external?.title ?? "Featured Post by @\(post.author.handle)"
            let summary = post.record.text
            
            stories.append(GroupedStory(
                headline: headline,
                summary: summary,
                contributingAuthors: [post.author],
                relatedPosts: [post]
            ))
        }
        
        return stories
    }
}
