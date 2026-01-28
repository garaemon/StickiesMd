import XCTest
@testable import StickiesMd

final class StickyNoteTests: XCTestCase {
    func testInitialization() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let note = StickyNote(fileURL: url)
        
        XCTAssertEqual(note.fileURL, url)
        XCTAssertTrue(StickyNote.palette.contains(note.backgroundColor))
        XCTAssertEqual(note.fontColor, "#000000")
        XCTAssertEqual(note.opacity, 1.0)
        XCTAssertFalse(note.showLineNumbers)
    }
    
    func testEncodingDecoding() throws {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        var note = StickyNote(fileURL: url)
        note.fontColor = "#FF0000"
        note.showLineNumbers = true
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(note)
        
        let decoder = JSONDecoder()
        let decodedNote = try decoder.decode(StickyNote.self, from: data)
        
        XCTAssertEqual(decodedNote.id, note.id)
        XCTAssertEqual(decodedNote.fontColor, "#FF0000")
        XCTAssertEqual(decodedNote.showLineNumbers, true)
    }

    func testDecodingFromLegacyData() throws {
        // Data without fontColor and showLineNumbers
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "fileURL": "file:///tmp/test.md",
            "backgroundColor": "#FFF9C4",
            "opacity": 1.0,
            "frame": [[100, 100], [300, 200]],
            "isAlwaysOnTop": false
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let note = try decoder.decode(StickyNote.self, from: json)
        
        XCTAssertEqual(note.fontColor, "#000000") // Default value
        XCTAssertEqual(note.showLineNumbers, false) // Default value
    }
}
