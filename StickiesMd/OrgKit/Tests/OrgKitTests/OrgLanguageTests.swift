import Foundation
import SwiftTreeSitter
import XCTest

@testable import OrgKit

final class OrgLanguageTests: XCTestCase {
  func testLanguageIsAvailable() throws {
    let language = OrgLanguage.language
    XCTAssertNotNil(language, "OrgLanguage.language should not be nil")
  }

  func testParseOrgHeadings() throws {
    let language = try XCTUnwrap(OrgLanguage.language)
    let parser = Parser()
    try parser.setLanguage(language)

    let source = "* Heading 1\n** Heading 2\n*** Heading 3\n"
    let tree = try XCTUnwrap(parser.parse(source))
    let rootNode = try XCTUnwrap(tree.rootNode)

    var headlineCount = 0
    walkNode(rootNode) { node in
      if node.nodeType == "headline" {
        headlineCount += 1
      }
    }
    XCTAssertEqual(headlineCount, 3, "Should find 3 headlines")
  }

  func testHeadingLevelFromStars() throws {
    let language = try XCTUnwrap(OrgLanguage.language)
    let parser = Parser()
    try parser.setLanguage(language)

    let source = "* Level 1\n** Level 2\n*** Level 3\n"
    let tree = try XCTUnwrap(parser.parse(source))
    let rootNode = try XCTUnwrap(tree.rootNode)

    var levels: [Int] = []
    walkNode(rootNode) { node in
      if node.nodeType == "stars" {
        let byteRange = node.byteRange
        let starCount = Int(byteRange.upperBound - byteRange.lowerBound) / 2
        levels.append(starCount)
      }
    }
    XCTAssertEqual(levels, [1, 2, 3])
  }

  func testMultiByteCharactersInHeadings() throws {
    let language = try XCTUnwrap(OrgLanguage.language)
    let parser = Parser()
    try parser.setLanguage(language)

    let source = "* Heading with emoji \u{1F310}\n** Another heading\n"
    let tree = try XCTUnwrap(parser.parse(source))
    let rootNode = try XCTUnwrap(tree.rootNode)

    var headlineTexts: [String] = []
    walkNode(rootNode) { node in
      if node.nodeType == "headline" {
        let byteRange = node.byteRange
        let start = Int(byteRange.lowerBound) / 2
        let end = Int(byteRange.upperBound) / 2

        if let startIdx = source.utf16.index(
          source.utf16.startIndex, offsetBy: start, limitedBy: source.utf16.endIndex),
          let endIdx = source.utf16.index(
            source.utf16.startIndex, offsetBy: end, limitedBy: source.utf16.endIndex),
          let range = Range(NSRange(startIdx..<endIdx, in: source), in: source)
        {
          headlineTexts.append(String(source[range]))
        }
      }
    }

    XCTAssertEqual(headlineTexts.count, 2)
    XCTAssertTrue(headlineTexts[0].contains("\u{1F310}"))
    XCTAssertTrue(headlineTexts[1].contains("Another heading"))
  }

  private func walkNode(_ node: Node, visitor: (Node) -> Void) {
    visitor(node)
    for i in 0..<node.childCount {
      if let child = node.child(at: i) {
        walkNode(child, visitor: visitor)
      }
    }
  }
}
