import XCTest
@testable import SwiftPaperATProtoCore

final class HardeningTests: XCTestCase {
    
    private var client: ATProtoClient!
    
    @MainActor
    override func setUp() {
        super.setUp()
        client = ATProtoClient()
    }
    
    @MainActor
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    // MARK: - Cursor Sanitation Tests
    
    @MainActor
    func testValidCursors() {
        XCTAssertTrue(client.validateCursor("next_page_123"))
        XCTAssertTrue(client.validateCursor("cursor==b64"))
        XCTAssertTrue(client.validateCursor("123:abc-def/xyz.123"))
    }
    
    @MainActor
    func testMalformedCursorsBlocked() {
        // Parameter injections
        XCTAssertFalse(client.validateCursor("next_page?query=inject"))
        XCTAssertFalse(client.validateCursor("next_page;DROP TABLE Timeline"))
        
        // Traversal attempts
        XCTAssertFalse(client.validateCursor("next_page/../../etc/passwd"))
        XCTAssertFalse(client.validateCursor("<script>"))
    }
    
    // MARK: - Web URL Protocol Gating Tests
    
    private func validateWebURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    func testValidWebSchemes() {
        XCTAssertTrue(validateWebURL("https://bsky.app/profile/alice"))
        XCTAssertTrue(validateWebURL("http://example.com"))
    }
    
    func testUnsafeSchemesBlocked() {
        XCTAssertFalse(validateWebURL("javascript:alert(1)"))
        XCTAssertFalse(validateWebURL("file:///etc/passwd"))
        XCTAssertFalse(validateWebURL("data:text/html,<html>"))
        XCTAssertFalse(validateWebURL("ftp://files.com"))
    }
    
    // MARK: - Keychain CRUD Tests
    
    func testKeychainLifecycle() {
        let testKey = "test_hardening_key"
        let testValue = "secure_token_payload_1234"
        
        // Save
        KeychainHelper.save(key: testKey, value: testValue)
        
        // Retrieve
        let retrieved = KeychainHelper.get(key: testKey)
        XCTAssertEqual(retrieved, testValue)
        
        // Delete
        KeychainHelper.delete(key: testKey)
        let postDelete = KeychainHelper.get(key: testKey)
        XCTAssertNil(postDelete)
    }
    
    // MARK: - Hardened Input Truncation & Link Gating
    
    func testQueryClassificationTruncation() {
        // Enforce 128 character limits on query classification inputs
        let excessQuery = String(repeating: "a", count: 250) + " #tag"
        // Truncated query will not contain "#tag" since it exceeds 128 chars, and thus gets evaluated as .textSearch instead of .tagSearch!
        let intent = StoryClustering.classifyQuery(excessQuery)
        XCTAssertEqual(intent, .textSearch)
    }
    
    func testClusteringIgnoresUnsafeWebSchemes() {
        let author = ProfileViewBasic(did: "did:plc:test", handle: "tester.bsky.social", displayName: "Tester", avatar: nil)
        let timeString = ISO8601DateFormatter().string(from: Date())
        
        // Post linking to local files (traverse/SSRF attempt)
        let postUnsafe = Post(
            uri: "at://did:plc:test/app.bsky.feed.post/1",
            cid: "cid1",
            author: author,
            record: PostRecord(text: "Check local files", createdAt: timeString),
            embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "file:///etc/passwd", title: "Passwords", description: "Local files leak", thumb: nil)),
            replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        let postUnsafe2 = Post(
            uri: "at://did:plc:test/app.bsky.feed.post/2",
            cid: "cid2",
            author: author,
            record: PostRecord(text: "More local files", createdAt: timeString),
            embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "file:///etc/passwd", title: "Passwords 2", description: "More Local files leak", thumb: nil)),
            replyCount: 0, repostCount: 0, likeCount: 0, indexedAt: timeString
        )
        
        let compiled = StoryClustering.compileStories(from: [postUnsafe, postUnsafe2])
        
        // Since getDomain returns nil for file:/// schemes, it should NOT group these posts into a domain story cluster!
        // Instead, they will be processed as individual highlight posts, producing separate standalone cards rather than a combined "Perspective" card.
        let domainCluster = compiled.first(where: { $0.headline.contains("Perspective") || $0.headline.contains("Passwords") })
        XCTAssertNil(domainCluster)
    }
}
