import SwiftUI
import AppKit
import Combine

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
            
        NotificationCenter.default.publisher(for: .stickyNoteToggleShade)
            .compactMap { $0.object as? StickyNote }
            .sink { [weak self] note in
                self?.windows[note.id]?.toggleShade()
            }
            .store(in: &cancellables)
    }
    
    func restoreWindows() {
        for note in StickiesStore.shared.notes {
            createWindow(for: note)
        }
    }
    
    func createNewWindow(for fileURL: URL) {
        let note = StickyNote(fileURL: fileURL)
        StickiesStore.shared.add(note: note)
        createWindow(for: note)
    }
    
    func updateWindowAppearance(for note: StickyNote) {
        guard let window = windows[note.id] else { return }
        window.setStickyColor(note.backgroundColor)
        window.alphaValue = CGFloat(note.opacity)
    }
    
    private func createWindow(for note: StickyNote) {
        let viewModel = StickyNoteViewModel(note: note)
        
        let window = StickyWindow(
            contentRect: note.frame,
            backing: .buffered,
            defer: false
        )
        window.setStickyColor(note.backgroundColor)
        window.alphaValue = CGFloat(note.opacity)
        
        window.onFrameChange = { newFrame in
            var updatedNote = note
            updatedNote.frame = newFrame
            StickiesStore.shared.update(note: updatedNote)
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
        StickyWindowManager.shared.restoreWindows()
        
        if StickiesStore.shared.notes.isEmpty {
            // Create a sample file for testing only if no notes exist
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let sampleURL = tempDir.appendingPathComponent("sample.org")
            let content = "* Welcome to Stickies.md\nThis is a sample org file."
            
            try? content.write(to: sampleURL, atomically: true, encoding: .utf8)
            
            StickyWindowManager.shared.createNewWindow(for: sampleURL)
        }
    }
}
