import Foundation

public struct OrgDocument {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

public class OrgParser {
    public init() {}
    
    public func parse(_ text: String) -> OrgDocument {
        // 将来的にここに移植ロジックを書く
        return OrgDocument(text: text)
    }
}
