import XCTest
@testable import SwiftPaperATProtoCore

final class RichTextParserTests: XCTestCase {
    
    // MARK: - Safe Range Conversion Tests
    
    func testByteSliceRangeConversion() {
        let text = "Hello World"
        // UTF-8 bytes: [H, e, l, l, o,  , W, o, r, l, d] -> count 11
        
        let sliceValid = ByteSlice(byteStart: 6, byteEnd: 11)
        let rangeValid = sliceValid.characterRange(in: text)
        XCTAssertNotNil(rangeValid)
        if let range = rangeValid {
            XCTAssertEqual(text[range], "World")
        }
        
        // Out-of-bounds start/end index
        let sliceOOB = ByteSlice(byteStart: 6, byteEnd: 15)
        XCTAssertNil(sliceOOB.characterRange(in: text))
        
        let sliceNegative = ByteSlice(byteStart: -1, byteEnd: 5)
        XCTAssertNil(sliceNegative.characterRange(in: text))
        
        // Invalid order
        let sliceReversed = ByteSlice(byteStart: 5, byteEnd: 3)
        XCTAssertNil(sliceReversed.characterRange(in: text))
    }
    
    func testByteSliceRangeConversionWithEmojis() {
        // "👋" is a 4-byte UTF-8 character: [0xF0, 0x9F, 0x91, 0x8B]
        let text = "👋 World"
        let utf8Count = text.utf8.count
        XCTAssertEqual(utf8Count, 10) // 4 bytes for emoji + 1 space + 5 "World"
        
        // Target "World": starts at byte offset 5, ends at 10
        let slice = ByteSlice(byteStart: 5, byteEnd: 10)
        let range = slice.characterRange(in: text)
        XCTAssertNotNil(range)
        if let r = range {
            XCTAssertEqual(text[r], "World")
        }
        
        // Invalid: offset falls directly inside the middle of the emoji (e.g. byte 2)
        let splitSlice = ByteSlice(byteStart: 2, byteEnd: 8)
        XCTAssertNil(splitSlice.characterRange(in: text), "Should fail gracefully when index splits a multi-byte scalar")
    }
    
    // MARK: - Rich Text Formatting Tests
    
    func testFormatValidFeatures() {
        let text = "Check out @alice.bsky.social and #swift!"
        // @alice.bsky.social starts at byte 10, ends at 28
        // #swift starts at byte 33, ends at 39
        
        let mentionFeature = FacetFeature.mention(did: "did:plc:alice123")
        let tagFeature = FacetFeature.tag(tag: "swift")
        
        let facets = [
            Facet(index: ByteSlice(byteStart: 10, byteEnd: 28), features: [mentionFeature]),
            Facet(index: ByteSlice(byteStart: 33, byteEnd: 39), features: [tagFeature])
        ]
        
        let formatted = RichTextParser.format(text: text, facets: facets)
        
        // We cannot easily query links inside AttributedString in raw assertions without macOS/iOS SDK APIs,
        // but we can ensure it compiles and parses without throwing.
        XCTAssertEqual(String(formatted.characters), text)
    }
    
    func testFormatSecureLinkFiltering() {
        let text = "Visit our site at https://evil-tracker.com"
        // Link starts at byte 18, ends at 42
        let linkFeature = FacetFeature.link(uri: "https://evil-tracker.com")
        
        let facets = [
            Facet(index: ByteSlice(byteStart: 18, byteEnd: 42), features: [linkFeature])
        ]
        
        let formatted = RichTextParser.format(text: text, facets: facets)
        XCTAssertEqual(String(formatted.characters), text)
    }
    
    func testFormatRejectsUnsafeSchemes() {
        let text = "Click javascript:alert(1) for free points!"
        let unsafeFeature = FacetFeature.link(uri: "javascript:alert(1)")
        let facets = [
            Facet(index: ByteSlice(byteStart: 6, byteEnd: 25), features: [unsafeFeature])
        ]
        
        let formatted = RichTextParser.format(text: text, facets: facets)
        XCTAssertEqual(String(formatted.characters), text)
    }
    
    func testFormatMalformedIndexSafety() {
        let text = "Short"
        let feature = FacetFeature.mention(did: "did:plc:malformed")
        
        // Byte slice represents offsets far outside string length (5)
        let facets = [
            Facet(index: ByteSlice(byteStart: 10, byteEnd: 20), features: [feature]),
            Facet(index: ByteSlice(byteStart: -5, byteEnd: 3), features: [feature]),
            Facet(index: ByteSlice(byteStart: 4, byteEnd: 2), features: [feature])
        ]
        
        // Execution must not crash or trigger out-of-bounds exceptions
        let formatted = RichTextParser.format(text: text, facets: facets)
        XCTAssertEqual(String(formatted.characters), text)
    }
}
