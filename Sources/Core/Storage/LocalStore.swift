import ObjectBox
import Foundation
import Combine

public struct CustomFeed: Codable, Hashable {
    public let uri: String
    public let displayName: String
    public let description: String
    public let avatar: String
    public var isPinned: Bool
    
    public init(uri: String, displayName: String, description: String, avatar: String, isPinned: Bool) {
        self.uri = uri
        self.displayName = displayName
        self.description = description
        self.avatar = avatar
        self.isPinned = isPinned
    }
}

@MainActor
public final class LocalStore: ObservableObject {
    @Published public var cachedFeed: [FeedViewPost] = []
    @Published public var savedPostUris: Set<String> = []
    @Published public var readPostUris: Set<String> = []
    @Published public var localAbuseScores: [String: Double] = [:]
    @Published public var lastTransactionDurationMs: Double = 0.0
    @Published public var pendingOutboxCount: Int = 0
    @Published public var pinnedFeeds: [CustomFeed] = []
    
    private var store: Store?
    private var postBox: Box<CachedPostEntity>?
    private var outboxBox: Box<OutboxActionEntity>?
    private var feedBox: Box<CustomFeedEntity>?
    
    public init() {
        initializeStore()
        loadFromDatabase()
        evictOldUnbookmarkedPosts()
        updatePendingOutboxCount()
        loadPinnedFeeds()
    }
    
    // Auxiliary initializer for unit testing using in-memory ObjectBox Prefix
    public init(inMemoryName: String) {
        do {
            self.store = try Store(directoryPath: Store.inMemoryPrefix + inMemoryName)
            if let store = store {
                self.postBox = store.box(for: CachedPostEntity.self)
                self.outboxBox = store.box(for: OutboxActionEntity.self)
                self.feedBox = store.box(for: CustomFeedEntity.self)
            }
        } catch {
            print("Failed to initialize in-memory ObjectBox: \(error)")
        }
        loadFromDatabase()
        updatePendingOutboxCount()
        loadPinnedFeeds()
    }
    
    private func initializeStore() {
        do {
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let directory = paths[0].appendingPathComponent("SwiftPaperATProto", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Hardening: Restrict directory permissions to owner only (700) to block local processes access
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            
            self.store = try Store(directoryPath: directory.path)
            if let store = store {
                self.postBox = store.box(for: CachedPostEntity.self)
                self.outboxBox = store.box(for: OutboxActionEntity.self)
                self.feedBox = store.box(for: CustomFeedEntity.self)
            }
        } catch {
            print("Failed to initialize ObjectBox: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load & Self-Healing Core
    private func loadFromDatabase() {
        guard let box = postBox else { return }
        do {
            let entities = try box.all()
            var validPosts: [FeedViewPost] = []
            var savedUris: Set<String> = []
            var readUris: Set<String> = []
            var scores: [String: Double] = [:]
            
            var corruptEntityIds: [Id] = []
            
            for entity in entities {
                // Self-Healing validation: check for malformed ATProtocol post URIs or metadata
                let isValidUri = entity.uri.starts(with: "at://") && entity.uri.contains("/app.bsky.feed.post/")
                if !isValidUri || entity.authorHandle.isEmpty {
                    // Record ID for self-healing eviction
                    corruptEntityIds.append(entity.id)
                    continue
                }
                
                let post = entity.toFeedViewPost()
                validPosts.append(post)
                if entity.isSaved {
                    savedUris.insert(entity.uri)
                }
                if entity.isRead {
                    readUris.insert(entity.uri)
                }
                scores[entity.uri] = entity.localAbuseScore
            }
            
            // Delete corrupt records automatically (self-healing database schema drift)
            if !corruptEntityIds.isEmpty {
                try box.remove(corruptEntityIds)
                print("Self-healed: removed \(corruptEntityIds.count) corrupt entities.")
            }
            
            self.cachedFeed = validPosts
            self.savedPostUris = savedUris
            self.readPostUris = readUris
            self.localAbuseScores = scores
        } catch {
            print("Database transaction failure: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 7-Day Cache Eviction
    public func evictOldUnbookmarkedPosts() {
        guard let box = postBox else { return }
        do {
            let entities = try box.all()
            let currentDate = Date()
            let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
            
            let formatter = ISO8601DateFormatter()
            var expiredEntityIds: [Id] = []
            
            for entity in entities {
                // If it is bookmarked (saved), never evict
                if entity.isSaved { continue }
                
                // Parse date
                if let postDate = formatter.date(from: entity.createdAt) {
                    let age = currentDate.timeIntervalSince(postDate)
                    if age > sevenDaysInSeconds {
                        expiredEntityIds.append(entity.id)
                    }
                } else {
                    // Evict post if date is corrupt (Self-healing fallback)
                    expiredEntityIds.append(entity.id)
                }
            }
            
            if !expiredEntityIds.isEmpty {
                try box.remove(expiredEntityIds)
                print("Cache Eviction: purged \(expiredEntityIds.count) expired timeline posts (>7 days old).")
                loadFromDatabase()
            }
        } catch {
            print("Eviction routine failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Feed Timeline
    public func cacheFeed(_ feed: [FeedViewPost]) {
        guard let box = postBox else { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let entities = try box.all()
            
            try store?.runInTransaction {
                for item in feed {
                    let uri = item.post.uri
                    // Input validation check
                    guard uri.starts(with: "at://") else { continue }
                    
                    let existing = entities.first(where: { $0.uri == uri })
                    
                    let isSaved = existing?.isSaved ?? savedPostUris.contains(uri)
                    let isRead = existing?.isRead ?? readPostUris.contains(uri)
                    
                    var score = localAbuseScores[uri] ?? existing?.localAbuseScore
                    if score == nil {
                        let text = item.post.record.text
                        if text.contains("!!!") || text.uppercased() == text {
                            score = Double.random(in: 0.4...0.7)
                        } else {
                            score = Double.random(in: 0.01...0.15)
                        }
                    }
                    
                    let entity = CachedPostEntity(from: item, isSaved: isSaved, isRead: isRead, abuseScore: score ?? 0.0)
                    if let old = existing {
                        entity.id = old.id
                    }
                    try box.put(entity)
                }
            }
        } catch {
            print("Failed to cache feed records in ObjectBox: \(error.localizedDescription)")
        }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        self.lastTransactionDurationMs = duration
        
        loadFromDatabase()
        evictOldUnbookmarkedPosts() // Sweep cache for expired entries
    }
    
    // MARK: - Cache Clearing
    public func clearCache() {
        guard let box = postBox else { return }
        do {
            // Keep saved items (bookmarks) when clearing standard cache, or delete all depending on action.
            // Under settings "Clear Cache & Bookmarks" we clear everything.
            try box.removeAll()
        } catch {
            print("Failed to clear database: \(error.localizedDescription)")
        }
        loadFromDatabase()
    }
    
    // MARK: - Bookmark & Read Management
    public func toggleSavePost(uri: String) {
        guard let box = postBox else { return }
        do {
            let entities = try box.all()
            if let entity = entities.first(where: { $0.uri == uri }) {
                entity.isSaved.toggle()
                try box.put(entity)
            }
        } catch {
            print("Failed to update bookmark state: \(error.localizedDescription)")
        }
        loadFromDatabase()
    }
    
    public func markAsRead(uri: String) {
        guard let box = postBox else { return }
        do {
            let entities = try box.all()
            if let entity = entities.first(where: { $0.uri == uri }) {
                entity.isRead = true
                try box.put(entity)
            }
        } catch {
            print("Failed to update read state: \(error.localizedDescription)")
        }
        loadFromDatabase()
    }
    
    public func isSaved(uri: String) -> Bool {
        savedPostUris.contains(uri)
    }
    
    public func isRead(uri: String) -> Bool {
        readPostUris.contains(uri)
    }
    
    // MARK: - Offline Outbox Operations
    
    func queueOutboxAction(type: String, payloadJson: String) {
        guard let box = outboxBox else { return }
        do {
            let action = OutboxActionEntity(
                actionType: type,
                payloadJson: payloadJson,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            try box.put(action)
        } catch {
            print("Failed to queue outbox action: \(error.localizedDescription)")
        }
        updatePendingOutboxCount()
    }
    
    func getAllPendingActions() -> [OutboxActionEntity] {
        guard let box = outboxBox else { return [] }
        return (try? box.all()) ?? []
    }
    
    func removeOutboxAction(id: Id) {
        guard let box = outboxBox else { return }
        do {
            try box.remove(id)
        } catch {
            print("Failed to remove outbox action: \(error.localizedDescription)")
        }
        updatePendingOutboxCount()
    }
    
    func updatePendingOutboxCount() {
        guard let box = outboxBox else {
            self.pendingOutboxCount = 0
            return
        }
        self.pendingOutboxCount = (try? box.count()) ?? 0
    }
    
    // MARK: - Custom Feeds Storage & Algorithmic Sorting
    
    func subscribeToFeed(uri: String, displayName: String, description: String, avatar: String) {
        guard let box = feedBox else { return }
        do {
            let entities = try box.all()
            let existing = entities.first(where: { $0.uri == uri })
            
            let entity = CustomFeedEntity(
                uri: uri,
                displayName: displayName,
                description: description,
                avatar: avatar,
                isPinned: existing?.isPinned ?? true,
                isSubscribed: true
            )
            if let old = existing {
                entity.id = old.id
            }
            try box.put(entity)
        } catch {
            print("Failed to subscribe to custom feed: \(error.localizedDescription)")
        }
        loadPinnedFeeds()
    }
    
    func togglePinFeed(uri: String) {
        guard let box = feedBox else { return }
        do {
            let entities = try box.all()
            if let existing = entities.first(where: { $0.uri == uri }) {
                existing.isPinned.toggle()
                try box.put(existing)
            }
        } catch {
            print("Failed to toggle pin state: \(error.localizedDescription)")
        }
        loadPinnedFeeds()
    }
    
    func loadPinnedFeeds() {
        guard let box = feedBox else { return }
        do {
            let entities = try box.all()
            self.pinnedFeeds = entities.filter { $0.isPinned && $0.isSubscribed }.map {
                CustomFeed(
                    uri: $0.uri,
                    displayName: $0.displayName,
                    description: $0.feedDescription,
                    avatar: $0.avatar,
                    isPinned: $0.isPinned
                )
            }
        } catch {
            print("Failed to load pinned feeds: \(error.localizedDescription)")
        }
    }
    
    public func getLocalSortedFeed(for feedUri: String? = nil) -> [FeedViewPost] {
        // Retrieve standard cached feed
        let posts = cachedFeed
        
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        
        struct ScoredPost {
            let post: FeedViewPost
            let score: Double
        }
        
        var scoredPosts: [ScoredPost] = []
        
        for item in posts {
            // 1. Calculate recency decay score
            var recencyScore = 0.5
            if let postDate = formatter.date(from: item.post.record.createdAt) {
                let delta = max(0.0, currentDate.timeIntervalSince(postDate))
                // Decay divisor representing age decay rate (e.g. 24 hours)
                recencyScore = 1.0 / (1.0 + (delta / 86400.0))
            }
            
            // 2. Apply bookmark bonus and read penalty
            let isSaved = savedPostUris.contains(item.post.uri)
            let isRead = readPostUris.contains(item.post.uri)
            let abuseScore = localAbuseScores[item.post.uri] ?? 0.0
            
            let bookmarkBonus = isSaved ? 0.35 : 0.0
            let readPenalty = isRead ? 0.5 : 0.0
            let abusePenalty = abuseScore
            
            let rawScore = recencyScore + bookmarkBonus - readPenalty - abusePenalty
            
            // Hardening: Clamp final score to [0.0, 1.0] to prevent overflow/underflow exploits
            let clampedScore = max(0.0, min(1.0, rawScore))
            
            scoredPosts.append(ScoredPost(post: item, score: clampedScore))
        }
        
        // Sort descending by score
        let sorted = scoredPosts.sorted { $0.score > $1.score }.map { $0.post }
        return sorted
    }
}
