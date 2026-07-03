import Foundation

public struct ThreadInsight: Codable, Hashable {
    public let stanceCoverage: [String: Double]
    public let centralEntities: [String]
    public let integrityScore: Double
    
    public init(stanceCoverage: [String: Double], centralEntities: [String], integrityScore: Double) {
        self.stanceCoverage = stanceCoverage
        self.centralEntities = centralEntities
        self.integrityScore = integrityScore
    }
}

public final class ThreadAnalytics {
    
    private static let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "and", "but", "or", "to", "in", 
        "on", "at", "it", "of", "for", "with", "this", "that", "these", "those", 
        "you", "my", "we", "they", "he", "she", "it", "our", "us", "your", "i", "me"
    ]
    
    public static func analyzeThread(_ root: ThreadNode) -> ThreadInsight {
        var allNodes: [ThreadNode] = []
        flattenThread(root, result: &allNodes)
        
        let texts = allNodes.compactMap { $0.post?.record.text }
        
        // 1. Calculate Stance Coverage
        let stances = calculateStanceCoverage(from: texts)
        
        // 2. Extract Central Entities
        let entities = extractCentralEntities(from: texts)
        
        // 3. Compute Integrity Score
        let integrity = calculateIntegrity(from: allNodes, texts: texts)
        
        return ThreadInsight(
            stanceCoverage: stances,
            centralEntities: entities,
            integrityScore: integrity
        )
    }
    
    // MARK: - Recursion Helper
    private static func flattenThread(_ node: ThreadNode, result: inout [ThreadNode]) {
        result.append(node)
        if let replies = node.replies {
            for child in replies {
                flattenThread(child, result: &result)
            }
        }
    }
    
    // MARK: - Local Stance Classifier (Deterministic NLP)
    public static func calculateStanceCoverage(from texts: [String]) -> [String: Double] {
        guard !texts.isEmpty else {
            return ["Analytical": 1.0, "Supportive": 0.0, "Skeptical": 0.0]
        }
        
        let supportiveKeywords = ["agree", "yes", "great", "nice", "love", "awesome", "perfect", "good", "cool", "wonderful", "like", "support", "congrats"]
        let skepticalKeywords = ["skeptical", "doubt", "but", "why", "how", "unlikely", "disagree", "issue", "problem", "fail", "broken", "flaw", "concern"]
        let analyticalKeywords = ["data", "source", "link", "metrics", "analytics", "numbers", "report", "fact", "code", "explain", "details", "compare", "benchmark"]
        
        var supportiveCount = 0
        var skepticalCount = 0
        var analyticalCount = 0
        
        for text in texts {
            let lowercased = text.lowercased()
            
            var supScore = 0
            var skpScore = 0
            var anaScore = 0
            
            for keyword in supportiveKeywords {
                if lowercased.contains(keyword) { supScore += 1 }
            }
            for keyword in skepticalKeywords {
                if lowercased.contains(keyword) { skpScore += 1 }
            }
            for keyword in analyticalKeywords {
                if lowercased.contains(keyword) { anaScore += 1 }
            }
            
            // Assign to highest score, default to Analytical if tied or empty
            if supScore > skpScore && supScore > anaScore {
                supportiveCount += 1
            } else if skpScore > supScore && skpScore > anaScore {
                skepticalCount += 1
            } else {
                analyticalCount += 1
            }
        }
        
        let total = Double(texts.count)
        return [
            "Supportive": Double(supportiveCount) / total,
            "Skeptical": Double(skepticalCount) / total,
            "Analytical": Double(analyticalCount) / total
        ]
    }
    
    // MARK: - Entity Frequency Extractor
    public static func extractCentralEntities(from texts: [String]) -> [String] {
        var wordFrequencies: [String: Int] = [:]
        
        for text in texts {
            // Extract hashtags directly
            let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted.union(.whitespacesAndNewlines))
            let rawWords = text.components(separatedBy: .whitespacesAndNewlines)
            
            // Process hashtags first
            for word in rawWords {
                if word.hasPrefix("#") && word.count > 2 {
                    let cleaned = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
                    if !cleaned.isEmpty {
                        wordFrequencies[cleaned, default: 0] += 5 // Heavy weighting for hashtags
                    }
                }
            }
            
            // Process regular words
            for word in words {
                let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard cleaned.count > 3 else { continue } // skip short abbreviations
                guard !stopwords.contains(cleaned) else { continue }
                
                // Exclude pure numbers
                if Double(cleaned) == nil {
                    wordFrequencies[cleaned, default: 0] += 1
                }
            }
        }
        
        // Sort and select top 4 entities
        let sortedEntities = wordFrequencies.sorted(by: { $0.value > $1.value })
        let topEntities = sortedEntities.prefix(4).map { $0.key.capitalized }
        
        return topEntities.isEmpty ? ["Conversation", "Timeline", "Social"] : topEntities
    }
    
    // MARK: - Trust Integrity Scoring
    public static func calculateIntegrity(from nodes: [ThreadNode], texts: [String]) -> Double {
        guard !nodes.isEmpty else { return 1.0 }
        
        var baseScore = 1.0
        
        // 1. Deduct for mock accounts
        let mockCount = nodes.filter { $0.post?.author.did.contains("mock") == true }.count
        let mockRatio = Double(mockCount) / Double(nodes.count)
        baseScore -= (mockRatio * 0.15)
        
        // 2. Deduct for spammy or low-quality replies (all caps, or extremely short)
        var lowQualityCount = 0
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 12 {
                lowQualityCount += 1
            } else if trimmed == trimmed.uppercased() && trimmed.count > 8 {
                lowQualityCount += 1
            }
        }
        let lowQualityRatio = Double(lowQualityCount) / Double(nodes.count)
        baseScore -= (lowQualityRatio * 0.20)
        
        // 3. Add credit for rich evidence embeds (external verified URLs, link headers)
        let embedCount = nodes.filter { $0.post?.embed?.external != nil || $0.post?.embed?.images != nil }.count
        let embedRatio = Double(embedCount) / Double(nodes.count)
        baseScore += (embedRatio * 0.15)
        
        // Clamp bounds securely between 10% and 100%
        return max(0.1, min(1.0, baseScore))
    }
}
