import Foundation

/// Helper to parse ATProto facets and format them into an interactive `AttributedString` link graph.
/// Uses safe byte-to-character indexing mapping to protect against malformed UTF-8 offsets.
public enum RichTextParser {
    
    /// Parses a string and its associated facets into an interactive `AttributedString`.
    /// Handles invalid/corrupted facets safely without crashing.
    public static func format(text: String, facets: [Facet]?) -> AttributedString {
        var attrString = AttributedString(text)
        guard let facets = facets, !facets.isEmpty else { return attrString }
        
        // Sort facets by start index descending to avoid character offset shifting issues if we modify ranges,
        // although AttributedString ranges are index-independent, it is good hygiene.
        let sortedFacets = facets.sorted { $0.index.byteStart > $1.index.byteStart }
        
        for facet in sortedFacets {
            guard let charRange = facet.index.characterRange(in: text) else {
                continue // Skip out-of-bounds or split-character bounds
            }
            
            // Map the String range to AttributedString range
            guard let attrRange = Range(charRange, in: attrString) else {
                continue
            }
            
            for feature in facet.features {
                switch feature {
                case .mention(let did):
                    // Use a custom scheme to let MainTabView handle navigation
                    if let url = URL(string: "atproto://mention?did=\(did)") {
                        attrString[attrRange].link = url
                        attrString[attrRange].underlineStyle = .single
                    }
                case .link(let uri):
                    // Security guard: Validate external URL scheme to prevent javascript: or SSRF injections
                    if ATProtoURLValidator.isAllowedExternalURL(uri),
                       let url = URL(string: uri) {
                        attrString[attrRange].link = url
                        attrString[attrRange].underlineStyle = .single
                    }
                case .tag(let tag):
                    // Percent-encode the tag for safety in URL
                    if let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "atproto://tag?name=\(encodedTag)") {
                        attrString[attrRange].link = url
                        attrString[attrRange].underlineStyle = .single
                    }
                case .unknown:
                    break
                }
            }
        }
        
        return attrString
    }
}
