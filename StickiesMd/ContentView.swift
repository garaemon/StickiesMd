//
//  ContentView.swift
//  StickiesMd
//
//  Created by Ryohei Ueda on 2026/01/21.
//

import SwiftUI
import OrgKit

struct ContentView: View {
    let doc = OrgParser().parse("* Hello Org Mode")
    
    var body: some View {
        VStack {
            Text("Stickies.md")
                .font(.caption)
            Divider()
            Text(doc.text)
                .padding()
        }
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
}
