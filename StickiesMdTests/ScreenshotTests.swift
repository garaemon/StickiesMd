import XCTest
import AppKit
@testable import StickiesMd

@MainActor
final class ScreenshotTests: XCTestCase {
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Configure StickiesStore to use temporary directory
        let suiteName = "ScreenshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        StickiesStore.shared.configure(defaults: defaults, storageDirectory: tempDir)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testTakeScreenshot() {
        let expectation = self.expectation(description: "Screenshot taken")
        
        // Create a dummy file
        let fileURL = tempDir.appendingPathComponent("test.md")
        let content = "# Test Sticky\nThis is a test note."
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Create window
        guard let window = StickyWindowManager.shared.createNewWindow(for: fileURL, persist: false) else {
            XCTFail("Failed to create window")
            return
        }
        
        // Ensure window has a frame
        window.setFrame(NSRect(x: 0, y: 0, width: 400, height: 300), display: true)
        
        let outputURL = tempDir.appendingPathComponent("screenshot.png")
        
        // Wait a bit for SwiftUI to render (same as in AppDelegate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            StickyWindowManager.shared.takeScreenshot(for: window, to: outputURL) { result in
                switch result {
                case .success:
                    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
                    
                    // Verify thumbnail is actually a PNG and has some data
                    if let image = NSImage(contentsOf: outputURL) {
                        XCTAssertEqual(image.size.width, 400)
                        XCTAssertEqual(image.size.height, 300)
                    } else {
                        XCTFail("Failed to load generated screenshot as NSImage")
                    }
                case .failure(let error):
                    XCTFail("Screenshot failed with error: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
