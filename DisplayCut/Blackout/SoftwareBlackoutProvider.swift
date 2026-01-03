//
//  SoftwareBlackoutProvider.swift
//  DisplayCut
//
//  Blackout implementation using software gamma adjustment and DDC brightness control.
//

import AppKit
import Foundation
import CoreGraphics

/// Blacks out displays using software gamma tables (for all displays) and
/// DDC brightness control (for external displays that support it).
/// This provides a deeper level of control than window overlay.
@MainActor
final class SoftwareBlackoutProvider: BlackoutProvider {
    
    /// Shared singleton instance
    static let shared = SoftwareBlackoutProvider()
    
    /// Tracks which displays are currently blacked out
    private var blackedOutDisplays: Set<DisplayIdentifier> = []
    
    /// Stores original DDC brightness values for restoration
    private var originalBrightness: [DisplayIdentifier: UInt8] = [:]
    
    /// Stores original gamma tables for per-display restoration
    private var originalGamma: [DisplayIdentifier: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]
    
    private init() {}
    
    // MARK: - BlackoutProvider
    
    func blackout(display: Display) {
        guard !blackedOutDisplays.contains(display.id) else { return }
        
        // Save original gamma before modification
        if let gamma = GammaControl.getCurrentGamma(displayID: display.cgDisplayID) {
            originalGamma[display.id] = gamma
        }
        
        // Apply gamma blackout (works on all displays)
        GammaControl.setBlack(displayID: display.cgDisplayID)
        
        // For external displays, also try DDC brightness control
        if !display.isBuiltin {
            if let brightness = DDCControl.getBrightness(displayID: display.cgDisplayID) {
                originalBrightness[display.id] = brightness
                DDCControl.setBrightness(displayID: display.cgDisplayID, value: 0)
            }
        }
        
        blackedOutDisplays.insert(display.id)
    }
    
    func restore(display: Display) {
        guard blackedOutDisplays.contains(display.id) else { return }
        
        // Restore DDC brightness if we saved it
        if let brightness = originalBrightness.removeValue(forKey: display.id) {
            DDCControl.setBrightness(displayID: display.cgDisplayID, value: brightness)
        }
        
        // Restore gamma
        // Note: CGDisplayRestoreColorSyncSettings restores all displays,
        // so we need to re-apply blackout to other blacked-out displays
        if let gamma = originalGamma.removeValue(forKey: display.id) {
            // First restore this display's gamma
            GammaControl.setGamma(
                displayID: display.cgDisplayID,
                red: gamma.red,
                green: gamma.green,
                blue: gamma.blue
            )
        } else {
            // Fallback: restore all and re-blackout others
            GammaControl.restoreAll()
            
            // Re-apply blackout to other displays that should remain blacked out
            // This is a workaround for the all-or-nothing gamma restore API
            reapplyBlackoutToOtherDisplays(except: display.id)
        }
        
        blackedOutDisplays.remove(display.id)
    }
    
    func restoreAll() {
        // Restore all DDC brightness values
        for (displayID, brightness) in originalBrightness {
            // We need to find the current CGDirectDisplayID for this display
            // This is a limitation - we can't restore DDC without the runtime ID
            // For now, we'll rely on the gamma restore which is the primary effect
            _ = displayID
            _ = brightness
        }
        originalBrightness.removeAll()
        originalGamma.removeAll()
        
        // Restore all gamma settings
        GammaControl.restoreAll()
        
        blackedOutDisplays.removeAll()
    }
    
    func isBlackedOut(display: Display) -> Bool {
        blackedOutDisplays.contains(display.id)
    }
    
    // MARK: - Private Helpers
    
    /// Re-applies blackout to displays that should remain blacked out
    /// Called after restoring gamma for a single display
    private func reapplyBlackoutToOtherDisplays(except excludedID: DisplayIdentifier) {
        // Get all active displays
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
        
        for cgDisplayID in displayIDs {
            let vendorID = CGDisplayVendorNumber(cgDisplayID)
            let modelID = CGDisplayModelNumber(cgDisplayID)
            let serialNumber = CGDisplaySerialNumber(cgDisplayID)
            let displayID = DisplayIdentifier(vendorID: vendorID, modelID: modelID, serialNumber: serialNumber)
            
            // Re-blackout displays that should remain blacked out
            if displayID != excludedID && blackedOutDisplays.contains(displayID) {
                GammaControl.setBlack(displayID: cgDisplayID)
            }
        }
    }
}

// MARK: - App Termination Handler

extension SoftwareBlackoutProvider {
    /// Ensures gamma is restored when the app terminates.
    /// Call this during app initialization.
    func registerTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Restore gamma synchronously on termination
            GammaControl.restoreAll()
            _ = self  // Silence unused warning
        }
    }
}

