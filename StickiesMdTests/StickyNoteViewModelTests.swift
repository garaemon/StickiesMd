import XCTest

@testable import StickiesMd

@MainActor
final class StickyNoteViewModelTests: XCTestCase {
  var note: StickyNote!
  var viewModel: StickyNoteViewModel!
  var tempFileURL: URL!

  override func setUp() {
    super.setUp()
    tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "test_\(UUID().uuidString).md")
    try? "# Test".write(to: tempFileURL, atomically: true, encoding: .utf8)

    note = StickyNote(fileURL: tempFileURL)
    viewModel = StickyNoteViewModel(note: note)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempFileURL)
    super.tearDown()
  }

  func testUpdateFontColor() {
    let expectation = expectation(forNotification: .stickyNoteFontColorChanged, object: nil) {
      notification in
      let updatedNote = notification.object as? StickyNote
      return updatedNote?.fontColor == "#123456"
    }

    viewModel.updateFontColor("#123456")

    XCTAssertEqual(viewModel.note.fontColor, "#123456")
    wait(for: [expectation], timeout: 1.0)
  }

  func testToggleLineNumbers() {
    let initialState = viewModel.note.showLineNumbers

    let expectation = expectation(forNotification: .stickyNoteLineNumbersChanged, object: nil) {
      notification in
      let updatedNote = notification.object as? StickyNote
      return updatedNote?.showLineNumbers == !initialState
    }

    viewModel.toggleLineNumbers()

    XCTAssertEqual(viewModel.note.showLineNumbers, !initialState)
    wait(for: [expectation], timeout: 1.0)
  }
}
