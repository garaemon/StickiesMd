//
//  ContentView.swift
//  StickiesMd
//
//  Created by Ryohei Ueda on 2026/01/21.
//

import SwiftUI
import OrgKit

struct ContentView: View {
    @ObservedObject var viewModel: StickyNoteViewModel
    
    var body: some View {
        VStack {
            Text(viewModel.note.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<viewModel.document.children.count, id: \.self) { index in
                        nodeView(viewModel.document.children[index])
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 200, minHeight: 150)
    }
    
    @ViewBuilder
    func nodeView(_ node: OrgNode) -> some View {
        if let heading = node as? Heading {
            Text(heading.text)
                .font(.system(size: CGFloat(24 - heading.level * 2), weight: .bold))
                .padding(.top, 4)
        } else if let paragraph = node as? Paragraph {
            Text(paragraph.text)
                .font(.body)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    ContentView(viewModel: StickyNoteViewModel(note: StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test.org"))))
}
