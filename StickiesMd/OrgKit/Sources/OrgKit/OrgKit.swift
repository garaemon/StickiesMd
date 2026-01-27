import Foundation
@_exported import CodeEditSourceEditor
@_exported import CodeEditLanguages

public protocol OrgNode {
    var range: NSRange { get }
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
    public let range: NSRange
    
    public init(children: [OrgNode], range: NSRange = NSRange(location: 0, length: 0)) {
        self.children = children
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitDocument(self)
    }
}

public struct Heading: OrgNode {
    public let level: Int
    public let text: String
    public let range: NSRange
    
    public init(level: Int, text: String, range: NSRange) {
        self.level = level
        self.text = text
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitHeading(self)
    }
}

public struct Paragraph: OrgNode {
    public let children: [OrgNode]
    public let range: NSRange
    
    // For backward compatibility (tests)
    public var text: String {
        return children.compactMap { ($0 as? TextNode)?.text }.joined()
    }
    
    public init(children: [OrgNode], range: NSRange) {
        self.children = children
        self.range = range
    }
    
    public init(text: String, range: NSRange = NSRange(location: 0, length: 0)) {
        self.children = [TextNode(text: text, range: range)]
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitParagraph(self)
    }
}

public struct ListNode: OrgNode {
    public let items: [String]
    public let ordered: Bool
    public let range: NSRange
    
    public init(items: [String], ordered: Bool = false, range: NSRange) {
        self.items = items
        self.ordered = ordered
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitList(self)
    }
}

public struct CodeBlock: OrgNode {
    public let language: String?
    public let content: String
    public let range: NSRange
    
    public init(language: String?, content: String, range: NSRange) {
        self.language = language
        self.content = content
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitCodeBlock(self)
    }
}

public struct HorizontalRule: OrgNode {
    public let range: NSRange
    public init(range: NSRange) {
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitHorizontalRule(self)
    }
}

public struct TextNode: OrgNode {
    public let text: String
    public let range: NSRange
    
    public init(text: String, range: NSRange) {
        self.text = text
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitText(self)
    }
}

public struct StrongNode: OrgNode {
    public let text: String
    public let range: NSRange
    
    public init(text: String, range: NSRange) {
        self.text = text
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitStrong(self)
    }
}

public struct EmphasisNode: OrgNode {
    public let text: String
    public let range: NSRange
    
    public init(text: String, range: NSRange) {
        self.text = text
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitEmphasis(self)
    }
}

public struct LinkNode: OrgNode {
    public let url: String
    public let text: String?
    public let range: NSRange
    
    public init(url: String, text: String?, range: NSRange) {
        self.url = url
        self.text = text
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitLink(self)
    }
}

public struct ImageNode: OrgNode {
    public let source: String
    public let range: NSRange
    
    public init(source: String, range: NSRange) {
        self.source = source
        self.range = range
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitImage(self)
    }
}

public enum FileFormat {
    case org
    case markdown
}

public class OrgParser {
    public init() {}
    
    public func parse(_ text: String, format: FileFormat = .org) -> OrgDocument {
        let nsText = text as NSString
        var children: [OrgNode] = []
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        
        while lineStart < nsText.length {
            nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))
            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = nsText.substring(with: lineRange)
            // let fullLineRange = NSRange(location: lineStart, length: lineEnd - lineStart) // Unused
            
            // Skip empty lines (preserve in range if needed, but for AST usually skipped or spacer)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lineStart = lineEnd
                continue
            }
            
            // Code Block
            // Org: #+BEGIN_SRC
            // Md: ```
            var isCodeBlock = false
            var lang: String? = nil
            var isOrgSrc = false
            
            if format == .org && line.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("#+BEGIN_SRC") {
                isCodeBlock = true
                isOrgSrc = true
                let parts = line.split(separator: " ", maxSplits: 1)
                lang = parts.count > 1 ? String(parts[1]) : nil
            } else if format == .markdown && line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                isCodeBlock = true
                isOrgSrc = false
                lang = line.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
                if lang?.isEmpty == true { lang = nil }
            }
            
            if isCodeBlock {
                var contentLines: [String] = []
                var currentBlockOffset = lineEnd
                var blockEnd = lineEnd
                
                while currentBlockOffset < nsText.length {
                    var lStart = 0, lEnd = 0, lCont = 0
                    nsText.getLineStart(&lStart, end: &lEnd, contentsEnd: &lCont, for: NSRange(location: currentBlockOffset, length: 0))
                    let lRange = NSRange(location: lStart, length: lCont - lStart)
                    let lText = nsText.substring(with: lRange)
                    
                    if isOrgSrc && lText.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("#+END_SRC") {
                        blockEnd = lEnd
                        break
                    } else if !isOrgSrc && lText.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        blockEnd = lEnd
                        break
                    }
                    
                    contentLines.append(lText)
                    currentBlockOffset = lEnd
                    blockEnd = lEnd
                }
                
                let totalRange = NSRange(location: lineStart, length: blockEnd - lineStart)
                children.append(CodeBlock(language: lang, content: contentLines.joined(separator: "\n"), range: totalRange))
                lineStart = blockEnd
                continue
            }
            
            // Horizontal Rule
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("-----") || (format == .markdown && line.trimmingCharacters(in: .whitespaces).hasPrefix("***")) {
                children.append(HorizontalRule(range: lineRange))
                lineStart = lineEnd
                continue
            }
            
            // Heading
            // Org: *
            // Md: #
            if (format == .org && line.hasPrefix("*")) || (format == .markdown && line.trimmingCharacters(in: .whitespaces).hasPrefix("#")) {
                if format == .org {
                    let parts = line.split(separator: " ", maxSplits: 1)
                    let stars = parts[0]
                    if stars.allSatisfy({ $0 == "*" }) {
                        let level = stars.count
                        let title = parts.count > 1 ? String(parts[1]) : ""
                        children.append(Heading(level: level, text: title, range: lineRange))
                        lineStart = lineEnd
                        continue
                    }
                } else {
                    // Markdown
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("#") {
                        let parts = trimmed.split(separator: " ", maxSplits: 1)
                        let hashes = parts[0]
                        if hashes.allSatisfy({ $0 == "#" }) {
                            let level = hashes.count
                            let title = parts.count > 1 ? String(parts[1]) : ""
                            children.append(Heading(level: level, text: title, range: lineRange))
                            lineStart = lineEnd
                            continue
                        }
                    }
                }
            }
            
            // List
            if isListLoop(line, format: format) {
                var items: [String] = []
                let listStart = lineStart
                var listEnd = lineEnd
                
                // First item
                items.append(stripListMarker(line, format: format))
                
                var currentListOffset = lineEnd
                
                while currentListOffset < nsText.length {
                    var lStart = 0, lEnd = 0, lCont = 0
                    nsText.getLineStart(&lStart, end: &lEnd, contentsEnd: &lCont, for: NSRange(location: currentListOffset, length: 0))
                    let lRange = NSRange(location: lStart, length: lCont - lStart)
                    let lText = nsText.substring(with: lRange)
                    
                    if isListLoop(lText, format: format) {
                        items.append(stripListMarker(lText, format: format))
                        currentListOffset = lEnd
                        listEnd = lEnd
                    } else {
                        break
                    }
                }
                children.append(ListNode(items: items, range: NSRange(location: listStart, length: listEnd - listStart)))
                lineStart = listEnd
                continue
            }
            
            // Paragraph
            children.append(parseParagraph(line, offset: lineStart))
            lineStart = lineEnd
        }
        
        return OrgDocument(children: children, range: NSRange(location: 0, length: nsText.length))
    }
    
    private func isListLoop(_ line: String, format: FileFormat) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if format == .org {
            return trimmed.hasPrefix("- ") || trimmed.hasPrefix("+ ") || (trimmed.first?.isNumber == true && trimmed.contains(". "))
        } else {
            return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || (trimmed.first?.isNumber == true && trimmed.contains(". "))
        }
    }
    
    private func stripListMarker(_ line: String, format: FileFormat) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: " ") {
            return String(trimmed[range.upperBound...])
        }
        return trimmed
    }
    
    private func parseParagraph(_ text: String, offset: Int) -> Paragraph {
        var nodes: [OrgNode] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        // Naive inline parsing with regex for links
        // We will process links first, then text/inline styles in between
        
        // Org Link: [[url][desc]]
        // Md Link: [desc](url)
        // Image: file:*.png inside link
        
        // For simplicity, let's just support Org links for now, or basic MD links?
        // Implementing full inline parser with ranges is complex.
        // Let's stick to Org links for consistency with existing code, 
        // OR add MD links `\[(.*?)\]\((.*?)\)`
        
        let linkPattern = "\\[\\[(.*?)(?:\\]\\[(.*?))?\\]\\]" // Org
        // TODO: Add Markdown link support later or now?
        // Let's do Org links + basic styles for now to ensure we don't break everything.
        
        let regex = try? NSRegularExpression(pattern: linkPattern)
        var lastIndex = 0
        
        regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, stop in
            guard let match = match else { return }
            
            // Text before match
            if match.range.location > lastIndex {
                let range = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let subText = nsText.substring(with: range)
                nodes.append(contentsOf: parseInlineStyles(subText, offset: offset + range.location))
            }
            
            // The match itself
            if match.numberOfRanges > 1 {
                let urlRange = match.range(at: 1)
                let url = nsText.substring(with: urlRange)
                var desc: String? = nil
                if match.numberOfRanges > 2 {
                    let descRange = match.range(at: 2)
                    if descRange.location != NSNotFound {
                        desc = nsText.substring(with: descRange)
                    }
                }
                
                let globalRange = NSRange(location: offset + match.range.location, length: match.range.length)
                
                if url.hasPrefix("file:") && (url.lowercased().hasSuffix(".png") || url.lowercased().hasSuffix(".jpg") || url.lowercased().hasSuffix(".jpeg") || url.lowercased().hasSuffix(".gif")) {
                    let path = String(url.dropFirst(5))
                    nodes.append(ImageNode(source: path, range: globalRange))
                } else {
                    nodes.append(LinkNode(url: url, text: desc, range: globalRange))
                }
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Remaining text
        if lastIndex < nsText.length {
            let range = NSRange(location: lastIndex, length: nsText.length - lastIndex)
            let subText = nsText.substring(with: range)
            nodes.append(contentsOf: parseInlineStyles(subText, offset: offset + range.location))
        }
        
        return Paragraph(children: nodes, range: NSRange(location: offset, length: nsText.length))
    }
    
    private func parseInlineStyles(_ text: String, offset: Int) -> [OrgNode] {
        var nodes: [OrgNode] = []
        let nsText = text as NSString
        
        // *bold* or /italic/
        // Simple regex: (\*([^\*]+)\*)|(/([^/]+)/)
        let pattern = "(\\*([^\\*]+)\\*)|(/([^/]+)/)"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        var lastIndex = 0
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            
            // Text before match
            if match.range.location > lastIndex {
                let range = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let subText = nsText.substring(with: range)
                nodes.append(TextNode(text: subText, range: NSRange(location: offset + range.location, length: range.length)))
            }
            
            let globalRange = NSRange(location: offset + match.range.location, length: match.range.length)
            
            // Group 1: *bold*
            if match.range(at: 1).location != NSNotFound {
                let contentRange = match.range(at: 2)
                let content = nsText.substring(with: contentRange)
                nodes.append(StrongNode(text: content, range: globalRange))
            } 
            // Group 3: /italic/
            else if match.range(at: 3).location != NSNotFound {
                let contentRange = match.range(at: 4)
                let content = nsText.substring(with: contentRange)
                nodes.append(EmphasisNode(text: content, range: globalRange))
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Remaining text
        if lastIndex < nsText.length {
            let range = NSRange(location: lastIndex, length: nsText.length - lastIndex)
            let subText = nsText.substring(with: range)
            nodes.append(TextNode(text: subText, range: NSRange(location: offset + range.location, length: range.length)))
        }
        
        return nodes
    }
}

