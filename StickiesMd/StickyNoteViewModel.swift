import Foundation
import Combine
import OrgKit

class StickyNoteViewModel: NSObject, ObservableObject, NSFilePresenter {
    @Published var note: StickyNote
    @Published var content: String = ""
    @Published var document: OrgDocument = OrgDocument(children: [])
    
    var presentedItemURL: URL? {
        return note.fileURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    init(note: StickyNote) {
        self.note = note
        super.init()
        loadContent()
        NSFileCoordinator.addFilePresenter(self)
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    func loadContent() {
        do {
            let data = try Data(contentsOf: note.fileURL)
            if let text = String(data: data, encoding: .utf8) {
                self.content = text
                self.document = OrgParser().parse(text)
            }
        } catch {
            print("Failed to load content: \(error)")
        }
    }
    
    func presentedItemDidChange() {
        loadContent()
    }
    
    func updateColor(_ hex: String) {
        note.backgroundColor = hex
        StickiesStore.shared.update(note: note)
        // Update window directly? Or binding?
        // Since StickyWindow is NSPanel, we might need a callback or notification.
        // For now, let's use NotificationCenter or a callback mechanism in StickyWindowManager.
        NotificationCenter.default.post(name: .stickyNoteAppearanceChanged, object: note)
    }
    
    func updateOpacity(_ opacity: Double) {
        note.opacity = opacity
        StickiesStore.shared.update(note: note)
        NotificationCenter.default.post(name: .stickyNoteAppearanceChanged, object: note)
    }
    
    func toggleShade() {
        NotificationCenter.default.post(name: .stickyNoteToggleShade, object: note)
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
}

extension Notification.Name {
    static let stickyNoteAppearanceChanged = Notification.Name("stickyNoteAppearanceChanged")
    static let stickyNoteToggleShade = Notification.Name("stickyNoteToggleShade")
}
