import SwiftUI
import AppKit
import Combine

class StickyWindowManager: NSObject, ObservableObject {
    static let shared = StickyWindowManager()
    private var windows: [UUID: StickyWindow] = [:]
    
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
    
    private func createWindow(for note: StickyNote) {
        let viewModel = StickyNoteViewModel(note: note)
        
        let window = StickyWindow(
            contentRect: note.frame,
            backing: .buffered,
            defer: false
        )
        
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
