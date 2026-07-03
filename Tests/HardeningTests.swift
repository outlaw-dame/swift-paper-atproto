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
}
