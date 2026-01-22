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
                Text(viewModel.document.text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 200, minHeight: 150)
    }
}

#Preview {
    ContentView(viewModel: StickyNoteViewModel(note: StickyNote(fileURL: URL(fileURLWithPath: "/tmp/test.org"))))
}
