import Foundation
import Combine

public struct AccountSession: Codable, Hashable {
    public let handle: String
    public let did: String
}

@MainActor
public final class ATProtoClient: ObservableObject {
    @Published public var session: CreateSessionResponse? = nil
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var useMockData = true
    
    // Multi-Account switcher lists
    @Published public var loggedInAccounts: [String] = []
    
    private let baseURL = URL(string: "https://bsky.social/xrpc")!
    
    // Global keys
    private let accountsIndexKey = "atproto_accounts_index"
    private let activeHandleKey = "atproto_active_handle"
    
    private var isRefreshingSession = false
    private var isFlushingOutbox = false
    
    public init() {
        restoreSessionFromKeychain()
    }
    
    // MARK: - Input Validation & Sanitization
    
    public func validateHandle(_ handle: String) -> Bool {
        let pattern = "^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,10}$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: handle.utf16.count)
        return regex.firstMatch(in: handle, options: [], range: range) != nil
    }
    
    public func validateDID(_ did: String) -> Bool {
        let pattern = "^did:[a-z0-9]+:[a-zA-Z0-9._%:-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: did.utf16.count)
        return regex.firstMatch(in: did, options: [], range: range) != nil
    }
    
    public func validatePostURI(_ uri: String) -> Bool {
        let pattern = "^at://did:[a-z0-9]+:[a-zA-Z0-9._%:-]+/app\\.bsky\\.feed\\.post/[a-zA-Z0-9_-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: uri.utf16.count)
        return regex.firstMatch(in: uri, options: [], range: range) != nil
    }
    
    public func validateFeedGeneratorURI(_ uri: String) -> Bool {
        let pattern = "^at://did:[a-z0-9]+:[a-zA-Z0-9._%:-]+/app\\.bsky\\.feed\\.generator/[a-zA-Z0-9_-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: uri.utf16.count)
        return regex.firstMatch(in: uri, options: [], range: range) != nil
    }
    
    public func validateCursor(_ cursor: String) -> Bool {
        let pattern = "^[a-zA-Z0-9+=/._%:-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: cursor.utf16.count)
        return regex.firstMatch(in: cursor, options: [], range: range) != nil
    }
    
    // MARK: - Multi-Account Keychain Persistence
    
    private func restoreSessionFromKeychain() {
        // Load active accounts index
        if let indexString = KeychainHelper.get(key: accountsIndexKey) {
            let accounts = indexString.components(separatedBy: ",").filter { !$0.isEmpty }
            self.loggedInAccounts = accounts.filter { handle in
                (validateHandle(handle) || handle.starts(with: "mock") || handle.contains(".mock")) && !handle.contains(",")
            }
        }
        
        guard let activeHandle = KeychainHelper.get(key: activeHandleKey),
              let access = KeychainHelper.get(key: "atproto_\(activeHandle)_access_jwt"),
              let refresh = KeychainHelper.get(key: "atproto_\(activeHandle)_refresh_jwt"),
              let did = KeychainHelper.get(key: "atproto_\(activeHandle)_did") else {
            return
        }
        
        // Active handle must be in the sanitized index
        guard loggedInAccounts.contains(activeHandle) else { return }
        
        self.session = CreateSessionResponse(
            did: did,
            handle: activeHandle,
            email: nil,
            accessJwt: access,
            refreshJwt: refresh
        )
        self.isAuthenticated = true
        self.useMockData = false
    }
    
    private func persistSessionToKeychain(_ session: CreateSessionResponse) {
        let handle = session.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sanitize check
        guard (validateHandle(handle) || handle.starts(with: "mock") || handle.contains(".mock")) && !handle.contains(",") else { return }
        
        // Save account-specific credentials
        KeychainHelper.save(key: "atproto_\(handle)_access_jwt", value: session.accessJwt)
        KeychainHelper.save(key: "atproto_\(handle)_refresh_jwt", value: session.refreshJwt)
        KeychainHelper.save(key: "atproto_\(handle)_did", value: session.did)
        
        // Save active account reference
        KeychainHelper.save(key: activeHandleKey, value: handle)
        
        // Update index list
        if !loggedInAccounts.contains(handle) {
            loggedInAccounts.append(handle)
            let indexString = loggedInAccounts.joined(separator: ",")
            KeychainHelper.save(key: accountsIndexKey, value: indexString)
        }
    }
    
    public func switchAccount(to handle: String) {
        guard loggedInAccounts.contains(handle) else { return }
        
        guard let access = KeychainHelper.get(key: "atproto_\(handle)_access_jwt"),
              let refresh = KeychainHelper.get(key: "atproto_\(handle)_refresh_jwt"),
              let did = KeychainHelper.get(key: "atproto_\(handle)_did") else {
            return
        }
        
        self.session = CreateSessionResponse(
            did: did,
            handle: handle,
            email: nil,
            accessJwt: access,
            refreshJwt: refresh
        )
        self.isAuthenticated = true
        KeychainHelper.save(key: activeHandleKey, value: handle)
        self.useMockData = false
    }
    
    private func clearAccountFromKeychain(handle: String) {
        // Delete credentials
        KeychainHelper.delete(key: "atproto_\(handle)_access_jwt")
        KeychainHelper.delete(key: "atproto_\(handle)_refresh_jwt")
        KeychainHelper.delete(key: "atproto_\(handle)_did")
        
        // Remove from index
        if let idx = loggedInAccounts.firstIndex(of: handle) {
            loggedInAccounts.remove(at: idx)
            let indexString = loggedInAccounts.joined(separator: ",")
            KeychainHelper.save(key: accountsIndexKey, value: indexString)
        }
        
        // Clear active pointer if deleted active account
        if KeychainHelper.get(key: activeHandleKey) == handle {
            KeychainHelper.delete(key: activeHandleKey)
            
            // Switch to remaining logged in account if available
            if let firstRemaining = loggedInAccounts.first {
                switchAccount(to: firstRemaining)
            } else {
                self.session = nil
                self.isAuthenticated = false
            }
        }
    }
    
    private func refreshSession() async throws {
        guard let session = session else { return }
        
        let refreshURL = baseURL.appendingPathComponent("com.atproto.server.refreshSession")
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.refreshJwt)", forHTTPHeaderField: "Authorization")
        
        let response: CreateSessionResponse = try await executeRequestWithBackoff(request)
        self.session = response
        persistSessionToKeychain(response)
    }
    
    // MARK: - Exponential Backoff Request Executor
    
    private func executeRequestWithBackoff<T: Decodable>(
        _ request: URLRequest,
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0
    ) async throws -> T {
        var attempt = 0
        
        while true {
            attempt += 1
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                }
                
                if httpResponse.statusCode == 401 {
                    if !isRefreshingSession {
                        isRefreshingSession = true
                        defer { isRefreshingSession = false }
                        do {
                            try await refreshSession()
                            var newRequest = request
                            if let access = self.session?.accessJwt {
                                newRequest.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
                            }
                            return try await executeRequestWithBackoff(newRequest)
                        } catch {
                            if let handle = self.session?.handle {
                                logout(handle: handle)
                            }
                            throw NSError(domain: "ATProtoError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Your session has expired. Please sign in again."])
                        }
                    } else {
                        if let handle = self.session?.handle {
                            logout(handle: handle)
                        }
                        throw NSError(domain: "ATProtoError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication token invalid or revoked."])
                    }
                }
                
                let isTransientStatus = httpResponse.statusCode == 429 || httpResponse.statusCode == 503 || httpResponse.statusCode == 504
                
                if isTransientStatus && attempt < maxRetries {
                    let delay = calculateDelay(attempt: attempt, initialDelay: initialDelay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    let sanitizedMessage = message.components(separatedBy: "stack:").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Network request failed."
                    throw NSError(domain: "ATProtoError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: sanitizedMessage])
                } else {
                    throw NSError(domain: "ATProtoError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Authentication server error (code \(httpResponse.statusCode))."])
                }
                
            } catch {
                let nsError = error as NSError
                let isTransientNetwork = nsError.domain == NSURLErrorDomain && 
                    (nsError.code == URLError.timedOut.rawValue ||
                     nsError.code == URLError.cannotConnectToHost.rawValue ||
                     nsError.code == URLError.cannotFindHost.rawValue ||
                     nsError.code == URLError.networkConnectionLost.rawValue)
                
                if isTransientNetwork && attempt < maxRetries {
                    let delay = calculateDelay(attempt: attempt, initialDelay: initialDelay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
            }
        }
    }
    
    private func calculateDelay(attempt: Int, initialDelay: TimeInterval) -> TimeInterval {
        let baseDelay = initialDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: -0.15...0.15) * baseDelay
        return baseDelay + jitter
    }
    
    // MARK: - Actions: Login
    
    public func login(handle: String, appPassword: String) async {
        isLoading = true
        errorMessage = nil
        
        let sanitizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !useMockData && !validateHandle(sanitizedHandle) {
            self.errorMessage = "Invalid handle format. Please use standard domain layout."
            self.isLoading = false
            return
        }
        
        if useMockData || sanitizedHandle.lowercased() == "mock" || sanitizedHandle.lowercased().starts(with: "mock") {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let mockSession = CreateSessionResponse(
                did: "did:plc:mock_\(sanitizedHandle.isEmpty ? "user" : sanitizedHandle)",
                handle: sanitizedHandle.isEmpty ? "mockuser.bsky.social" : sanitizedHandle,
                email: "mock@example.com",
                accessJwt: "mock_jwt_access_token",
                refreshJwt: "mock_jwt_refresh_token"
            )
            self.session = mockSession
            self.isAuthenticated = true
            persistSessionToKeychain(mockSession)
            self.isLoading = false
            return
        }
        
        do {
            let loginURL = baseURL.appendingPathComponent("com.atproto.server.createSession")
            var request = URLRequest(url: loginURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = [
                "identifier": sanitizedHandle,
                "password": appPassword
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let sessionResp: CreateSessionResponse = try await executeRequestWithBackoff(request)
            self.session = sessionResp
            self.isAuthenticated = true
            persistSessionToKeychain(sessionResp)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Actions: Logout
    
    public func logout(handle: String) {
        clearAccountFromKeychain(handle: handle)
        self.errorMessage = nil
    }
    
    public func logoutAll() {
        let accounts = loggedInAccounts
        for acc in accounts {
            clearAccountFromKeychain(handle: acc)
        }
        KeychainHelper.delete(key: accountsIndexKey)
        KeychainHelper.delete(key: activeHandleKey)
        self.loggedInAccounts = []
        self.session = nil
        self.isAuthenticated = false
        self.errorMessage = nil
    }
    
    // MARK: - Actions: Fetch Timeline
    
    public func fetchTimeline(cursor: String? = nil) async throws -> GetTimelineResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            return generateMockTimeline()
        }
        
        guard let session = session else {
            throw URLError(.notConnectedToInternet)
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("app.bsky.feed.getTimeline"), resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem(name: "algorithm", value: "reverse-chronological")]
        if let cursor = cursor {
            let sanitizedCursor = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard validateCursor(sanitizedCursor) else {
                throw NSError(domain: "ATProtoError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid page reference token format."])
            }
            queryItems.append(URLQueryItem(name: "cursor", value: sanitizedCursor))
        }
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        
        return try await executeRequestWithBackoff(request)
    }
    
    public func fetchCustomTimeline(feedUri: String, cursor: String? = nil) async throws -> GetTimelineResponse {
        let sanitizedUri = feedUri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateFeedGeneratorURI(sanitizedUri) || useMockData else {
            throw NSError(domain: "ATProtoError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insecure or malformed custom feed generator URI target."])
        }
        
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            return generateMockTimeline()
        }
        
        guard let session = session else {
            throw URLError(.notConnectedToInternet)
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("app.bsky.feed.getFeed"), resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem(name: "feed", value: sanitizedUri)]
        if let cursor = cursor {
            let sanitizedCursor = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard validateCursor(sanitizedCursor) else {
                throw NSError(domain: "ATProtoError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid page reference token format."])
            }
            queryItems.append(URLQueryItem(name: "cursor", value: sanitizedCursor))
        }
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        
        return try await executeRequestWithBackoff(request)
    }
    
    // MARK: - Actions: Fetch Thread
    
    public func fetchThread(postUri: String) async throws -> GetPostThreadResponse {
        guard validatePostURI(postUri) || useMockData else {
            throw NSError(domain: "ATProtoError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Malformed ATProtocol post URI reference."])
        }
        
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return generateMockThread(for: postUri)
        }
        
        guard let session = session else {
            throw URLError(.notConnectedToInternet)
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("app.bsky.feed.getPostThread"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "uri", value: postUri)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        
        return try await executeRequestWithBackoff(request)
    }
    
    // MARK: - Offline Outbox Publishing & Background Sync Work
    
    public func createPost(text: String, using store: LocalStore) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { return }
        
        let payload: [String: String] = [
            "text": trimmed,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        // If offline (mock offline mode) or network unavailable, queue action in database
        if useMockData {
            store.queueOutboxAction(type: "post", payloadJson: jsonString)
            print("Offline Outbox: queued post locally in database.")
            return
        }
        
        // Online: attempt HTTP publish directly
        do {
            try await publishPostRecord(text: trimmed)
        } catch {
            // Self-healing fallback: if HTTP post fails due to network outage, queue it offline
            store.queueOutboxAction(type: "post", payloadJson: jsonString)
            print("Network failure. Offline fallback: queued post locally in database.")
        }
    }
    
    private func publishPostRecord(text: String) async throws {
        guard let session = session else { throw URLError(.notConnectedToInternet) }
        
        let postURL = baseURL.appendingPathComponent("com.atproto.repo.createRecord")
        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": [
                "$type": "app.bsky.feed.post",
                "text": text,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Fire request with exponential backoff retry parameters
        let _: EmptyDecodableResponse = try await executeRequestWithBackoff(request)
    }
    
    public func flushOutbox(using store: LocalStore) async {
        guard !useMockData, isAuthenticated else { return }
        guard !isFlushingOutbox else { return }
        isFlushingOutbox = true
        defer { isFlushingOutbox = false }
        
        let pending = store.getAllPendingActions()
        guard !pending.isEmpty else { return }
        
        print("Outbox Sync: resolving \(pending.count) queued actions...")
        
        for action in pending {
            guard let data = action.payloadJson.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = payload["text"] as? String else {
                // Self-healing: purge corrupt JSON payloads instantly to prevent sync blocks
                store.removeOutboxAction(id: action.id)
                continue
            }
            
            do {
                try await publishPostRecord(text: text)
                store.removeOutboxAction(id: action.id)
                print("Outbox Sync: successfully published action ID \(action.id)")
            } catch {
                // If failed due to network connection loss, pause sync (try again later)
                let nsError = error as NSError
                let isConnectionLoss = nsError.domain == NSURLErrorDomain && 
                    (nsError.code == URLError.notConnectedToInternet.rawValue ||
                     nsError.code == URLError.networkConnectionLost.rawValue)
                if isConnectionLoss {
                    print("Outbox Sync: sync paused due to network disconnect.")
                    break
                }
                
                // If failed due to permanent data errors (e.g. text violates character limits), purge it
                store.removeOutboxAction(id: action.id)
                print("Outbox Sync: purged invalid post action ID \(action.id) - Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Empty Decodable Helper
    private struct EmptyDecodableResponse: Decodable {}
    
    // MARK: - Mock Generator Helpers
    private func generateMockTimeline() -> GetTimelineResponse {
        let authors = [
            ProfileViewBasic(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Smith", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150"),
            ProfileViewBasic(did: "did:plc:2", handle: "bob_dev.bsky.social", displayName: "Bob Robertson", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"),
            ProfileViewBasic(did: "did:plc:3", handle: "tech_insider.bsky.social", displayName: "Tech Insider", avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150"),
            ProfileViewBasic(did: "did:plc:4", handle: "nature_pics.bsky.social", displayName: "Nature Daily", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150")
        ]
        
        let posts = [
            Post(
                uri: "at://did:plc:1/app.bsky.feed.post/101",
                cid: "cid101",
                author: authors[0],
                record: PostRecord(text: "Just built a local-first Swift client for the AT Protocol! The card-based swipe gestures in SwiftUI feel incredibly responsive, matching Apple's HIG principles perfectly. 🚀📱 #swift #atproto", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600))),
                embed: Embed(type: "app.bsky.embed.images", images: [EmbedImage(thumb: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600", fullsize: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1200", alt: "Abstract digital art displaying vibrant colors.")]),
                replyCount: 5, repostCount: 12, likeCount: 42,
                indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600))
            ),
            Post(
                uri: "at://did:plc:2/app.bsky.feed.post/102",
                cid: "cid102",
                author: authors[1],
                record: PostRecord(text: "Is anyone else exploring the decentralized web? Bluesky and the AT Protocol are showing some very cool possibilities for custom developer feeds and data ownership.", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))),
                replyCount: 2, repostCount: 4, likeCount: 18,
                indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))
            ),
            Post(
                uri: "at://did:plc:3/app.bsky.feed.post/103",
                cid: "cid103",
                author: authors[2],
                record: PostRecord(text: "Apple announces major updates to SwiftUI navigation and gestures at WWDC! Check out the details of interactive transition anchors and custom scroll target behaviors. 💡🍏 #iosdev #wwdc", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))),
                embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "https://developer.apple.com", title: "Apple Developer News", description: "Read about the latest updates to Swift and SwiftUI frameworks directly from Apple's design and engineering teams.", thumb: "https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=600")),
                replyCount: 8, repostCount: 19, likeCount: 78,
                indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
            ),
            Post(
                uri: "at://did:plc:4/app.bsky.feed.post/104",
                cid: "cid104",
                author: authors[3],
                record: PostRecord(text: "Beautiful sunset view in Yosemite Valley today. Connecting back with nature offline is the best reset. 🌄🌲✨", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))),
                embed: Embed(type: "app.bsky.embed.images", images: [EmbedImage(thumb: "https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=600", fullsize: "https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=1200", alt: "Sunset casting gold rays on trees and granite cliffs.")]),
                replyCount: 0, repostCount: 8, likeCount: 52,
                indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
            )
        ]
        
        let feedItems = posts.map { FeedViewPost(post: $0) }
        return GetTimelineResponse(feed: feedItems, cursor: "next_cursor_page_1")
    }
    
    private func generateMockThread(for postUri: String) -> GetPostThreadResponse {
        let currentPostId = postUri.components(separatedBy: "/").last ?? "101"
        
        let author = ProfileViewBasic(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Smith", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150")
        let rootPost = Post(
            uri: postUri,
            cid: "cid" + currentPostId,
            author: author,
            record: PostRecord(text: "This is the post we are inspecting in the thread. It has multiple replies to demonstrate our HIG-compliant thread rendering system.", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))),
            replyCount: 2, repostCount: 5, likeCount: 15,
            indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        )
        
        let repliers = [
            ProfileViewBasic(did: "did:plc:r1", handle: "charlie.bsky.social", displayName: "Charlie Brown", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150"),
            ProfileViewBasic(did: "did:plc:r2", handle: "diana.bsky.social", displayName: "Diana Prince", avatar: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150")
        ]
        
        let replyNodes = [
            ThreadNode(
                type: "app.bsky.feed.defs#threadViewPost",
                post: Post(
                    uri: "at://did:plc:r1/app.bsky.feed.post/901",
                    cid: "cid901",
                    author: repliers[0],
                    record: PostRecord(text: "Wow! The interface layout looks incredibly clean. Love the thread tree visuals.", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))),
                    replyCount: 0, repostCount: 0, likeCount: 3,
                    indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))
                ),
                replies: []
            ),
            ThreadNode(
                type: "app.bsky.feed.defs#threadViewPost",
                post: Post(
                    uri: "at://did:plc:r2/app.bsky.feed.post/902",
                    cid: "cid902",
                    author: repliers[1],
                    record: PostRecord(text: "Does this also support caching posts locally to view later offline?", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-900))),
                    replyCount: 1, repostCount: 0, likeCount: 5,
                    indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-900))
                ),
                replies: [
                    ThreadNode(
                        type: "app.bsky.feed.defs#threadViewPost",
                        post: Post(
                            uri: "at://did:plc:1/app.bsky.feed.post/903",
                            cid: "cid903",
                            author: author,
                            record: PostRecord(text: "Yes, it implements a LocalStore that persists post structures using native caching policies!", createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))),
                            replyCount: 0, repostCount: 0, likeCount: 2,
                            indexedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))
                        ),
                        replies: []
                    )
                ]
            )
        ]
        
        let mainNode = ThreadNode(
            type: "app.bsky.feed.defs#threadViewPost",
            post: rootPost,
            parent: nil,
            replies: replyNodes
        )
        
        return GetPostThreadResponse(thread: mainNode)
    }
}
