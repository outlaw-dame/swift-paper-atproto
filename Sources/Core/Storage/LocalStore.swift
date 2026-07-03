import Foundation
import Combine

@MainActor
public final class LocalStore: ObservableObject {
    @Published public var cachedFeed: [FeedViewPost] = []
    @Published public var savedPostUris: Set<String> = []
    @Published public var readPostUris: Set<String> = []
    @Published public var localAbuseScores: [String: Double] = [:] // Mocked local safety classifier
    
    private let cacheFile: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("SwiftPaperATProto", isDirectory: true)
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("feed_cache.json")
    }()
    
    private let savedUrisKey = "saved_post_uris"
    private let readUrisKey = "read_post_uris"
    
    public init() {
        loadSavedAndReadState()
        loadFeedCache()
    }
    
    // MARK: - Cache Management
    public func cacheFeed(_ feed: [FeedViewPost]) {
        self.cachedFeed = feed
        saveFeedCache()
        
        // Populate mock abuse/safety scores for demonstration
        for item in feed {
            let uri = item.post.uri
            if localAbuseScores[uri] == nil {
                // High-quality text gets low abuse score, spam/all-caps gets slightly higher
                let text = item.post.record.text
                if text.contains("!!!") || text.uppercased() == text {
                    localAbuseScores[uri] = Double.random(in: 0.4...0.7)
                } else {
                    localAbuseScores[uri] = Double.random(in: 0.01...0.15)
                }
            }
        }
    }
    
    public func clearCache() {
        self.cachedFeed = []
        try? FileManager.default.removeItem(at: cacheFile)
    }
    
    // MARK: - Post Interaction State
    public func toggleSavePost(uri: String) {
        if savedPostUris.contains(uri) {
            savedPostUris.remove(uri)
        } else {
            savedPostUris.insert(uri)
        }
        UserDefaults.standard.set(Array(savedPostUris), forKey: savedUrisKey)
    }
    
    public func markAsRead(uri: String) {
        readPostUris.insert(uri)
        UserDefaults.standard.set(Array(readPostUris), forKey: readUrisKey)
    }
    
    public func isSaved(uri: String) -> Bool {
        savedPostUris.contains(uri)
    }
    
    public func isRead(uri: String) -> Bool {
        readPostUris.contains(uri)
    }
    
    // MARK: - Helper Persistence Methods
    private func saveFeedCache() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cachedFeed)
            try data.write(to: cacheFile, options: [.atomic])
        } catch {
            print("Failed to save feed cache: \(error.localizedDescription)")
        }
    }
    
    private func loadFeedCache() {
        guard FileManager.default.fileExists(atPath: cacheFile.path) else { return }
        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            self.cachedFeed = try decoder.decode([FeedViewPost].self, from: data)
        } catch {
            print("Failed to load feed cache: \(error.localizedDescription)")
        }
    }
    
    private func loadSavedAndReadState() {
        if let saved = UserDefaults.standard.stringArray(forKey: savedUrisKey) {
            self.savedPostUris = Set(saved)
        }
        if let read = UserDefaults.standard.stringArray(forKey: readUrisKey) {
            self.readPostUris = Set(read)
        }
    }
}
