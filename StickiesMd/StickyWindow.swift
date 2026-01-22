import AppKit
import SwiftUI

class StickyWindow: NSPanel, NSWindowDelegate {
    var onFrameChange: ((NSRect) -> Void)?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .resizable, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )
        
        self.delegate = self
        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8)
        self.isOpaque = false
        self.hasShadow = true
    }
    
    func windowDidMove(_ notification: Notification) {
        onFrameChange?(self.frame)
    }
    
    func windowDidResize(_ notification: Notification) {
        onFrameChange?(self.frame)
    }
}
