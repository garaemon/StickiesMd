import XCTest

@testable import StickiesMd

@MainActor
final class StickiesStoreTests: XCTestCase {
  var store: StickiesStore!
  var tempDefaults: UserDefaults!
  var tempDir: URL!

  override func setUp() {
    super.setUp()
    tempDefaults = UserDefaults(suiteName: "StickiesStoreTests")
    tempDefaults.removePersistentDomain(forName: "StickiesStoreTests")

    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    store = StickiesStore()
    store.configure(defaults: tempDefaults, storageDirectory: tempDir)
  }

  override func tearDown() {
    tempDefaults.removePersistentDomain(forName: "StickiesStoreTests")
    try? FileManager.default.removeItem(at: tempDir)
    super.tearDown()
  }

  func testAddAndSave() {
    let note = StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test1.md"))
    store.add(note: note)

    XCTAssertEqual(store.notes.count, 1)
    XCTAssertEqual(store.notes.first?.id, note.id)

    // Verify it was saved to defaults
    let newStore = StickiesStore()
    newStore.configure(defaults: tempDefaults, storageDirectory: tempDir)
    XCTAssertEqual(newStore.notes.count, 1)
    XCTAssertEqual(newStore.notes.first?.id, note.id)
  }

  func testUpdate() {
    var note = StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test1.md"))
    store.add(note: note)

    note.fontColor = "#00FF00"
    store.update(note: note)

    XCTAssertEqual(store.notes.first?.fontColor, "#00FF00")

    let newStore = StickiesStore()
    newStore.configure(defaults: tempDefaults, storageDirectory: tempDir)
    XCTAssertEqual(newStore.notes.first?.fontColor, "#00FF00")
  }

  func testRemove() {
    let note = StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test1.md"))
    store.add(note: note)
    XCTAssertEqual(store.notes.count, 1)

    store.remove(note: note)
    XCTAssertEqual(store.notes.count, 0)
  }
}
