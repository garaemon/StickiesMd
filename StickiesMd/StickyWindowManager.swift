import AppKit
import Combine
import SwiftUI

@MainActor
class StickyWindowManager: NSObject, ObservableObject {
  static let shared = StickyWindowManager()
  private var windows: [UUID: StickyWindow] = [:]
  private var cancellables: Set<AnyCancellable> = []

  override init() {
    super.init()
    NotificationCenter.default.publisher(for: .stickyNoteAppearanceChanged)
      .compactMap { $0.object as? StickyNote }
      .sink { [weak self] note in
        self?.updateWindowAppearance(for: note)
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .stickyNoteMouseThrough)
      .compactMap { notification -> (StickyNote, Bool)? in
        guard let note = notification.object as? StickyNote,
          let enabled = notification.userInfo?["enabled"] as? Bool
        else {
          return nil
        }
        return (note, enabled)
      }
      .sink { [weak self] (note, enabled) in
        self?.windows[note.id]?.setMouseThrough(enabled)
        if !enabled {
          self?.updateWindowAppearance(for: note)
        }
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .stickyNoteAlwaysOnTopChanged)
      .compactMap { $0.object as? StickyNote }
      .sink { [weak self] note in
        self?.windows[note.id]?.setAlwaysOnTop(note.isAlwaysOnTop)
      }
      .store(in: &cancellables)
  }

  func restoreWindows() {
    for note in StickiesStore.shared.notes {
      createWindow(for: note)
    }
  }

  func createNewWindow(for fileURL: URL, persist: Bool = true) {
    let note = StickyNote(fileURL: fileURL)
    if persist {
      StickiesStore.shared.add(note: note)
    }
    createWindow(for: note)
  }

  func updateWindowAppearance(for note: StickyNote) {
    guard let window = windows[note.id] else { return }
    window.setStickyColor(note.backgroundColor)
    window.alphaValue = CGFloat(note.opacity)
    window.setAlwaysOnTop(note.isAlwaysOnTop)
  }

  func resetAllMouseThrough() {
    for window in windows.values {
      window.setMouseThrough(false)
    }
  }

  private func createWindow(for note: StickyNote) {
    let viewModel = StickyNoteViewModel(note: note)

    let window = StickyWindow(
      contentRect: note.frame,
      backing: .buffered,
      defer: false
    )
    window.identifier = NSUserInterfaceItemIdentifier("StickyWindow")
    window.setAccessibilityIdentifier("StickyWindow")
    window.setStickyColor(note.backgroundColor)
    window.alphaValue = CGFloat(note.opacity)
    window.setAlwaysOnTop(note.isAlwaysOnTop)

    window.onFrameChange = { newFrame in
      var updatedNote = note
      updatedNote.frame = newFrame
      StickiesStore.shared.update(note: updatedNote)
    }

    window.onFocusChange = { [weak viewModel] isFocused in
      DispatchQueue.main.async {
        viewModel?.isFocused = isFocused
      }
    }

    window.onClose = { [weak self] in
      StickiesStore.shared.remove(note: note)
      self?.windows.removeValue(forKey: note.id)
    }

    let contentView = ContentView(viewModel: viewModel)
    let hostingView = NSHostingView(rootView: contentView)
    window.contentView = hostingView

    window.makeKeyAndOrderFront(nil)
    windows[note.id] = window
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    if ProcessInfo.processInfo.arguments.contains("--reset-state") {
      // Isolate for testing
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "StickiesMdUITests")
      let testDefaults = UserDefaults(suiteName: "StickiesMdUITests") ?? .standard

      // Clean up previous test run if needed (though reset() does it too)
      testDefaults.removePersistentDomain(forName: "StickiesMdUITests")

      StickiesStore.shared.configure(defaults: testDefaults, storageDirectory: tempDir)
      StickiesStore.shared.reset()
    } else {
      // Normal launch - ensure initial load happens if not already
      StickiesStore.shared.load()
    }

    // Parse command line arguments for files to open
    let args = ProcessInfo.processInfo.arguments
    var filePaths: [String] = []
    if args.count > 1 {
      for arg in args.dropFirst() {
        if !arg.hasPrefix("-") {
          // Check if it's a valid file path to avoid misinterpreting system flags like "YES"
          if FileManager.default.fileExists(atPath: arg) {
            filePaths.append(arg)
          }
        }
      }
    }

    if !filePaths.isEmpty {
      // Open specified files without persisting them as restored windows
      for path in filePaths {
        let url = URL(fileURLWithPath: path)
        StickyWindowManager.shared.createNewWindow(for: url, persist: false)
      }
    } else {
      // Normal restoration flow
      StickyWindowManager.shared.restoreWindows()

      if StickiesStore.shared.notes.isEmpty {
        // Create a sample file for testing only if no notes exist
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let sampleURL = tempDir.appendingPathComponent("sample.org")
        let content =
          "* Welcome to Stickies.md\nThis is a sample org file.\nYou can use *bold* and /italic/ text.\n\n- Item 1\n- Item 2\n"

        try? content.write(to: sampleURL, atomically: true, encoding: .utf8)

        StickyWindowManager.shared.createNewWindow(for: sampleURL)
      }
    }
  }
}
