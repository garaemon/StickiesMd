//
//  ContentView.swift
//  StickiesMd
//
//  Created by Ryohei Ueda on 2026/01/21.
//

import SwiftUI
import OrgKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: StickyNoteViewModel
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.note.fileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    viewModel.manualSave()
                }) {
                    Image(systemName: "opticaldisc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Save content")
                .padding(.trailing, 4)
                
                Button(action: {
                    viewModel.toggleAlwaysOnTop()
                }) {
                    Image(systemName: viewModel.note.isAlwaysOnTop ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundColor(viewModel.note.isAlwaysOnTop ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Always on Top")
                .padding(.trailing, 4)
                
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
                }
            }
            .padding(.leading, 80) // Space for traffic lights
            .padding(.trailing, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
            
            // Divider() removed for integrated look
            
            Group {
                if viewModel.isFocused {
                    RichTextEditor(text: $viewModel.content, format: viewModel.fileFormat)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(4)
                } else {
                    ScrollView {
                        let renderer = OrgViewRenderer(baseURL: viewModel.note.fileURL)
                        renderer.render(viewModel.document)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
        }
        .environment(\.colorScheme, .light)
        .frame(minWidth: 200, minHeight: 150)
        .onDrop(of: [.image], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                guard let url = url else { return }
                // loadFileRepresentation gives a tmp url that might disappear.
                // Move logic needs to happen carefully.
                // We should copy it immediately.
                
                // Jump to main thread for ViewModel ops
                DispatchQueue.main.async {
                    // Create a temp copy because 'url' is only valid inside this block
                    let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempCopy)
                    try? FileManager.default.copyItem(at: url, to: tempCopy)
                    
                    viewModel.appendImage(from: tempCopy)
                }
            }
            return true
        }
        .contextMenu {
            Menu("Color") {
                ForEach(StickyNote.palette, id: \.self) { colorHex in
                    Button {
                        viewModel.updateColor(colorHex)
                    } label: {
                        HStack {
                            if let nsColor = NSColor(hex: colorHex) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(Color(nsColor))
                            }
                            Text(colorHex) // Or usage name
                        }
                    }
                }
            }
            
            Menu("Opacity") {
                Button("100%") { viewModel.updateOpacity(1.0) }
                Button("80%") { viewModel.updateOpacity(0.8) }
                Button("60%") { viewModel.updateOpacity(0.6) }
                Button("40%") { viewModel.updateOpacity(0.4) }
            }
            
            Button("Collapse/Expand") {
                viewModel.toggleShade()
            }
            
            Button("Enable Mouse-Through") {
                viewModel.setMouseThrough(true)
            }
            
            Divider()
            
            Button("Close") {
                // Find window and close?
                // Or just delete note?
                // Typically close window means close logic.
                // For now, let's just implement close via window button or cmd+w.
                // But this context menu is useful.
                // We need a way to close the specific window from here if needed.
                // Assuming standard window controls exist or keyboard shortcuts.
            }
        }
    }
}

#Preview {
    ContentView(viewModel: StickyNoteViewModel(note: StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test.org"))))
}
