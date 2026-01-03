//
//  WindowBlackoutProvider.swift
//  DisplayCut
//
//  Blackout implementation using fullscreen black NSPanel windows.
//

import AppKit
import Foundation

/// Blacks out displays by creating fullscreen black windows over them.
/// This is the simplest and most reliable method that works on all displays.
@MainActor
final class WindowBlackoutProvider: BlackoutProvider {
    
    /// Shared singleton instance
    static let shared = WindowBlackoutProvider()
    
    /// Maps display identifiers to their blackout windows
    private var blackoutWindows: [DisplayIdentifier: NSPanel] = [:]
    
    private init() {}
    
    // MARK: - BlackoutProvider
    
    func blackout(display: Display) {
        // Don't create duplicate windows
        guard blackoutWindows[display.id] == nil else { return }
        
        // Find the NSScreen for this display
        guard let screen = screen(for: display.cgDisplayID) else {
            print("Could not find screen for display: \(display.localizedName)")
            return
        }
        
        // Create the blackout panel
        let panel = createBlackoutPanel(for: screen)
        blackoutWindows[display.id] = panel
        
        // Show the panel
        panel.orderFrontRegardless()
    }
    
    func restore(display: Display) {
        guard let panel = blackoutWindows.removeValue(forKey: display.id) else { return }
        panel.close()
    }
    
    func restoreAll() {
        for (_, panel) in blackoutWindows {
            panel.close()
        }
        blackoutWindows.removeAll()
    }
    
    func isBlackedOut(display: Display) -> Bool {
        blackoutWindows[display.id] != nil
    }
    
    // MARK: - Private Helpers
    
    /// Finds the NSScreen corresponding to a CGDirectDisplayID
    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               screenNumber == displayID {
                return screen
            }
        }
        return nil
    }
    
    /// Creates a fullscreen black panel for the specified screen
    private func createBlackoutPanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance
        panel.backgroundColor = .black
        panel.isOpaque = true
        panel.hasShadow = false
        
        // Set to screenSaver level to appear above most other windows
        panel.level = .screenSaver
        
        // Allow the panel to span across spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Don't show in window lists
        panel.isExcludedFromWindowsMenu = true
        
        // Position on the correct screen
        panel.setFrame(screen.frame, display: true)
        
        // Prevent the panel from becoming key window
        panel.becomesKeyOnlyIfNeeded = true
        
        // Don't release when closed, we manage the lifecycle
        panel.isReleasedWhenClosed = false
        
        return panel
    }
}

