import XCTest
@testable import SwiftPaperATProtoCore

final class ValidationTests: XCTestCase {
    
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
    
    // MARK: - Handle Validation
    
    @MainActor
    func testValidHandles() {
        XCTAssertTrue(client.validateHandle("alice.bsky.social"))
        XCTAssertTrue(client.validateHandle("bob.dev"))
        XCTAssertTrue(client.validateHandle("john-doe123.test.co.uk"))
    }
    
    @MainActor
    func testMalformedHandlesBlocked() {
        // Block path traversal / SSRF payloads
        XCTAssertFalse(client.validateHandle("alice.bsky.social/x/y"))
        XCTAssertFalse(client.validateHandle("alice.bsky.social?admin=true"))
        
        // Block SQL/NoSQL injections
        XCTAssertFalse(client.validateHandle("alice.bsky.social;DROP TABLE users;--"))
        XCTAssertFalse(client.validateHandle("alice.bsky.social' OR '1'='1"))
        
        // Block script tag injections
        XCTAssertFalse(client.validateHandle("<script>alert(1)</script>"))
    }
    
    // MARK: - DID Validation
    
    @MainActor
    func testValidDIDs() {
        XCTAssertTrue(client.validateDID("did:plc:z72i7hd4wj4cqa45267llckw"))
        XCTAssertTrue(client.validateDID("did:web:example.com"))
    }
    
    @MainActor
    func testMalformedDIDsBlocked() {
        // SSRF / Path Traversal attempts
        XCTAssertFalse(client.validateDID("did:plc:z72i7hd4wj4cqa45267llckw/../../../etc/passwd"))
        XCTAssertFalse(client.validateDID("did:plc:z72i7hd4wj4cqa45267llckw?query=inject"))
        
        // Injections
        XCTAssertFalse(client.validateDID("did:plc:z72i7hd4wj4cqa45267llckw;SELECT * FROM users"))
    }
    
    // MARK: - ATProtocol Post URI Validation
    
    @MainActor
    func testValidPostURIs() {
        XCTAssertTrue(client.validatePostURI("at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/3k4y4z2z2z2z"))
        XCTAssertTrue(client.validatePostURI("at://did:web:example.com/app.bsky.feed.post/12345"))
    }
    
    @MainActor
    func testMalformedPostURIsBlocked() {
        // Directory Traversal
        XCTAssertFalse(client.validatePostURI("at://did:plc:123/app.bsky.feed.post/../../passwd"))
        
        // SSRF / Query parameters injection
        XCTAssertFalse(client.validatePostURI("at://did:plc:123/app.bsky.feed.post/101?admin=true"))
        
        // Command injection / SQL Injection
        XCTAssertFalse(client.validatePostURI("at://did:plc:123/app.bsky.feed.post/101;rm -rf /"))
    }
}
