import Foundation
import XCTest
import SwiftTreeSitter
import CodeEditLanguages
@testable import OrgKit

final class TreeSitterIntegrationTests: XCTestCase {
    var parser: Parser!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        parser = Parser()
        
        guard let codeLang = CodeLanguage.allLanguages.first(where: { "\($0.id)".lowercased().contains("markdown") }),
              let tsLang = codeLang.language else {
            XCTFail("Markdown language not found")
            return
        }
        
        try parser.setLanguage(tsLang)
    }
    
    /// Verify if dividing Tree-sitter byte offsets by 2 matches Swift's UTF-16 code unit offsets.
    func testHeadingOffsetCorrectionWithMultiByteCharacters() throws {
        // Markdown containing multi-byte characters
        let sourceString = "# Heading with Multi-byte 🌐\n\nSome body text."
        guard let tree = parser.parse(sourceString) else {
            XCTFail("Failed to parse")
            return
        }
        
        var foundText = ""
        
        func walk(_ node: Node) {
            if let type = node.nodeType, type == "atx_heading" {
                let byteRange = node.byteRange
                // In this integration, byte offsets appear to be 2x UTF-16 code unit offsets.
                let start = Int(byteRange.lowerBound) / 2
                let end = Int(byteRange.upperBound) / 2
                
                if sourceString.utf16.index(sourceString.utf16.startIndex, offsetBy: start, limitedBy: sourceString.utf16.endIndex) != nil,
                   sourceString.utf16.index(sourceString.utf16.startIndex, offsetBy: end, limitedBy: sourceString.utf16.endIndex) != nil,
                   let range = Range(NSRange(location: start, length: end - start), in: sourceString) {
                    foundText = String(sourceString[range])
                }
            }
            for i in 0..<node.childCount {
                if let child = node.child(at: i) {
                    walk(child)
                }
            }
        }
        
        if let root = tree.rootNode {
            walk(root)
        }
        
        XCTAssertTrue(foundText.hasPrefix("# Heading with Multi-byte 🌐"))
    }
}
