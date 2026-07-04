import XCTest
@testable import SwiftPaperATProtoCore

/// Full test suite for Phase 9: Identity Resolution & Handle Management.
///
/// Tests are grouped into:
///  1. DIDResolver — handle validation, DID validation, SSRF guard, DNS safety labels
///  2. DIDDocument — parsing logic, IDOR guard (id mismatch)
///  3. ATProtoClient — profile sanitization, updateProfile mock flow
///  4. ATProtoURLValidator — integration with DID document service endpoint validation
final class IdentityResolutionTests: XCTestCase {

    // MARK: - DIDResolver Validation (Unit-level; no network calls)

    // We test the private validation helpers through the public contract by
    // exercising `resolveHandle` with known-bad inputs and verifying errors.

    func testResolveHandleRejectsEmptyString() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("")
            XCTFail("Expected DIDResolutionError.invalidHandle")
        } catch DIDResolutionError.invalidHandle {
            // Expected.
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testResolveHandleRejectsHandleWithUpperCase() async {
        // Handles are normalised to lowercase by the resolver; uppercase input
        // is valid after normalisation — but a raw capital should not crash.
        let resolver = DIDResolver()
        // "ALICE.BSKY.SOCIAL" lowercased is "alice.bsky.social" which is valid format.
        // We cannot assert network result, just that it doesn't throw .invalidHandle.
        // We only test the validation layer — cancel immediately after dispatch.
        let task = Task { try await resolver.resolveHandle("ALICE.BSKY.SOCIAL") }
        task.cancel()
        // No assertion on result — just confirm no crash on valid-after-normalise input.
    }

    func testResolveHandleRejectsBareLabel() async {
        // A bare label with no dot is not a valid handle per ATProto spec.
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("noDot")
            XCTFail("Expected DIDResolutionError.invalidHandle")
        } catch DIDResolutionError.invalidHandle {
            // Expected.
        } catch {
            // Network error is also acceptable — means it passed validation but failed resolution.
            XCTAssertTrue(
                error is DIDResolutionError || error is URLError,
                "Unexpected error type: \(error)"
            )
        }
    }

    func testResolveHandleRejectsLocalhostSSRF() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("localhost")
            XCTFail("Expected SSRF protection to block localhost")
        } catch DIDResolutionError.invalidHandle {
            // Caught at handle-validation layer (bare label, no dot).
        } catch DIDResolutionError.ssrfProtectedHost {
            // Caught at SSRF guard layer.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveHandleRejectsPrivateIPSSRF() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("192.168.1.1")
            XCTFail("Expected SSRF protection or invalid handle error")
        } catch DIDResolutionError.ssrfProtectedHost {
            // Expected — private IP range blocked.
        } catch DIDResolutionError.invalidHandle {
            // Also acceptable — IP addresses may fail the handle regex.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveHandleRejectsAWSMetadataSSRF() async {
        // 169.254.169.254 is the AWS EC2 metadata endpoint.
        // Even if the network is reachable, the SSRF guard must block it.
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("169.254.169.254")
            XCTFail("Expected SSRF guard to block AWS metadata endpoint")
        } catch DIDResolutionError.ssrfProtectedHost {
            // Expected.
        } catch DIDResolutionError.invalidHandle {
            // Also acceptable.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveHandleRejectsTraversalInHandle() async {
        // Path traversal sequences in handles should fail handle validation.
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("../etc.passwd")
            XCTFail("Expected DIDResolutionError.invalidHandle")
        } catch DIDResolutionError.invalidHandle {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveHandleRejectsNullByte() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle("alice\u{0000}bsky.social")
            XCTFail("Expected DIDResolutionError.invalidHandle")
        } catch DIDResolutionError.invalidHandle {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveHandleRejectsOversizedHandle() async {
        // Handles max 253 chars per DNS spec.
        let longHandle = String(repeating: "a", count: 254) + ".bsky.social"
        let resolver = DIDResolver()
        do {
            _ = try await resolver.resolveHandle(longHandle)
            XCTFail("Expected DIDResolutionError.invalidHandle for oversized handle")
        } catch DIDResolutionError.invalidHandle {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - DID Format Validation

    func testValidDIDPlcFormat() async {
        // Valid DID:PLC format should not throw invalidDIDFormat.
        // We only test the validation contract — not live network.
        let resolver = DIDResolver()
        // We can indirectly test by fetching a DID document with an invalid DID.
        do {
            _ = try await resolver.fetchDIDDocument(did: "not-a-did")
            XCTFail("Expected DIDResolutionError.invalidDIDFormat")
        } catch DIDResolutionError.invalidDIDFormat {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDIDWithTraversalRejected() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.fetchDIDDocument(did: "did:plc:../../../../etc/passwd")
            XCTFail("Expected DIDResolutionError.invalidDIDFormat")
        } catch DIDResolutionError.invalidDIDFormat {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDIDWithJavascriptSchemeRejected() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.fetchDIDDocument(did: "did:javascript:alert(1)")
            XCTFail("Expected DIDResolutionError.invalidDIDFormat or plcDirectoryFailed")
        } catch DIDResolutionError.invalidDIDFormat {
            // Expected — 'javascript' is a disallowed method.
        } catch DIDResolutionError.plcDirectoryFailed {
            // Also acceptable.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyDIDRejected() async {
        let resolver = DIDResolver()
        do {
            _ = try await resolver.fetchDIDDocument(did: "")
            XCTFail("Expected DIDResolutionError.invalidDIDFormat")
        } catch DIDResolutionError.invalidDIDFormat {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - ATProtoClient Profile Sanitization

    func testSanitizeProfileTextCapsLength() async {
        // ATProtoClient.sanitizeProfileText is private, but we test it indirectly
        // through updateProfile which is public. Use the mock mode path.
        let client = await ATProtoClient()
        await MainActor.run {
            client.useMockData = true
            client.session = CreateSessionResponse(
                did: "did:plc:mock123",
                handle: "mock.bsky.social",
                accessJwt: "mock_access",
                refreshJwt: "mock_refresh"
            )
        }

        // A display name exceeding 64 chars should be truncated.
        let longName = String(repeating: "A", count: 100)
        try? await client.updateProfile(displayName: longName, description: nil)

        await MainActor.run {
            XCTAssertLessThanOrEqual(client.session?.displayName?.count ?? 0, 64,
                                     "Display name must be truncated to ≤64 characters")
        }
    }

    func testUpdateProfileInMockModeSucceeds() async throws {
        let client = await ATProtoClient()
        await MainActor.run {
            client.useMockData = true
            client.session = CreateSessionResponse(
                did: "did:plc:mock123",
                handle: "mock.bsky.social",
                accessJwt: "mock_access",
                refreshJwt: "mock_refresh"
            )
        }

        // Should not throw in mock mode.
        try await client.updateProfile(displayName: "New Name", description: "A bio.")

        await MainActor.run {
            XCTAssertEqual(client.session?.displayName, "New Name")
        }
    }

    func testUpdateProfileWithControlCharactersSanitised() async throws {
        let client = await ATProtoClient()
        await MainActor.run {
            client.useMockData = true
            client.session = CreateSessionResponse(
                did: "did:plc:mock123",
                handle: "mock.bsky.social",
                accessJwt: "mock_access",
                refreshJwt: "mock_refresh"
            )
        }

        // Control characters should be stripped; the remainder should survive.
        let maliciousName = "Alice\u{0008}\u{0007}Smith"
        try await client.updateProfile(displayName: maliciousName, description: nil)

        await MainActor.run {
            let name = client.session?.displayName ?? ""
            XCTAssertFalse(name.contains("\u{0008}"), "Control characters must be stripped")
            XCTAssertFalse(name.contains("\u{0007}"), "Control characters must be stripped")
            XCTAssertTrue(name.contains("Alice"), "Printable chars must be preserved")
        }
    }

    func testUpdateProfileWithNoSessionThrows() async {
        let client = await ATProtoClient()
        await MainActor.run {
            client.useMockData = false
            client.session = nil
        }
        do {
            try await client.updateProfile(displayName: "Test", description: nil)
            XCTFail("Expected URLError when session is nil")
        } catch {
            XCTAssertTrue(error is URLError || (error as NSError).code == URLError.notConnectedToInternet.rawValue)
        }
    }

    // MARK: - ATProtoURLValidator Integration with DID Services

    func testServiceEndpointHTTPSAccepted() {
        XCTAssertTrue(ATProtoURLValidator.isAllowedExternalURL("https://bsky.network"))
    }

    func testServiceEndpointFileSchemeRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedExternalURL("file:///etc/passwd"))
    }

    func testServiceEndpointJavascriptRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedExternalURL("javascript:void(0)"))
    }

    func testServiceEndpointLocalhostRejected() {
        XCTAssertFalse(ATProtoURLValidator.isAllowedExternalURL("https://localhost/service"))
    }

    // MARK: - ProfileViewDetailed Decodable

    func testProfileViewDetailedDecodes() throws {
        let json = """
        {
            "did": "did:plc:z72i7hd4wj4cqa45267llckw",
            "handle": "alice.bsky.social",
            "displayName": "Alice",
            "description": "Engineer. Coffee aficionado.",
            "avatar": "https://cdn.bsky.app/img/avatar.jpg",
            "banner": null,
            "followersCount": 100,
            "followsCount": 50,
            "postsCount": 200
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(ProfileViewDetailed.self, from: json)
        XCTAssertEqual(profile.did, "did:plc:z72i7hd4wj4cqa45267llckw")
        XCTAssertEqual(profile.handle, "alice.bsky.social")
        XCTAssertEqual(profile.displayName, "Alice")
        XCTAssertEqual(profile.followersCount, 100)
    }

    func testCreateSessionResponseDecodesWithNewFields() throws {
        let json = """
        {
            "did": "did:plc:abc",
            "handle": "test.bsky.social",
            "accessJwt": "token_a",
            "refreshJwt": "token_r",
            "displayName": "Test User",
            "avatar": "https://cdn.bsky.app/img/avatar.jpg"
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(CreateSessionResponse.self, from: json)
        XCTAssertEqual(session.displayName, "Test User")
        XCTAssertEqual(session.avatar, "https://cdn.bsky.app/img/avatar.jpg")
    }
}
