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
        self.isOpaque = false
        self.hasShadow = true
    }
    
    func setStickyColor(_ hex: String) {
        if let color = NSColor(hex: hex) {
            self.backgroundColor = color.withAlphaComponent(0.8)
        }
    }
    
    // Phase 4: Window Shading & Mouse-through
    
    private var originalFrame: NSRect?
    private var isShaded: Bool = false
    
    func toggleShade() {
        if isShaded {
            // Unshade
            if let original = originalFrame {
                self.setFrame(original, display: true, animate: true)
                originalFrame = nil
            }
            isShaded = false
        } else {
            // Shade
            originalFrame = self.frame
            var newFrame = self.frame
            newFrame.size.height = 22 // Small height
            // Adjust origin y to keep top position
            newFrame.origin.y = self.frame.maxY - 22
            self.setFrame(newFrame, display: true, animate: true)
            isShaded = true
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            toggleShade()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    func setMouseThrough(_ enabled: Bool) {
        self.ignoresMouseEvents = enabled
        // If enabled, user cannot click context menu anymore to disable it.
        // We need a global hotkey or mechanism.
        // For this prototype, we accept this limitation or assume App menu can restore it if we had one.
        // Or, maybe hold a modifier key to interact?
        // NSWindow has no simple "pass through unless modifier pressed".
        // A common trick is to monitor events globally or toggle transparent to clicks.
        
        if enabled {
            self.level = .floating
            self.alphaValue = 0.5 // Visual cue
        } else {
            self.level = .floating
            self.alphaValue = 0.8
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        onFrameChange?(self.frame)
    }
    
    func windowDidResize(_ notification: Notification) {
        onFrameChange?(self.frame)
    }
}
