import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: StickyNoteViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
            
            // Color Palette
            VStack(alignment: .leading) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                    ForEach(StickyNote.palette, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: colorHex) ?? .white))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black.opacity(0.5))
                                    .opacity(viewModel.note.backgroundColor == colorHex ? 1 : 0)
                            )
                            .onTapGesture {
                                viewModel.updateColor(colorHex)
                            }
                    }
                }
            }
            
            // Opacity
            VStack(alignment: .leading) {
                Text("Opacity: \(Int(viewModel.note.opacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { viewModel.note.opacity },
                    set: { viewModel.updateOpacity($0) }
                ), in: 0.1...1.0)
            }
            
            // File
            VStack(alignment: .leading) {
                Text("File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: "doc.text")
                    Text(viewModel.note.fileURL.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                
                Button("Open Another File...") {
                    let panel = NSOpenPanel()
                    let orgType = UTType(filenameExtension: "org") ?? .text
                    let mdType = UTType(filenameExtension: "md") ?? .text
                    panel.allowedContentTypes = [orgType, mdType, .text, .plainText]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            viewModel.updateFile(url)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .light)
    }
}
