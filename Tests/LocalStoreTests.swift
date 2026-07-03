import XCTest
import ObjectBox
@testable import SwiftPaperATProtoCore

final class LocalStoreTests: XCTestCase {
    
    private var store: LocalStore!
    
    @MainActor
    override func setUp() {
        super.setUp()
        // Initialize with a unique in-memory name to prevent tests from writing files on disk
        store = LocalStore(inMemoryName: "test_db_\(UUID().uuidString)")
    }
    
    @MainActor
    override func tearDown() {
        store.clearCache()
        store = nil
        super.tearDown()
    }
    
    // MARK: - Basic Caching & Persistence Mappings
    
    @MainActor
    func testCacheFeedFeedRetrieval() {
        let postItem = createSampleFeedViewPost(uri: "at://did:plc:1/app.bsky.feed.post/101", text: "Hello Swift World")
        store.cacheFeed([postItem])
        
        XCTAssertEqual(store.cachedFeed.count, 1)
        XCTAssertEqual(store.cachedFeed.first?.post.uri, "at://did:plc:1/app.bsky.feed.post/101")
        XCTAssertEqual(store.cachedFeed.first?.post.record.text, "Hello Swift World")
    }
    
    // MARK: - Bookmark / Read State Updates
    
    @MainActor
    func testToggleBookmarksAndReadStates() {
        let uri = "at://did:plc:1/app.bsky.feed.post/102"
        let postItem = createSampleFeedViewPost(uri: uri, text: "Cache details test")
        store.cacheFeed([postItem])
        
        // Assert initial unbookmarked/unread
        XCTAssertFalse(store.isSaved(uri: uri))
        XCTAssertFalse(store.isRead(uri: uri))
        
        // Toggle Bookmark
        store.toggleSavePost(uri: uri)
        XCTAssertTrue(store.isSaved(uri: uri))
        
        // Toggle Read
        store.markAsRead(uri: uri)
        XCTAssertTrue(store.isRead(uri: uri))
    }
    
    // MARK: - 7-Day Cache Eviction Rules
    
    @MainActor
    func testCacheEvictionRules() {
        let formatter = ISO8601DateFormatter()
        
        // 1. Post older than 7 days, unbookmarked -> Should be evicted
        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
        let oldPost = createSampleFeedViewPost(
            uri: "at://did:plc:1/app.bsky.feed.post/old",
            text: "Old post",
            createdAt: formatter.string(from: tenDaysAgo)
        )
        
        // 2. Post older than 7 days, but bookmarked -> Should NOT be evicted
        let oldBookmarkedPost = createSampleFeedViewPost(
            uri: "at://did:plc:1/app.bsky.feed.post/old_saved",
            text: "Old saved post",
            createdAt: formatter.string(from: tenDaysAgo)
        )
        
        // 3. Post recent (2 days old), unbookmarked -> Should NOT be evicted
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let recentPost = createSampleFeedViewPost(
            uri: "at://did:plc:1/app.bsky.feed.post/recent",
            text: "Recent post",
            createdAt: formatter.string(from: twoDaysAgo)
        )
        
        // Cache posts in database
        store.cacheFeed([oldPost, oldBookmarkedPost, recentPost])
        
        // Mark oldBookmarkedPost as saved
        store.toggleSavePost(uri: "at://did:plc:1/app.bsky.feed.post/old_saved")
        
        // Run eviction sweep explicitly
        store.evictOldUnbookmarkedPosts()
        
        // Verify results
        let cachedUris = store.cachedFeed.map { $0.post.uri }
        
        // Old post should be purged
        XCTAssertFalse(cachedUris.contains("at://did:plc:1/app.bsky.feed.post/old"))
        
        // Old saved post must be retained
        XCTAssertTrue(cachedUris.contains("at://did:plc:1/app.bsky.feed.post/old_saved"))
        
        // Recent post must be retained
        XCTAssertTrue(cachedUris.contains("at://did:plc:1/app.bsky.feed.post/recent"))
    }
    
    // MARK: - Self-Healing Caching Tests
    
    @MainActor
    func testSelfHealingCorruptedEntries() {
        // 1. Add valid entry
        let validPost = createSampleFeedViewPost(uri: "at://did:plc:1/app.bsky.feed.post/valid", text: "Healthy content")
        
        // 2. Add malformed/corrupted entry (e.g. invalid URI scheme matching IDOR/Path Traversal attempts)
        let corruptPost = createSampleFeedViewPost(uri: "corrupt-traversal-scheme/../etc", text: "Malicious metadata payload")
        
        store.cacheFeed([validPost, corruptPost])
        
        // Self-healing database load runs automatically in cacheFeed, checking validations.
        // It must purge the corrupt entry, retaining only the valid one.
        XCTAssertEqual(store.cachedFeed.count, 1)
        XCTAssertEqual(store.cachedFeed.first?.post.uri, "at://did:plc:1/app.bsky.feed.post/valid")
    }
    
    // MARK: - Helper Builder
    private func createSampleFeedViewPost(uri: String, text: String, createdAt: String = "2026-07-03T12:00:00Z") -> FeedViewPost {
        let author = ProfileViewBasic(
            did: "did:plc:test",
            handle: "tester.bsky.social",
            displayName: "Tester",
            avatar: "http://example.com/avatar.png"
        )
        let record = PostRecord(text: text, createdAt: createdAt)
        let post = Post(
            uri: uri,
            cid: "cid-test",
            author: author,
            record: record,
            embed: nil,
            replyCount: 0,
            repostCount: 0,
            likeCount: 0,
            indexedAt: createdAt
        )
        return FeedViewPost(post: post)
    }
}
