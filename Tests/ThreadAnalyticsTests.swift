import XCTest
@testable import SwiftPaperATProtoCore

final class ThreadAnalyticsTests: XCTestCase {
    
    // MARK: - Stance Classification Tests
    
    func testStanceCoverageClassification() {
        // 1. Supportive post text
        let supTexts = [
            "I totally agree, this is awesome!",
            "Great work, I love this new feature!",
            "Yes, congratulations on the launch."
        ]
        let supStances = ThreadAnalytics.calculateStanceCoverage(from: supTexts)
        XCTAssertGreaterThan(supStances["Supportive"] ?? 0.0, 0.5)
        
        // 2. Skeptical post text
        let skpTexts = [
            "I doubt this will work, why did they do this?",
            "I disagree with the layout, this is a major concern.",
            "Skeptical about the performance scaling."
        ]
        let skpStances = ThreadAnalytics.calculateStanceCoverage(from: skpTexts)
        XCTAssertGreaterThan(skpStances["Skeptical"] ?? 0.0, 0.5)
        
        // 3. Analytical post text
        let anaTexts = [
            "Here is the benchmark data report.",
            "Compare the metrics and performance code links.",
            "Show the numbers explaining this comparison."
        ]
        let anaStances = ThreadAnalytics.calculateStanceCoverage(from: anaTexts)
        XCTAssertGreaterThan(anaStances["Analytical"] ?? 0.0, 0.5)
    }
    
    // MARK: - Entity Extraction Tests
    
    func testEntityExtraction() {
        let texts = [
            "Learning SwiftUI and building on the ATProto network today. #swiftui #atproto",
            "Decentralization is the future of social networks. SwiftUI rules!"
        ]
        let entities = ThreadAnalytics.extractCentralEntities(from: texts)
        
        // Assert that the stop words like 'learning', 'building', 'today' are not selected,
        // and hashtags like 'swiftui' or 'atproto' are selected, or capitalized proper nouns like 'SwiftUI'.
        XCTAssertTrue(entities.contains("Swiftui") || entities.contains("SwiftUI"))
        XCTAssertTrue(entities.contains("Atproto") || entities.contains("ATProto"))
    }
    
    // MARK: - Integrity Scoring Tests
    
    func testIntegrityScoringCalculations() {
        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())
        
        let authorNormal = ProfileViewBasic(did: "did:plc:normal", handle: "user.bsky.social", displayName: "User", avatar: nil)
        let authorMock = ProfileViewBasic(did: "did:plc:mock-adversarial", handle: "mock.bsky.social", displayName: "Mock User", avatar: nil)
        
        // 1. High-quality thread (normal authors, long texts, external links)
        let rootPostNormal = Post(
            uri: "at://did:plc:normal/app.bsky.feed.post/1",
            cid: "cid1",
            author: authorNormal,
            record: PostRecord(text: "This is a detailed analysis containing comprehensive details and evidence references.", createdAt: nowString),
            embed: Embed(type: "app.bsky.embed.external", external: EmbedExternal(uri: "https://example.com", title: "Fact Source Link", description: "Verified citation info", thumb: nil)),
            replyCount: 0, repostCount: 0, likeCount: 0,
            indexedAt: nowString
        )
        let nodeNormal = ThreadNode(type: "app.bsky.feed.defs#threadViewPost", post: rootPostNormal, replies: [])
        let integrityNormal = ThreadAnalytics.calculateIntegrity(from: [nodeNormal], texts: [rootPostNormal.record.text])
        
        // 2. Low-quality thread (mock author, very short all-caps texts, no links)
        let rootPostMock = Post(
            uri: "at://did:plc:mock-adversarial/app.bsky.feed.post/2",
            cid: "cid2",
            author: authorMock,
            record: PostRecord(text: "SPAM TEXT!", createdAt: nowString),
            embed: nil,
            replyCount: 0, repostCount: 0, likeCount: 0,
            indexedAt: nowString
        )
        let nodeMock = ThreadNode(type: "app.bsky.feed.defs#threadViewPost", post: rootPostMock, replies: [])
        let integrityMock = ThreadAnalytics.calculateIntegrity(from: [nodeMock], texts: [rootPostMock.record.text])
        
        // High quality should score higher than low quality
        XCTAssertGreaterThan(integrityNormal, integrityMock)
    }
}
