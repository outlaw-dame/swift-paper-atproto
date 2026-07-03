import XCTest
@testable import SwiftPaperATProtoCore

final class StoryClusteringTests: XCTestCase {
    
    // MARK: - Intent Classification Tests
    
    func testQueryIntentClassification() {
        XCTAssertEqual(StoryClustering.classifyQuery("@alice.bsky.social"), .profileSearch)
        XCTAssertEqual(StoryClustering.classifyQuery("did:plc:12345"), .profileSearch)
        XCTAssertEqual(StoryClustering.classifyQuery("#SwiftUI"), .tagSearch)
        XCTAssertEqual(StoryClustering.classifyQuery("refresh custom feed timeline"), .feedSearch)
        XCTAssertEqual(StoryClustering.classifyQuery("Yosemite trail hike photography"), .textSearch)
    }
    
    // MARK: - Story Grouping Tests
    
    func testStoryCompilationGrouping() {
        let formatter = ISO8601DateFormatter()
        let timeString = formatter.string(from: Date())
        
        let author1 = ProfileViewBasic(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice", avatar: "http://example.com/alice.png")
        let author2 = ProfileViewBasic(did: "did:plc:2", handle: "bob.bsky.social", displayName: "Bob", avatar: "http://example.com/bob.png")
        let author3 = ProfileViewBasic(did: "did:plc:3", handle: "charlie.bsky.social", displayName: "Charlie", avatar: nil)
        
        // 1. Group by domain: two posts linking to same host developer.apple.com
        let post1 = Post(
            uri: "at://did:plc:1/app.bsky.feed.post/101",
            cid: "cid101",
            author: author1,
            record: PostRecord(text: "Check out the Swift updates on Apple's developer website.", createdAt: timeString),
            embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "https://developer.apple.com/news/1", title: "Apple Developer News", description: "Details of swift release", thumb: nil)),
            replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        let post2 = Post(
            uri: "at://did:plc:2/app.bsky.feed.post/102",
            cid: "cid102",
            author: author2,
            record: PostRecord(text: "More Swift coverage from developer.apple.com. This is amazing.", createdAt: timeString),
            embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "https://developer.apple.com/news/2", title: "Swift Updates", description: "Details of API modifications", thumb: nil)),
            replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        
        // 2. Group by hashtag: two posts sharing #atproto
        let post3 = Post(
            uri: "at://did:plc:1/app.bsky.feed.post/103",
            cid: "cid103",
            author: author1,
            record: PostRecord(text: "Decentralized protocols are cool. #atproto", createdAt: timeString),
            embed: nil, replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        let post4 = Post(
            uri: "at://did:plc:3/app.bsky.feed.post/104",
            cid: "cid104",
            author: author3,
            record: PostRecord(text: "Building app structures on top of #atproto graph endpoints.", createdAt: timeString),
            embed: nil, replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        
        // 3. Standalone post: no matching tags or link hosts
        let post5 = Post(
            uri: "at://did:plc:2/app.bsky.feed.post/105",
            cid: "cid105",
            author: author2,
            record: PostRecord(text: "Just enjoying a coffee at home offline.", createdAt: timeString),
            embed: nil, replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        
        let posts = [post1, post2, post3, post4, post5]
        let compiledStories = StoryClustering.compileStories(from: posts)
        
        // Assertions:
        // We expect exactly 3 compiled story clusters:
        // - One domain story grouping developer.apple.com (post1 and post2)
        // - One hashtag story grouping #atproto (post3 and post4)
        // - One standalone story card containing post5
        XCTAssertEqual(compiledStories.count, 3)
        
        // Verify domain story details
        let domainStory = compiledStories.first(where: { $0.headline.contains("Apple") })
        XCTAssertNotNil(domainStory)
        XCTAssertEqual(domainStory?.contributingAuthors.count, 2)
        XCTAssertEqual(domainStory?.relatedPosts.count, 2)
        
        // Verify hashtag story details
        let tagStory = compiledStories.first(where: { $0.headline.contains("ATPROTO") })
        XCTAssertNotNil(tagStory)
        XCTAssertEqual(tagStory?.contributingAuthors.count, 2)
        XCTAssertEqual(tagStory?.relatedPosts.count, 2)
        
        // Verify standalone story
        let standaloneStory = compiledStories.first(where: { $0.relatedPosts.count == 1 })
        XCTAssertNotNil(standaloneStory)
        XCTAssertEqual(standaloneStory?.contributingAuthors.first?.handle, "bob.bsky.social")
    }
}
