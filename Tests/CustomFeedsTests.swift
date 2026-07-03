import XCTest
import ObjectBox
@testable import SwiftPaperATProtoCore

final class CustomFeedsTests: XCTestCase {
    
    private var client: ATProtoClient!
    private var store: LocalStore!
    
    @MainActor
    override func setUp() {
        super.setUp()
        client = ATProtoClient()
        client.useMockData = true
        store = LocalStore(inMemoryName: "test_feeds_db_\(UUID().uuidString)")
    }
    
    @MainActor
    override func tearDown() {
        client = nil
        store.clearCache()
        store = nil
        super.tearDown()
    }
    
    // MARK: - SSRF & Path Traversal URI Validation Tests
    
    @MainActor
    func testFeedGeneratorUriGating() {
        // 1. Valid AT Feed Generator URI
        let validUri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.generator/tech-feed"
        XCTAssertTrue(client.validateFeedGeneratorURI(validUri))
        
        // 2. Traversal Injection Attack (SSRF/IDOR target)
        let traversalUri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.generator/../../passwd"
        XCTAssertFalse(client.validateFeedGeneratorURI(traversalUri))
        
        // 3. Spoofed collection targeting profile repo records
        let spoofedUri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.actor.profile/self"
        XCTAssertFalse(client.validateFeedGeneratorURI(spoofedUri))
        
        // 4. Raw host domain SSRF injection attempt
        let externalHostUri = "at://example.com/app.bsky.feed.generator/tech"
        XCTAssertFalse(client.validateFeedGeneratorURI(externalHostUri))
    }
    
    // MARK: - Clamped Algorithmic Sorting Boundaries Tests
    
    @MainActor
    func testClampedReRankingBounds() {
        let authors = [
            ProfileViewBasic(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Smith", avatar: nil)
        ]
        
        // Setup cache with custom items to inspect calculated sorting values
        let rawPosts = [
            Post(
                uri: "at://did:plc:1/app.bsky.feed.post/1",
                cid: "c1",
                author: authors[0],
                record: PostRecord(text: "Standard fresh post", createdAt: ISO8601DateFormatter().string(from: Date())),
                embed: nil, replyCount: 0, repostCount: 0, likeCount: 0,
                indexedAt: ISO8601DateFormatter().string(from: Date())
            ),
            Post(
                uri: "at://did:plc:1/app.bsky.feed.post/2",
                cid: "c2",
                author: authors[0],
                record: PostRecord(text: "Abusive post", createdAt: ISO8601DateFormatter().string(from: Date())),
                embed: nil, replyCount: 0, repostCount: 0, likeCount: 0,
                indexedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        
        let feedItems = rawPosts.map { FeedViewPost(post: $0) }
        store.cacheFeed(feedItems)
        
        // Add extreme high abuse score for post 2
        store.localAbuseScores["at://did:plc:1/app.bsky.feed.post/2"] = 5.0 // Out of normal bounds
        
        // Add bookmark for post 1
        store.savedPostUris.insert("at://did:plc:1/app.bsky.feed.post/1")
        
        // Calculate rankings
        let sorted = store.getLocalSortedFeed()
        
        XCTAssertEqual(sorted.count, 2)
        
        // Post 1 (bookmarked) should be first, Post 2 (abusive) should be second.
        XCTAssertEqual(sorted[0].post.uri, "at://did:plc:1/app.bsky.feed.post/1")
        XCTAssertEqual(sorted[1].post.uri, "at://did:plc:1/app.bsky.feed.post/2")
    }
    
    // MARK: - ObjectBox Database Feed Subscriptions
    
    @MainActor
    func testFeedSubscriptionAndPinOperations() {
        XCTAssertEqual(store.pinnedFeeds.count, 0)
        
        let feedUri = "at://did:plc:123/app.bsky.feed.generator/tech-news"
        
        // 1. Subscribe
        store.subscribeToFeed(
            uri: feedUri,
            displayName: "Tech News",
            description: "Updates on developer frameworks.",
            avatar: "avatar_link"
        )
        
        // Pinned by default on subscription
        XCTAssertEqual(store.pinnedFeeds.count, 1)
        XCTAssertEqual(store.pinnedFeeds.first?.displayName, "Tech News")
        XCTAssertEqual(store.pinnedFeeds.first?.uri, feedUri)
        
        // 2. Unpin / Toggle pin state
        store.togglePinFeed(uri: feedUri)
        XCTAssertEqual(store.pinnedFeeds.count, 0)
        
        // 3. Re-pin
        store.togglePinFeed(uri: feedUri)
        XCTAssertEqual(store.pinnedFeeds.count, 1)
    }
}
