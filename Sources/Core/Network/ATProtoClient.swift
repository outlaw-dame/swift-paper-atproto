import Foundation
import Combine

@MainActor
public final class ATProtoClient: ObservableObject {
    @Published public var session: CreateSessionResponse? = nil
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var useMockData = true
    
    private let baseURL = URL(string: "https://bsky.social/xrpc")!
    
    // Keychain keys
    private let accessJwtKey = "atproto_access_jwt"
    private let refreshJwtKey = "atproto_refresh_jwt"
    private let handleKey = "atproto_user_handle"
    private let didKey = "atproto_user_did"
    
    public init() {
        restoreSessionFromKeychain()
    }
    
    // MARK: - Input Validation & Sanitization (Adversarial Hardening)
    
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
    
    public func validateCursor(_ cursor: String) -> Bool {
        // Alphanumeric, equals (base64 padding), slashes, dashes, colons, dots, percents (encoded)
        let pattern = "^[a-zA-Z0-9+=/._%:-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: cursor.utf16.count)
        return regex.firstMatch(in: cursor, options: [], range: range) != nil
    }
    
    // MARK: - Keychain Session Storage
    
    private func restoreSessionFromKeychain() {
        guard let access = KeychainHelper.get(key: accessJwtKey),
              let refresh = KeychainHelper.get(key: refreshJwtKey),
              let handle = KeychainHelper.get(key: handleKey),
              let did = KeychainHelper.get(key: didKey) else {
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
        self.useMockData = false // Session restored -> prioritize live API calls
    }
    
    private func persistSessionToKeychain(_ session: CreateSessionResponse) {
        KeychainHelper.save(key: accessJwtKey, value: session.accessJwt)
        KeychainHelper.save(key: refreshJwtKey, value: session.refreshJwt)
        KeychainHelper.save(key: handleKey, value: session.handle)
        KeychainHelper.save(key: didKey, value: session.did)
    }
    
    private func clearSessionFromKeychain() {
        KeychainHelper.delete(key: accessJwtKey)
        KeychainHelper.delete(key: refreshJwtKey)
        KeychainHelper.delete(key: handleKey)
        KeychainHelper.delete(key: didKey)
    }
    
    // MARK: - Exponential Backoff Wrapper
    
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
                
                let isTransientStatus = httpResponse.statusCode == 429 || httpResponse.statusCode == 503 || httpResponse.statusCode == 504
                
                if isTransientStatus && attempt < maxRetries {
                    let delay = calculateDelay(attempt: attempt, initialDelay: initialDelay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                // Sanitize server errors to prevent stack trace leaks
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
        
        if useMockData || sanitizedHandle.lowercased() == "mock" {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let mockSession = CreateSessionResponse(
                did: "did:plc:mockuser12345",
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
    
    public func logout() {
        clearSessionFromKeychain()
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
    
    // MARK: - Mock Generator Helper
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
