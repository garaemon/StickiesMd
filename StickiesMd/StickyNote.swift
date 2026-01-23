import Foundation
import SwiftUI

struct StickyNote: Identifiable, Codable {
    var id: UUID = UUID()
    var fileURL: URL
    var backgroundColor: String // Hex string
    var opacity: Double
    var frame: NSRect
    var bookmarkData: Data?
    var isAlwaysOnTop: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, fileURL, backgroundColor, opacity, frame, bookmarkData, isAlwaysOnTop
    }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.backgroundColor = Self.palette.randomElement() ?? "#FFF9C4"
        self.opacity = 1.0
        self.frame = NSRect(x: 100, y: 100, width: 300, height: 200)
        self.isAlwaysOnTop = false
        updateBookmark()
    }
    
    mutating func updateBookmark() {
        do {
            // Check if file exists to avoid error spam (though creating new note ensures it exists)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                self.bookmarkData = try fileURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
        } catch {
            print("Failed to create bookmark for \(fileURL): \(error)")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        opacity = try container.decode(Double.self, forKey: .opacity)
        frame = try container.decode(NSRect.self, forKey: .frame)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        isAlwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .isAlwaysOnTop) ?? false
        
        let storedURL = try container.decode(URL.self, forKey: .fileURL)
        
        if let data = bookmarkData {
            var isStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: data,
                                          options: .withSecurityScope,
                                          relativeTo: nil,
                                          bookmarkDataIsStale: &isStale)
                self.fileURL = resolvedURL
                if isStale {
                    print("Bookmark is stale for \(resolvedURL)")
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
                self.fileURL = storedURL
            }
        } else {
            self.fileURL = storedURL
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileURL, forKey: .fileURL)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(frame, forKey: .frame)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(isAlwaysOnTop, forKey: .isAlwaysOnTop)
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
}
