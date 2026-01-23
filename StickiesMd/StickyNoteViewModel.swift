import Foundation
import Combine
import OrgKit

class StickyNoteViewModel: NSObject, ObservableObject, NSFilePresenter {
    @Published var note: StickyNote
    @Published var content: String = ""
    @Published var document: OrgDocument = OrgDocument(children: [])
    @Published var isFocused: Bool = false
    
    private var cancellables: Set<AnyCancellable> = []
    private var lastSavedContent: String = ""
    private var isAccessingResource = false
    
    var presentedItemURL: URL? {
        return note.fileURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    var fileFormat: FileFormat {
        if note.fileURL.pathExtension.lowercased() == "md" {
            return .markdown
        }
        return .org
    }
    
    init(note: StickyNote) {
        self.note = note
        super.init()
        
        isAccessingResource = self.note.fileURL.startAccessingSecurityScopedResource()
        
        loadContent()
        lastSavedContent = content
        NSFileCoordinator.addFilePresenter(self)
        
        setupAutoSave()
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
        if isAccessingResource {
            note.fileURL.stopAccessingSecurityScopedResource()
        }
    }
    
    private func setupAutoSave() {
        $content
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newContent in
                self?.saveContent(newContent)
            }
            .store(in: &cancellables)
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
                // Also update the document model for rendering
                DispatchQueue.main.async {
                    self.document = OrgParser().parse(text, format: self.fileFormat)
                }
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
                        if text != self.content {
                            self.content = text
                            self.lastSavedContent = text
                            self.document = OrgParser().parse(text, format: self.fileFormat)
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
    
    func toggleShade() {
        NotificationCenter.default.post(name: .stickyNoteToggleShade, object: note)
    }
    
    func setMouseThrough(_ enabled: Bool) {
        NotificationCenter.default.post(name: .stickyNoteMouseThrough, object: note, userInfo: ["enabled": enabled])
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
    static let stickyNoteToggleShade = Notification.Name("stickyNoteToggleShade")
    static let stickyNoteMouseThrough = Notification.Name("stickyNoteMouseThrough")
    static let stickyNoteAlwaysOnTopChanged = Notification.Name("stickyNoteAlwaysOnTopChanged")
}
