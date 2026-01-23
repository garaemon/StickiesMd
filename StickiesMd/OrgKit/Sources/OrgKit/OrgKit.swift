import Foundation

public protocol OrgNode {
    func accept<V: OrgVisitor>(_ visitor: V)
}

public protocol OrgVisitor: AnyObject {
    func visit(_ node: OrgNode)
    func visitDocument(_ node: OrgDocument)
    func visitHeading(_ node: Heading)
    func visitParagraph(_ node: Paragraph)
    func visitList(_ node: ListNode)
    func visitCodeBlock(_ node: CodeBlock)
    func visitHorizontalRule(_ node: HorizontalRule)
    func visitText(_ node: TextNode)
    func visitStrong(_ node: StrongNode)
    func visitEmphasis(_ node: EmphasisNode)
    func visitLink(_ node: LinkNode)
    func visitImage(_ node: ImageNode)
}

extension OrgVisitor {
    public func visit(_ node: OrgNode) {
        node.accept(self)
    }
}

public struct OrgDocument: OrgNode {
    public let children: [OrgNode]
    
    public init(children: [OrgNode]) {
        self.children = children
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitDocument(self)
    }
}

public struct Heading: OrgNode {
    public let level: Int
    public let text: String
    
    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitHeading(self)
    }
}

public struct Paragraph: OrgNode {
    public let children: [OrgNode]
    
    // For backward compatibility (tests)
    public var text: String {
        return children.compactMap { ($0 as? TextNode)?.text }.joined()
    }
    
    public init(children: [OrgNode]) {
        self.children = children
    }
    
    public init(text: String) {
        self.children = [TextNode(text: text)]
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitParagraph(self)
    }
}

public struct ListNode: OrgNode {
    public let items: [String] // Simplified for now, or [OrgNode] if we want nested parsing
    public let ordered: Bool
    
    public init(items: [String], ordered: Bool = false) {
        self.items = items
        self.ordered = ordered
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitList(self)
    }
}

public struct CodeBlock: OrgNode {
    public let language: String?
    public let content: String
    
    public init(language: String?, content: String) {
        self.language = language
        self.content = content
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitCodeBlock(self)
    }
}

public struct HorizontalRule: OrgNode {
    public init() {}
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitHorizontalRule(self)
    }
}

public struct TextNode: OrgNode {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitText(self)
    }
}

public struct StrongNode: OrgNode {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitStrong(self)
    }
}

public struct EmphasisNode: OrgNode {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitEmphasis(self)
    }
}

public struct LinkNode: OrgNode {
    public let url: String
    public let text: String?
    
    public init(url: String, text: String?) {
        self.url = url
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitLink(self)
    }
}

public struct ImageNode: OrgNode {
    public let source: String
    
    public init(source: String) {
        self.source = source
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitImage(self)
    }
}

public class OrgParser {
    public init() {}
    
    public func parse(_ text: String) -> OrgDocument {
        let lines = text.components(separatedBy: .newlines)
        var children: [OrgNode] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Skip empty lines at top level (optional, but cleaner)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }
            
            // Code Block
            if line.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("#+BEGIN_SRC") {
                let parts = line.split(separator: " ", maxSplits: 1)
                let lang = parts.count > 1 ? String(parts[1]) : nil
                
                var contentLines: [String] = []
                i += 1
                while i < lines.count {
                    let nextLine = lines[i]
                    if nextLine.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("#+END_SRC") {
                        break
                    }
                    contentLines.append(nextLine)
                    i += 1
                }
                children.append(CodeBlock(language: lang, content: contentLines.joined(separator: "\n")))
                i += 1
                continue
            }
            
            // Horizontal Rule
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("-----") {
                children.append(HorizontalRule())
                i += 1
                continue
            }
            
            // Heading
            if line.hasPrefix("*") {
                let parts = line.split(separator: " ", maxSplits: 1)
                let stars = parts[0]
                if stars.allSatisfy({ $0 == "*" }) {
                    let level = stars.count
                    let title = parts.count > 1 ? String(parts[1]) : ""
                    children.append(Heading(level: level, text: title))
                    i += 1
                    continue
                }
            }
            
            // List
            if isListLoop(line) {
                var items: [String] = []
                // Detect list type from first line
                // For simplicity, we just group consecutive list items
                // Proper Org mode has strict indentation rules, we'll be loose here.
                while i < lines.count {
                    let l = lines[i]
                    if isListLoop(l) {
                        // Extract content after marker
                        items.append(stripListMarker(l))
                        i += 1
                    } else {
                        break
                    }
                }
                children.append(ListNode(items: items))
                continue
            }
            
            // Paragraph
            children.append(parseParagraph(line))
            i += 1
        }
        
        return OrgDocument(children: children)
    }
    
    private func isListLoop(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("+ ") || (trimmed.first?.isNumber == true && trimmed.contains(". "))
    }
    
    private func stripListMarker(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: " ") {
            return String(trimmed[range.upperBound...])
        }
        return trimmed
    }
    
    private func parseParagraph(_ text: String) -> Paragraph {
        var nodes: [OrgNode] = []
        
        // Split by links and images first
        let linkPattern = "\\[\\[(.*?)(?:\\]\\[(.*?))?\\]\\]"
        
        var remaining = text
        while let range = remaining.range(of: linkPattern, options: .regularExpression) {
            let match = String(remaining[range])
            let prefix = String(remaining[..<range.lowerBound])
            
            if !prefix.isEmpty {
                nodes.append(contentsOf: parseInlineStyles(prefix))
            }
            
            let content = match.dropFirst(2).dropLast(2)
            let parts = content.components(separatedBy: "][")
            let url = parts[0]
            let description = parts.count > 1 ? parts[1] : nil
            
            if url.hasPrefix("file:") && (url.lowercased().hasSuffix(".png") || url.lowercased().hasSuffix(".jpg") || url.lowercased().hasSuffix(".jpeg") || url.lowercased().hasSuffix(".gif")) {
                let path = String(url.dropFirst(5))
                nodes.append(ImageNode(source: path))
            } else {
                nodes.append(LinkNode(url: url, text: description))
            }
            
            remaining = String(remaining[range.upperBound...])
        }
        
        if !remaining.isEmpty {
            nodes.append(contentsOf: parseInlineStyles(remaining))
        }
        
        return Paragraph(children: nodes)
    }
    
    private func parseInlineStyles(_ text: String) -> [OrgNode] {
        // Handle *bold* and /italic/
        // Simple scanner: look for first * or /
        // This is a naive implementation.
        
        var nodes: [OrgNode] = []
        var scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        
        while !scanner.isAtEnd {
            let startIndex = scanner.currentIndex
            
            if let char = scanner.scanCharacter() {
                if char == "*" {
                    // Possible bold
                    if let boldText = scanner.scanUpToString("*") {
                        if scanner.scanString("*") != nil {
                            nodes.append(StrongNode(text: boldText))
                            continue
                        }
                    }
                    // Reset if failed
                    scanner.currentIndex = scanner.string.index(after: startIndex)
                    nodes.append(TextNode(text: String(char)))
                } else if char == "/" {
                    // Possible italic
                    if let italicText = scanner.scanUpToString("/") {
                        if scanner.scanString("/") != nil {
                            nodes.append(EmphasisNode(text: italicText))
                            continue
                        }
                    }
                    // Reset if failed
                    scanner.currentIndex = scanner.string.index(after: startIndex)
                    nodes.append(TextNode(text: String(char)))
                } else {
                     // Accumulate text
                     // Optimization: scan until next special char
                     // But for now, character by character is safe or accumulating
                     nodes.append(TextNode(text: String(char)))
                }
            }
        }
        
        // Merge adjacent TextNodes
        var merged: [OrgNode] = []
        for node in nodes {
            if let textNode = node as? TextNode, let last = merged.last as? TextNode {
                merged[merged.count - 1] = TextNode(text: last.text + textNode.text)
            } else {
                merged.append(node)
            }
        }
        
        return merged
    }
}
