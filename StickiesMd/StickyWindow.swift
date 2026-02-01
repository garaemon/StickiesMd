import AppKit
import SwiftUI

class StickyWindow: NSPanel, NSWindowDelegate {
  var onFrameChange: ((NSRect) -> Void)?
  var onFocusChange: ((Bool) -> Void)?
  var onClose: (() -> Void)?

  private var isAlwaysOnTop: Bool = false

  init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
    super.init(
      contentRect: contentRect,
      styleMask: [.titled, .resizable, .closable, .fullSizeContentView, .nonactivatingPanel],
      backing: backing,
      defer: flag
    )

    self.delegate = self
    self.isFloatingPanel = true
    self.level = .normal
    self.isMovableByWindowBackground = true
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isOpaque = false
    self.hasShadow = true

    // Add a toolbar to increase the titlebar height and better align traffic lights
    let toolbar = NSToolbar()
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar
    self.toolbarStyle = .unified
  }

  func windowWillClose(_ notification: Notification) {
    onClose?()
  }

  func windowDidBecomeKey(_ notification: Notification) {
    onFocusChange?(true)
  }

  func windowDidResignKey(_ notification: Notification) {
    onFocusChange?(false)
  }

  func setStickyColor(_ hex: String) {
    if let color = NSColor(hex: hex) {
      self.backgroundColor = color
    }
  }

  func setAlwaysOnTop(_ enabled: Bool) {
    isAlwaysOnTop = enabled
    updateLevel()
  }

  private func updateLevel() {
    if ignoresMouseEvents {
      self.level = .floating
    } else {
      self.level = isAlwaysOnTop ? .floating : .normal
    }
  }

  // Phase 4: Window Shading & Mouse-through

  override func cancelOperation(_ sender: Any?) {
    // Do nothing to prevent closing window on Esc
  }

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
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
      self.alphaValue = 0.5  // Visual cue
    } else {
      // Alpha will be restored by WindowManager
    }
    updateLevel()
  }

  func windowDidMove(_ notification: Notification) {
    onFrameChange?(self.frame)
  }

  func windowDidResize(_ notification: Notification) {
    onFrameChange?(self.frame)
  }
}
