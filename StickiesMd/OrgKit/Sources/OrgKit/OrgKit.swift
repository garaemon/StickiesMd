import Foundation

public protocol OrgNode {
    func accept<V: OrgVisitor>(_ visitor: V)
}

public protocol OrgVisitor: AnyObject {
    func visit(_ node: OrgNode)
    func visitDocument(_ node: OrgDocument)
    func visitHeading(_ node: Heading)
    func visitParagraph(_ node: Paragraph)
    func visitText(_ node: TextNode)
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

public struct TextNode: OrgNode {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func accept<V: OrgVisitor>(_ visitor: V) {
        visitor.visitText(self)
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
        
        for line in lines {
            if line.isEmpty { continue }
            
            if line.hasPrefix("*") {
                let parts = line.split(separator: " ", maxSplits: 1)
                let stars = parts[0]
                if stars.allSatisfy({ $0 == "*" }) {
                    let level = stars.count
                    let title = parts.count > 1 ? String(parts[1]) : ""
                    children.append(Heading(level: level, text: title))
                    continue
                }
            }
            
            children.append(parseParagraph(line))
        }
        
        return OrgDocument(children: children)
    }
    
    private func parseParagraph(_ text: String) -> Paragraph {
        var nodes: [OrgNode] = []
        var remaining = text
        
        // Simple regex for links: [[url][desc]] or [[url]]
        // And images: [[file:path.png]]
        // Regex pattern: \[ \[ (.*?) (?: \] \[ (.*?) )? \] \]
        // Escaped for Swift String: "\\[\\[(.*?)(?:\\]\\[(.*?))?\\]\\]"
        let linkPattern = "\\[\\[(.*?)(?:\\]\\[(.*?))?\\]\\]"
        
        while let range = remaining.range(of: linkPattern, options: .regularExpression) {
            let match = String(remaining[range])
            let prefix = String(remaining[..<range.lowerBound])
            
            if !prefix.isEmpty {
                nodes.append(TextNode(text: prefix))
            }
            
            // Analyze match
            // Remove [[ and ]]
            let content = match.dropFirst(2).dropLast(2)
            // Split by ][
            let parts = content.components(separatedBy: "][")
            let url = parts[0]
            let description = parts.count > 1 ? parts[1] : nil
            
            if url.hasPrefix("file:") && (url.lowercased().hasSuffix(".png") || url.lowercased().hasSuffix(".jpg") || url.lowercased().hasSuffix(".jpeg") || url.lowercased().hasSuffix(".gif")) {
                let path = String(url.dropFirst(5)) // remove file:
                nodes.append(ImageNode(source: path))
            } else {
                nodes.append(LinkNode(url: url, text: description))
            }
            
            remaining = String(remaining[range.upperBound...])
        }
        
        if !remaining.isEmpty {
            nodes.append(TextNode(text: remaining))
        }
        
        return Paragraph(children: nodes)
    }
}
