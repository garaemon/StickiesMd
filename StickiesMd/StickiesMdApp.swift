//
//  StickiesMdApp.swift
//  StickiesMd
//
//  Created by Ryohei Ueda on 2026/01/21.
//

import SwiftUI

@main
struct StickiesMdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
