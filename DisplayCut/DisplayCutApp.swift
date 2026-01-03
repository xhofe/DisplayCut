//
//  DisplayCutApp.swift
//  DisplayCut
//
//  Main application entry point with MenuBarExtra.
//

import SwiftUI

@main
struct DisplayCutApp: App {
    /// The display manager instance, shared across the app
    @StateObject private var displayManager = DisplayManager()
    
    var body: some Scene {
        // Menu bar extra - the only UI entry point
        MenuBarExtra {
            MenuBarView(displayManager: displayManager)
                .frame(width: 280)
        } label: {
            // Menu bar icon
            Image(systemName: "display")
        }
        .menuBarExtraStyle(.window)
    }
}
