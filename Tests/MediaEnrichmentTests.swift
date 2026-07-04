import XCTest
@testable import SwiftPaperATProtoCore

// MARK: - MediaEnrichmentTests
// These tests use the *real* SecureMediaCache.shared singleton but always call
// clearCache() in tearDown to leave the filesystem clean.  They exercise both
// the happy paths and a comprehensive set of adversarial inputs.

final class MediaEnrichmentTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Evict stale entries so each test begins from a known state.
        SecureMediaCache.shared.clearCache()
    }

    override func tearDown() {
        SecureMediaCache.shared.clearCache()
        super.tearDown()
    }

    // MARK: ─── SHA-256 Key Structure ──────────────────────────────────────────

    func testCacheKeyIs64HexCharsWithExtension() {
        let url = URL(string: "https://cdn.bsky.app/img/avatar/plain/did:plc:abc/cid@jpeg")!
        let key = SecureMediaCache.shared.cacheKey(for: url)

        // SHA-256 produces 32 bytes → 64 hex chars.  Plus ".cache" suffix = 70.
        XCTAssertEqual(key.count, 70, "Key must be 64 hex chars + '.cache' suffix")
        XCTAssertTrue(key.hasSuffix(".cache"))
        // Must be pure hex + extension — no user-controlled characters can appear.
        let hexPart = String(key.dropLast(6))
        XCTAssertTrue(hexPart.allSatisfy { $0.isHexDigit }, "Key prefix must be pure hex")
    }

    func testDifferentURLsProduceDifferentKeys() {
        let url1 = URL(string: "https://cdn.bsky.app/img/avatar.jpg")!
        let url2 = URL(string: "https://cdn.bsky.app/img/banner.jpg")!
        XCTAssertNotEqual(
            SecureMediaCache.shared.cacheKey(for: url1),
            SecureMediaCache.shared.cacheKey(for: url2)
        )
    }

    func testSameURLAlwaysProducesSameKey() {
        let url = URL(string: "https://cdn.bsky.app/img/avatar.jpg")!
        let key1 = SecureMediaCache.shared.cacheKey(for: url)
        let key2 = SecureMediaCache.shared.cacheKey(for: url)
        XCTAssertEqual(key1, key2, "Cache key must be deterministic")
    }

    // MARK: ─── POSIX Directory Permissions ───────────────────────────────────

    func testCacheDirectoryIsOwnerOnly700() {
        XCTAssertTrue(
            SecureMediaCache.shared.verifyCacheDirectoryPermissions(),
            "Cache directory must have POSIX 700 (owner-only) permissions"
        )
    }

    // MARK: ─── Path Containment / Traversal Prevention ───────────────────────

    func testTraversalURLHashedSafely() {
        // Even a traversal-heavy URL must be fully absorbed into a hash — the
        // resulting key must contain no "../" or absolute path components.
        let traversalUrl = URL(string: "https://evil.bsky.app/img/../../../../etc/passwd")!
        let key = SecureMediaCache.shared.cacheKey(for: traversalUrl)
        XCTAssertFalse(key.contains("../"), "Key must not contain traversal sequences")
        XCTAssertFalse(key.contains("/"), "Key must not contain path separators")
        XCTAssertTrue(key.hasSuffix(".cache"))
    }

    func testWriteAndReadRoundTrip() throws {
        let url = URL(string: "https://cdn.bsky.app/img/test-image.jpg")!
        let payload = Data("fake-image-bytes".utf8)

        try SecureMediaCache.shared.cacheMedia(url: url, data: payload)
        let retrieved = try SecureMediaCache.shared.getCachedMedia(url: url)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, payload)
    }

    func testOversizedPayloadRejected() {
        let url = URL(string: "https://cdn.bsky.app/img/huge.jpg")!
        // 6 MB — exceeds the 5 MB cap.
        let bigData = Data(repeating: 0xFF, count: 6 * 1024 * 1024)

        XCTAssertThrowsError(try SecureMediaCache.shared.cacheMedia(url: url, data: bigData)) { error in
            guard let cacheError = error as? SecureMediaCache.CacheError,
                  case .fileTooLarge = cacheError else {
                XCTFail("Expected CacheError.fileTooLarge, got \(error)")
                return
            }
        }
    }

    func testMissingEntryReturnsNil() throws {
        let url = URL(string: "https://cdn.bsky.app/img/not-cached.jpg")!
        let result = try SecureMediaCache.shared.getCachedMedia(url: url)
        XCTAssertNil(result)
    }

    // MARK: ─── ATProtoURLValidator — Media URLs ───────────────────────────────

    func testValidHTTPSMediaURLAccepted() {
        XCTAssertTrue(ATProtoURLValidator.isAllowedMediaURL("https://cdn.bsky.app/img/avatar.jpg"))
    }

    func testHTTPMediaURLRejected() {
        // Media URLs must be HTTPS-only.
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("http://cdn.bsky.app/img/avatar.jpg"))
    }

    func testFileSchemeMediaURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("file:///etc/passwd"))
    }

    func testDataSchemeMediaURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("data:image/png;base64,abc123"))
    }

    func testJavascriptSchemeMediaURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("javascript:alert(1)"))
    }

    func testBlobSchemeMediaURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("blob:https://evil.com/uuid"))
    }

    func testLocalhostMediaURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("https://localhost/img/avatar.jpg"))
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("https://127.0.0.1/img/avatar.jpg"))
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("https://::1/img/avatar.jpg"))
    }

    func testCaseSpoofedSchemeRejected() {
        // Scheme comparison must be case-insensitive; "HTTPS" must still pass,
        // but "File" or "JAVASCRIPT" must be normalised and rejected.
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("FILE:///etc/passwd"))
        XCTAssertFalse(ATProtoURLValidator.isAllowedMediaURL("JAVASCRIPT:alert(1)"))
    }

    // MARK: ─── ATProtoURLValidator — External URLs ────────────────────────────

    func testValidHTTPSExternalURLAccepted() {
        XCTAssertTrue(ATProtoURLValidator.isAllowedExternalURL("https://example.com/article"))
    }

    func testValidHTTPExternalURLAccepted() {
        XCTAssertTrue(ATProtoURLValidator.isAllowedExternalURL("http://example.com/article"))
    }

    func testJavascriptExternalURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedExternalURL("javascript:void(0)"))
    }

    func testFileExternalURLRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedExternalURL("file:///etc/hosts"))
    }

    // MARK: ─── ATProtoURLValidator — AT URIs ─────────────────────────────────

    func testValidFeedPostATUriAccepted() {
        let uri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/3k4y4z2z"
        XCTAssertTrue(ATProtoURLValidator.isValidATUri(uri))
    }

    func testValidFeedGeneratorATUriAccepted() {
        let uri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.generator/tech"
        XCTAssertTrue(ATProtoURLValidator.isValidATUri(uri))
    }

    func testTraversalATUriRejected() {
        let uri = "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/../../etc/passwd"
        XCTAssertFalse(ATProtoURLValidator.isValidATUri(uri))
    }

    func testUnknownCollectionATUriRejected() {
        // An attacker spoofing a non-approved collection should be blocked.
        let uri = "at://did:plc:z72i7hd4wj4cqa45267llckw/com.evil.exfiltrate.data/item123"
        XCTAssertFalse(ATProtoURLValidator.isValidATUri(uri))
    }

    func testRawHTTPSATUriRejected() {
        // Must use at:// scheme, not https://.
        let uri = "https://bsky.social/app.bsky.feed.post/abc"
        XCTAssertFalse(ATProtoURLValidator.isValidATUri(uri))
    }

    // MARK: ─── EmbedVideo Decoding Hardening ──────────────────────────────────

    func testEmbedVideoDecodesValidPlaylist() throws {
        let json = """
        {"playlist":"https://cdn.bsky.app/video.m3u8","thumbnail":null}
        """.data(using: .utf8)!
        let video = try JSONDecoder().decode(EmbedVideo.self, from: json)
        XCTAssertEqual(video.playlist, "https://cdn.bsky.app/video.m3u8")
    }

    func testEmbedVideoRejectsFileSchemePlaylist() {
        let json = """
        {"playlist":"file:///etc/passwd","thumbnail":null}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(EmbedVideo.self, from: json))
    }

    func testEmbedVideoRejectsJavascriptPlaylist() {
        let json = """
        {"playlist":"javascript:alert(1)","thumbnail":null}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(EmbedVideo.self, from: json))
    }

    // MARK: ─── EmbedImage Decoding Hardening ─────────────────────────────────

    func testEmbedImageDecodesValidURLs() throws {
        let json = """
        {"thumb":"https://cdn.bsky.app/img/t.jpg","fullsize":"https://cdn.bsky.app/img/f.jpg","alt":"photo"}
        """.data(using: .utf8)!
        let image = try JSONDecoder().decode(EmbedImage.self, from: json)
        XCTAssertEqual(image.thumb, "https://cdn.bsky.app/img/t.jpg")
    }

    func testEmbedImageRejectsHTTPThumb() {
        // Images must use HTTPS; HTTP is rejected at model layer.
        let json = """
        {"thumb":"http://cdn.bsky.app/img/t.jpg","fullsize":"https://cdn.bsky.app/img/f.jpg","alt":null}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(EmbedImage.self, from: json))
    }

    // MARK: ─── EmbedExternal Decoding Hardening ───────────────────────────────

    func testEmbedExternalDecodesValidURI() throws {
        let json = """
        {"uri":"https://example.com","title":"Example","description":"A test","thumb":null}
        """.data(using: .utf8)!
        let ext = try JSONDecoder().decode(EmbedExternal.self, from: json)
        XCTAssertEqual(ext.uri, "https://example.com")
    }

    func testEmbedExternalRejectsJavascriptURI() {
        let json = """
        {"uri":"javascript:alert(document.cookie)","title":"XSS","description":"Attack","thumb":null}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(EmbedExternal.self, from: json))
    }

    func testEmbedExternalTruncatesLongTitle() throws {
        let longTitle = String(repeating: "A", count: 500)
        let json = """
        {"uri":"https://example.com","title":"\(longTitle)","description":"ok","thumb":null}
        """.data(using: .utf8)!
        let ext = try JSONDecoder().decode(EmbedExternal.self, from: json)
        XCTAssertEqual(ext.title.count, 200, "Title must be truncated to 200 characters")
    }
}
