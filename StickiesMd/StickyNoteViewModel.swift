import AppKit
import Combine
import Foundation

class StickyNoteViewModel: NSObject, ObservableObject, NSFilePresenter {
  @Published var note: StickyNote
  @Published var content: String = "" {
    didSet {
      // Sync content to textStorage if they differ
      if textStorage.string != content {
        textStorage.beginEditing()
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.replaceCharacters(in: range, with: content)
        textStorage.endEditing()
      }
      hasUnsavedChanges = content != lastSavedContent
    }
  }
  @Published var hasUnsavedChanges: Bool = false
  // Version counter to force view refresh when content is loaded from disk
  @Published var version: Int = 0

  let textStorage = NSTextStorage()
  @Published var isFocused: Bool = false

  private var lastSavedContent: String = ""
  private var isAccessingResource = false

  var presentedItemURL: URL? {
    return note.fileURL
  }

  var presentedItemOperationQueue: OperationQueue {
    return .main
  }

  var fileFormat: FileFormat {
    switch note.fileURL.pathExtension.lowercased() {
    case "org":
      return .org
    default:
      return .markdown
    }
  }

  init(note: StickyNote) {
    self.note = note
    super.init()

    isAccessingResource = self.note.fileURL.startAccessingSecurityScopedResource()

    loadContent()
    lastSavedContent = content

    // Ensure textStorage has initial content
    if textStorage.string != content {
      textStorage.replaceCharacters(
        in: NSRange(location: 0, length: textStorage.length), with: content)
    }

    setupTextStorageObserver()
    setupSaveRequestObserver()

    NSFileCoordinator.addFilePresenter(self)
  }

  private func setupTextStorageObserver() {
    NotificationCenter.default.addObserver(
      forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      if self.content != self.textStorage.string {
        self.content = self.textStorage.string
      }
    }
  }

  private func setupSaveRequestObserver() {
    NotificationCenter.default.addObserver(
      forName: .stickyNoteSaveRequested, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self, self.isFocused else { return }
      self.manualSave()
    }
  }

  deinit {
    if isAccessingResource {
      note.fileURL.stopAccessingSecurityScopedResource()
    }
  }

  func saveContent(_ text: String) {
    guard text != lastSavedContent else { return }

    // Prevent recursive reload if we are the one saving
    // NSFileCoordinator(filePresenter: self) handles this if we use it correctly

    let coordinator = NSFileCoordinator(filePresenter: self)
    var error: NSError?

    coordinator.coordinate(writingItemAt: note.fileURL, options: [], error: &error) { url in
      do {
        try text.write(to: url, atomically: true, encoding: .utf8)
        self.lastSavedContent = text
        self.hasUnsavedChanges = false
      } catch {
        print("Failed to save content: \(error)")
      }
    }

    if let error = error {
      print("Coordinator error: \(error)")
    }
  }

  func loadContent() {
    // If we are currently editing (focused) or just saved, maybe we should be careful?
    // But if external change happens, we SHOULD reload.
    // If we just saved, lastSavedContent == content, so ideally we shouldn't overwrite unless file is different.

    // Use coordinator for reading
    let coordinator = NSFileCoordinator(filePresenter: self)
    var error: NSError?

    coordinator.coordinate(readingItemAt: note.fileURL, options: [], error: &error) { url in
      do {
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
          DispatchQueue.main.async {
            // Only update if text is actually different to avoid cursor jumps or loops
            // We check against lastSavedContent to distinguish between our own saves and external changes.
            // If text matches lastSavedContent, it means the file contains what we just saved,
            // so we shouldn't overwrite self.content (which might have newer, unsaved changes).
            if text != self.lastSavedContent {
              self.content = text
              self.lastSavedContent = text
              self.hasUnsavedChanges = false
              self.version += 1
            }
          }
        }
      } catch {
        print("Failed to load content: \(error)")
      }
    }
  }

  func presentedItemDidChange() {
    // This is called when file changes on disk
    loadContent()
  }

  @MainActor
  func updateColor(_ hex: String) {
    note.backgroundColor = hex
    StickiesStore.shared.update(note: note)
    // Update window directly? Or binding?
    // Since StickyWindow is NSPanel, we might need a callback or notification.
    // For now, let's use NotificationCenter or a callback mechanism in StickyWindowManager.
    NotificationCenter.default.post(name: .stickyNoteAppearanceChanged, object: note)
  }

  @MainActor
  func updateOpacity(_ opacity: Double) {
    note.opacity = opacity
    StickiesStore.shared.update(note: note)
    NotificationCenter.default.post(name: .stickyNoteAppearanceChanged, object: note)
  }

  @MainActor
  func updateFontColor(_ hex: String) {
    note.fontColor = hex
    StickiesStore.shared.update(note: note)
    NotificationCenter.default.post(name: .stickyNoteFontColorChanged, object: note)
  }

  @MainActor
  func toggleLineNumbers() {
    note.showLineNumbers.toggle()
    StickiesStore.shared.update(note: note)
    NotificationCenter.default.post(name: .stickyNoteLineNumbersChanged, object: note)
  }

  @MainActor
  func updateFile(_ newURL: URL) {
    NSFileCoordinator.removeFilePresenter(self)
    if isAccessingResource {
      note.fileURL.stopAccessingSecurityScopedResource()
    }

    note.fileURL = newURL
    isAccessingResource = note.fileURL.startAccessingSecurityScopedResource()
    note.updateBookmark()

    loadContent()
    NSFileCoordinator.addFilePresenter(self)
    StickiesStore.shared.update(note: note)
  }

  func setMouseThrough(_ enabled: Bool) {
    NotificationCenter.default.post(
      name: .stickyNoteMouseThrough, object: note, userInfo: ["enabled": enabled])
  }

  func appendImage(from url: URL) {
    // Determine destination path
    let fileDir = note.fileURL.deletingLastPathComponent()
    let fileName = url.lastPathComponent
    let destinationURL = fileDir.appendingPathComponent(fileName)

    // Copy file
    do {
      if !FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.copyItem(at: url, to: destinationURL)
      }
      // If file exists, we might want to rename or skip. For now, assuming unique or overwrite intent (if copied manually before)
      // But copyItem throws if exists.
    } catch {
      print("Failed to copy image: \(error)")
      // Fallback: use original path if possible? No, sandbox issues likely.
      // Just continue to append link, maybe it was already there.
    }

    // Append text
    let linkText = "\n[[file:\(fileName)]]\n"
    append(text: linkText)
  }

  func append(text: String) {
    do {
      let fileHandle = try FileHandle(forWritingTo: note.fileURL)
      fileHandle.seekToEndOfFile()
      if let data = text.data(using: .utf8) {
        fileHandle.write(data)
      }
      fileHandle.closeFile()
      // Reload will happen via NSFilePresenter
    } catch {
      print("Failed to append text: \(error)")
    }
  }

  @MainActor
  func toggleAlwaysOnTop() {
    note.isAlwaysOnTop.toggle()
    StickiesStore.shared.update(note: note)
    NotificationCenter.default.post(name: .stickyNoteAlwaysOnTopChanged, object: note)
  }

  func manualSave() {
    saveContent(content)
  }
}

extension Notification.Name {
  static let stickyNoteAppearanceChanged = Notification.Name("stickyNoteAppearanceChanged")
  static let stickyNoteMouseThrough = Notification.Name("stickyNoteMouseThrough")
  static let stickyNoteAlwaysOnTopChanged = Notification.Name("stickyNoteAlwaysOnTopChanged")
  static let stickyNoteFontColorChanged = Notification.Name("stickyNoteFontColorChanged")
  static let stickyNoteLineNumbersChanged = Notification.Name("stickyNoteLineNumbersChanged")
  static let stickyNoteSaveRequested = Notification.Name("stickyNoteSaveRequested")
}
