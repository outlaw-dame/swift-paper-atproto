import XCTest
import ObjectBox
@testable import SwiftPaperATProtoCore

final class MultiAccountTests: XCTestCase {
    
    private var client: ATProtoClient!
    private var store: LocalStore!
    
    @MainActor
    override func setUp() {
        super.setUp()
        client = ATProtoClient()
        client.useMockData = true
        store = LocalStore(inMemoryName: "test_outbox_db_\(UUID().uuidString)")
    }
    
    @MainActor
    override func tearDown() {
        client.logoutAll()
        client = nil
        store.clearCache()
        store = nil
        super.tearDown()
    }
    
    // MARK: - Multi-Account Keychain Switcher Tests
    
    @MainActor
    func testMultiAccountSwitcherLifecycle() async {
        // 1. Login first account
        await client.login(handle: "alice.bsky.social", appPassword: "password123")
        XCTAssertEqual(client.session?.handle, "alice.bsky.social")
        XCTAssertTrue(client.loggedInAccounts.contains("alice.bsky.social"))
        
        // 2. Login second account
        await client.login(handle: "bob.bsky.social", appPassword: "password456")
        XCTAssertEqual(client.session?.handle, "bob.bsky.social")
        XCTAssertTrue(client.loggedInAccounts.contains("bob.bsky.social"))
        XCTAssertEqual(client.loggedInAccounts.count, 2)
        
        // 3. Switch account back to alice
        client.switchAccount(to: "alice.bsky.social")
        XCTAssertEqual(client.session?.handle, "alice.bsky.social")
        
        // 4. Logout bob and verify active remains alice
        client.logout(handle: "bob.bsky.social")
        XCTAssertEqual(client.session?.handle, "alice.bsky.social")
        XCTAssertFalse(client.loggedInAccounts.contains("bob.bsky.social"))
        XCTAssertEqual(client.loggedInAccounts.count, 1)
        
        // 5. Logout active account alice
        client.logout(handle: "alice.bsky.social")
        XCTAssertNil(client.session)
        XCTAssertFalse(client.isAuthenticated)
        XCTAssertEqual(client.loggedInAccounts.count, 0)
    }
    
    // MARK: - Offline Outbox Database Queue Tests
    
    @MainActor
    func testOfflineOutboxQueueOperations() async {
        XCTAssertEqual(store.pendingOutboxCount, 0)
        
        // 1. Publish mock post when offline (useMockData = true)
        await client.createPost(text: "Hello Offline ATProto World!", using: store)
        
        // Outbox must queue the post record
        XCTAssertEqual(store.pendingOutboxCount, 1)
        
        let pending = store.getAllPendingActions()
        XCTAssertEqual(pending.first?.actionType, "post")
        XCTAssertTrue(pending.first?.payloadJson.contains("Hello Offline") == true)
        
        // 2. Remove completed outbox item
        if let firstAction = pending.first {
            store.removeOutboxAction(id: firstAction.id)
        }
        XCTAssertEqual(store.pendingOutboxCount, 0)
    }
}
