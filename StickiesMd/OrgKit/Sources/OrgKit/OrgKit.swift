import Foundation

public protocol OrgNode {}

public struct OrgDocument: OrgNode {
    public let children: [OrgNode]
    
    public init(children: [OrgNode]) {
        self.children = children
    }
}

public struct Heading: OrgNode {
    public let level: Int
    public let text: String
    
    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

public struct Paragraph: OrgNode {
    public let text: String
    
    public init(text: String) {
        self.text = text
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
            
            children.append(Paragraph(text: line))
        }
        
        return OrgDocument(children: children)
    }
}