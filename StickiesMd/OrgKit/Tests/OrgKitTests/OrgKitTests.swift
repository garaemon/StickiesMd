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
    
    /// 検証: Tree-sitter のオフセットを 2 で割ることで、Swift の UTF-16 文字数と一致するか
    func testHeadingOffsetCorrectionWithJapanese() throws {
        // 日本語を含む Markdown
        let sourceString = "# はじめての付箋\n\n本文です。"
        guard let tree = parser.parse(sourceString) else {
            XCTFail("Failed to parse")
            return
        }
        
        var foundText = ""
        
        func walk(_ node: Node) {
            if let type = node.nodeType, type == "atx_heading" {
                let byteRange = node.byteRange
                // この統合環境における「黄金律」: オフセットを 2 で割る
                let start = Int(byteRange.lowerBound) / 2
                let end = Int(byteRange.upperBound) / 2
                
                let utf16 = sourceString.utf16
                if start < utf16.count && end <= utf16.count {
                    let startIdx = sourceString.index(sourceString.startIndex, offsetBy: start)
                    let endIdx = sourceString.index(sourceString.startIndex, offsetBy: end)
                    foundText = String(sourceString[startIdx..<endIdx])
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
        
        // 正しく取得できていれば、見出し記号を含めて一致するはず
        XCTAssertTrue(foundText.hasPrefix("# はじめての付箋"))
    }
}