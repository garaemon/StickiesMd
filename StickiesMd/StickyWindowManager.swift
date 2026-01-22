import SwiftUI
import AppKit
import Combine

class StickyWindowManager: NSObject, ObservableObject {
    static let shared = StickyWindowManager()
    private var windows: [StickyWindow] = []
    
    func createNewWindow() {
        let contentRect = NSRect(x: 100, y: 100, width: 300, height: 200)
        let window = StickyWindow(
            contentRect: contentRect,
            backing: .buffered,
            defer: false
        )
        
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StickyWindowManager.shared.createNewWindow()
    }
}
