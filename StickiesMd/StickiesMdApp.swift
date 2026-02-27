//
//  StickiesMdApp.swift
//  StickiesMd
//
//  Created by Ryohei Ueda on 2026/01/21.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct StickiesMdApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Sticky") {
          createNewSticky()
        }
        .keyboardShortcut("n")

        Button("Open...") {
          openFile()
        }
        .keyboardShortcut("o")
      }

      CommandGroup(replacing: .saveItem) {
        Button("Save") {
          NotificationCenter.default.post(name: .stickyNoteSaveRequested, object: nil)
        }
        .keyboardShortcut("s")
      }

      CommandGroup(after: .windowSize) {
        Button("Reset Mouse-Through") {
          StickyWindowManager.shared.resetAllMouseThrough()
        }
      }
    }
  }

  func createNewSticky() {
    let fileManager = FileManager.default
    let folder = StickiesStore.shared.storageDirectory
    try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let filename = formatter.string(from: Date()) + ".org"
    let fileURL = folder.appendingPathComponent(filename)

    if !fileManager.fileExists(atPath: fileURL.path) {
      let content = "* New Sticky\n"
      try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    StickyWindowManager.shared.createNewWindow(for: fileURL)
  }

  func openFile() {
    let panel = NSOpenPanel()
    // Define UTTypes safely
    let orgType = UTType(filenameExtension: "org") ?? .text
    let mdType = UTType(filenameExtension: "md") ?? .text

    panel.allowedContentTypes = [orgType, mdType, .text, .plainText]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false

    if panel.runModal() == .OK {
      for url in panel.urls {
        StickyWindowManager.shared.createNewWindow(for: url)
      }
    }
  }
}
