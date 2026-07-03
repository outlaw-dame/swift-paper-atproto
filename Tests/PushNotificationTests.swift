import XCTest
@testable import SwiftPaperATProtoCore

final class PushNotificationTests: XCTestCase {
    
    private var manager: PushNotificationManager!
    
    @MainActor
    override func setUp() {
        super.setUp()
        manager = PushNotificationManager()
    }
    
    @MainActor
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Payload Parsing Tests
    
    @MainActor
    func testValidNotificationPayloadParsing() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "New Reply",
                    "body": "Alice replied to your post."
                ]
            ],
            "postUri": "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/3k4y4z2z"
        ]
        
        let payload = manager.parseNotificationPayload(from: userInfo)
        
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.title, "New Reply")
        XCTAssertEqual(payload?.body, "Alice replied to your post.")
        XCTAssertEqual(payload?.postUri, "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/3k4y4z2z")
    }
    
    @MainActor
    func testMalformedNotificationPayloadSkipped() {
        // Missing "aps" key
        let userInfo: [AnyHashable: Any] = [
            "postUri": "at://did:plc:z72i7hd4wj4cqa45267llckw/app.bsky.feed.post/3k4y4z"
        ]
        
        let payload = manager.parseNotificationPayload(from: userInfo)
        XCTAssertNil(payload)
    }
    
    // MARK: - Input Truncation Hardening Tests
    
    @MainActor
    func testNotificationPayloadTruncation() {
        let longTitle = String(repeating: "T", count: 150)
        let longBody = String(repeating: "B", count: 300)
        
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": longTitle,
                    "body": longBody
                ]
            ]
        ]
        
        let payload = manager.parseNotificationPayload(from: userInfo)
        
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.title.count, 100) // Truncated to 100
        XCTAssertEqual(payload?.body.count, 250)  // Truncated to 250
    }
    
    // MARK: - Post URI Validation in Payload
    
    @MainActor
    func testNotificationPayloadUnsafeUriFiltered() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Alert",
                    "body": "Text info"
                ]
            ],
            // Traversal payload injected in metadata URI fields
            "postUri": "at://did:plc:123/app.bsky.feed.post/../../passwd"
        ]
        
        let payload = manager.parseNotificationPayload(from: userInfo)
        
        XCTAssertNotNil(payload)
        // The URI must be rejected and set to nil to prevent traversal/injection routing
        XCTAssertNil(payload?.postUri)
    }
}
