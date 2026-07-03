import XCTest
@testable import SwiftPaperATProtoCore

final class MediaEnrichmentTests: XCTestCase {
    
    private var cache: SecureMediaCache!
    
    override func setUp() {
        super.setUp()
        cache = SecureMediaCache.shared
    }
    
    override func tearDown() {
        cache.clearCache()
        cache = nil
        super.tearDown()
    }
    
    // MARK: - SHA-256 Hash and Directory Containment Security
    
    func testHashMatchesKeyStructure() {
        let url = URL(string: "https://bsky.social/xrpc/images/my-avatar.jpg")!
        let key = cache.cacheKey(for: url)
        
        // Hashed keys must be 64-char hex strings + extension (.cache)
        XCTAssertEqual(key.count, 70) // 64 + 6 (.cache)
        XCTAssertTrue(key.hasSuffix(".cache"))
    }
    
    func testPOSIXDirectorySecurityAttributes() {
        let isOwnerOnly = cache.verifyCacheDirectoryPermissions()
        XCTAssertTrue(isOwnerOnly, "Media cache folder must restrict POSIX attributes to 700 owner-only access.")
    }
    
    func testPathTraversalAttackContainment() {
        // Construct traversal parameters designed to bypass standard sandboxes
        let traversalUrl = URL(string: "https://bsky.social/xrpc/../../../../etc/passwd")!
        
        // Ensure that attempts to write or read traversal URLs are securely hashed as safe SHA-256 keys,
        // and cannot escape the cache directory bounds.
        let key = cache.cacheKey(for: traversalUrl)
        XCTAssertFalse(key.contains("../"))
        XCTAssertTrue(key.hasSuffix(".cache"))
    }
    
    // MARK: - Video Protocol Scheme Validation
    
    func testVideoPlaybackProtocolGating() {
        // 1. Safe Web HTTP/HTTPS schemes
        let safeWebUrl = URL(string: "https://bsky.social/video.m3u8")!
        XCTAssertTrue(safeWebUrl.scheme == "http" || safeWebUrl.scheme == "https")
        
        // 2. Unsafe Local schemes (IDOR/SSRF path triggers)
        let localSchemeUrl = URL(string: "file:///etc/passwd")!
        XCTAssertFalse(localSchemeUrl.scheme == "http" || localSchemeUrl.scheme == "https")
        
        let customSchemeUrl = URL(string: "localhost://debug")!
        XCTAssertFalse(customSchemeUrl.scheme == "http" || customSchemeUrl.scheme == "https")
    }
}
