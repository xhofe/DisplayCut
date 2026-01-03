//
//  DisplayManager.swift
//  DisplayCut
//
//  Central manager for display enumeration, state management, and blackout logic.
//

import Foundation
import CoreGraphics
import AppKit
import Combine

/// Manages display enumeration, blackout state, and auto-blackout logic.
@MainActor
final class DisplayManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All currently connected displays
    @Published private(set) var displays: [Display] = []
    
    /// Whether auto-blackout for built-in display is enabled
    @Published var autoBlackoutBuiltin: Bool {
        didSet {
            settingsManager.settings.autoBlackoutBuiltin = autoBlackoutBuiltin
            handleAutoBlackoutChange()
        }
    }
    
    /// Current blackout mode
    @Published var blackoutMode: BlackoutMode {
        didSet {
            if oldValue != blackoutMode {
                settingsManager.settings.blackoutMode = blackoutMode
                switchBlackoutMode(from: oldValue, to: blackoutMode)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let settingsManager: SettingsManager
    private let displayObserver = DisplayObserver()
    
    /// Current active blackout provider based on mode
    private var activeProvider: BlackoutProvider {
        switch blackoutMode {
        case .window:
            return WindowBlackoutProvider.shared
        case .softwareDimming:
            return SoftwareBlackoutProvider.shared
        }
    }
    
    // MARK: - Initialization
    
    init(settingsManager: SettingsManager? = nil) {
        let manager = settingsManager ?? SettingsManager.shared
        self.settingsManager = manager
        self.autoBlackoutBuiltin = manager.settings.autoBlackoutBuiltin
        self.blackoutMode = manager.settings.blackoutMode
        
        // Register termination handler for gamma restoration
        SoftwareBlackoutProvider.shared.registerTerminationHandler()
        
        // Initial display enumeration
        enumerateDisplays()
        
        // Start observing display changes
        displayObserver.startObserving { [weak self] in
            self?.handleDisplayConfigurationChange()
        }
        
        // Apply saved blackout states
        restoreBlackoutStates()
    }
    
    // Note: DisplayObserver cleanup happens automatically when it's deallocated
    
    // MARK: - Public API
    
    /// Toggles the blackout state of a display
    func toggleBlackout(for display: Display) {
        let isCurrentlyBlackedOut = isBlackedOut(display: display)
        
        if isCurrentlyBlackedOut {
            restore(display: display)
        } else {
            blackout(display: display)
        }
    }
    
    /// Blacks out a display
    func blackout(display: Display) {
        activeProvider.blackout(display: display)
        settingsManager.settings.setBlackedOut(true, for: display.id)
    }
    
    /// Restores a display from blackout
    func restore(display: Display) {
        activeProvider.restore(display: display)
        settingsManager.settings.setBlackedOut(false, for: display.id)
    }
    
    /// Checks if a display is currently blacked out
    func isBlackedOut(display: Display) -> Bool {
        activeProvider.isBlackedOut(display: display)
    }
    
    /// Returns the built-in display if present
    var builtinDisplay: Display? {
        displays.first { $0.isBuiltin }
    }
    
    /// Returns all external displays
    var externalDisplays: [Display] {
        displays.filter { !$0.isBuiltin }
    }
    
    /// Whether there are any external displays connected
    var hasExternalDisplays: Bool {
        !externalDisplays.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Enumerates all connected displays
    private func enumerateDisplays() {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        guard displayCount > 0 else {
            displays = []
            return
        }
        
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
        
        displays = displayIDs.map { Display(cgDisplayID: $0) }
    }
    
    /// Restores blackout states from saved settings
    private func restoreBlackoutStates() {
        for display in displays {
            if settingsManager.settings.isBlackedOut(displayID: display.id) {
                activeProvider.blackout(display: display)
            }
        }
        
        // Handle auto-blackout if enabled
        if autoBlackoutBuiltin {
            handleAutoBlackoutChange()
        }
    }
    
    /// Handles display configuration changes (connect/disconnect)
    private func handleDisplayConfigurationChange() {
        let previousDisplays = displays
        enumerateDisplays()
        
        // Check for newly connected or disconnected displays
        let previousIDs = Set(previousDisplays.map { $0.id })
        let currentIDs = Set(displays.map { $0.id })
        
        let addedIDs = currentIDs.subtracting(previousIDs)
        let removedIDs = previousIDs.subtracting(currentIDs)
        
        // Clean up blackout windows for disconnected displays
        for removedID in removedIDs {
            if let removedDisplay = previousDisplays.first(where: { $0.id == removedID }) {
                // Both providers should clean up
                WindowBlackoutProvider.shared.restore(display: removedDisplay)
                SoftwareBlackoutProvider.shared.restore(display: removedDisplay)
            }
        }
        
        // Restore blackout state for reconnected displays
        for addedID in addedIDs {
            if let addedDisplay = displays.first(where: { $0.id == addedID }),
               settingsManager.settings.isBlackedOut(displayID: addedID) {
                activeProvider.blackout(display: addedDisplay)
            }
        }
        
        // Handle auto-blackout logic
        if autoBlackoutBuiltin {
            handleAutoBlackoutChange()
        }
    }
    
    /// Handles auto-blackout state changes
    private func handleAutoBlackoutChange() {
        guard let builtinDisplay = builtinDisplay else { return }
        
        if autoBlackoutBuiltin && hasExternalDisplays {
            // Blackout built-in when external displays are connected
            if !isBlackedOut(display: builtinDisplay) {
                blackout(display: builtinDisplay)
            }
        } else if !hasExternalDisplays {
            // Always restore built-in if no external displays
            // (regardless of auto-blackout setting, to prevent being stuck with black screen)
            if isBlackedOut(display: builtinDisplay) {
                restore(display: builtinDisplay)
            }
        }
    }
    
    /// Switches between blackout modes, transferring blackout states
    private func switchBlackoutMode(from oldMode: BlackoutMode, to newMode: BlackoutMode) {
        let oldProvider: BlackoutProvider
        let newProvider: BlackoutProvider
        
        switch oldMode {
        case .window:
            oldProvider = WindowBlackoutProvider.shared
        case .softwareDimming:
            oldProvider = SoftwareBlackoutProvider.shared
        }
        
        switch newMode {
        case .window:
            newProvider = WindowBlackoutProvider.shared
        case .softwareDimming:
            newProvider = SoftwareBlackoutProvider.shared
        }
        
        // Transfer blackout states from old to new provider
        for display in displays {
            if oldProvider.isBlackedOut(display: display) {
                oldProvider.restore(display: display)
                newProvider.blackout(display: display)
            }
        }
    }
}

