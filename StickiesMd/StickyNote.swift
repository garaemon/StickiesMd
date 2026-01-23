import Foundation
import SwiftUI

struct StickyNote: Identifiable, Codable {
    var id: UUID = UUID()
    var fileURL: URL
    var backgroundColor: String // Hex string
    var opacity: Double
    var frame: NSRect
    
    enum CodingKeys: String, CodingKey {
        case id, fileURL, backgroundColor, opacity, frame
    }
}

extension StickyNote {
    static let palette = [
        "#FFF9C4", // Yellow
        "#E1F5FE", // Blue
        "#F1F8E9", // Green
        "#FCE4EC", // Pink
        "#F3E5F5", // Purple
        "#F5F5F5"  // Gray
    ]
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.backgroundColor = Self.palette.randomElement() ?? "#FFF9C4"
        self.opacity = 1.0
        self.frame = NSRect(x: 100, y: 100, width: 300, height: 200)
    }
}
