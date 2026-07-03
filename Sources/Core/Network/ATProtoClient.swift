import Foundation
import Combine

@MainActor
public final class ATProtoClient: ObservableObject {
    @Published public var session: CreateSessionResponse? = nil
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var useMockData = true // Enabled by default for easy demo/testing
    
    private let baseURL = URL(string: "https://bsky.social/xrpc")!
    
    public init() {}
    
    // MARK: - Login
    public func login(handle: String, appPassword: String) async {
        isLoading = true
        errorMessage = nil
        
        if useMockData || handle.lowercased() == "mock" {
            // Mock login
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.session = CreateSessionResponse(
                did: "did:plc:mockuser12345",
                handle: handle.isEmpty ? "mockuser.bsky.social" : handle,
                email: "mock@example.com",
                accessJwt: "mock_jwt_access_token",
                refreshJwt: "mock_jwt_refresh_token"
            )
            self.isAuthenticated = true
            self.isLoading = false
            return
        }
        
        do {
            let loginURL = baseURL.appendingPathComponent("com.atproto.server.createSession")
            var request = URLRequest(url: loginURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = [
                "identifier": handle,
                "password": appPassword
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let sessionResp = try decoder.decode(CreateSessionResponse.self, from: data)
                self.session = sessionResp
                self.isAuthenticated = true
            } else {
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    self.errorMessage = message
                } else {
                    self.errorMessage = "Login failed with code \(httpResponse.statusCode)"
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Logout
    public func logout() {
        self.session = nil
        self.isAuthenticated = false
        self.errorMessage = nil
    }
    
    // MARK: - Fetch Timeline
    public func fetchTimeline(cursor: String? = nil) async throws -> GetTimelineResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 800_000_000)
            return generateMockTimeline()
        }
        
        guard let session = session else {
            throw URLError(.notConnectedToInternet)
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("app.bsky.feed.getTimeline"), resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem(name: "algorithm", value: "reverse-chronological")]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GetTimelineResponse.self, from: data)
    }
    
    // MARK: - Fetch Thread
    public func fetchThread(postUri: String) async throws -> GetPostThreadResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GetPostThreadResponse.self, from: data)
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
