//
//  GammaControl.swift
//  DisplayCut
//
//  Wrapper for CoreGraphics gamma table manipulation.
//

import Foundation
import CoreGraphics

/// Controls display gamma tables to achieve software-level dimming.
/// Setting all gamma values to 0 makes the display appear completely black.
enum GammaControl {
    
    /// Number of entries in the gamma table
    private static let tableSize: UInt32 = 256
    
    // MARK: - Public API
    
    /// Sets the display gamma to all zeros, making the screen appear black.
    /// - Parameter displayID: The display to modify
    /// - Returns: True if successful
    @discardableResult
    static func setBlack(displayID: CGDirectDisplayID) -> Bool {
        // Create a table of zeros for R, G, B channels
        var table = [CGGammaValue](repeating: 0.0, count: Int(tableSize))
        
        let result = CGSetDisplayTransferByTable(
            displayID,
            tableSize,
            &table,  // Red
            &table,  // Green
            &table   // Blue
        )
        
        if result != .success {
            print("Failed to set gamma for display \(displayID): \(result)")
            return false
        }
        
        return true
    }
    
    /// Restores the default gamma/color settings for all displays.
    /// This is the recommended way to restore gamma as it uses ColorSync profiles.
    static func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
    }
    
    /// Restores the default gamma for a specific display.
    /// Note: This actually restores all displays due to API limitations.
    /// - Parameter displayID: The display to restore (currently ignored)
    static func restore(displayID: CGDirectDisplayID) {
        // CoreGraphics doesn't provide a per-display restore function
        // CGDisplayRestoreColorSyncSettings restores all displays
        // For targeted restore, we would need to cache and reapply other displays' settings
        CGDisplayRestoreColorSyncSettings()
    }
    
    /// Gets the current gamma table for a display.
    /// Useful for saving state before modification.
    /// - Parameter displayID: The display to query
    /// - Returns: Tuple of (red, green, blue) gamma tables, or nil on failure
    static func getCurrentGamma(displayID: CGDirectDisplayID) -> (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])? {
        var red = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var green = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var blue = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var sampleCount: UInt32 = 0
        
        let result = CGGetDisplayTransferByTable(
            displayID,
            tableSize,
            &red,
            &green,
            &blue,
            &sampleCount
        )
        
        guard result == .success else {
            print("Failed to get gamma for display \(displayID): \(result)")
            return nil
        }
        
        return (red, green, blue)
    }
    
    /// Sets a custom gamma table for a display.
    /// - Parameters:
    ///   - displayID: The display to modify
    ///   - red: Red channel gamma values
    ///   - green: Green channel gamma values
    ///   - blue: Blue channel gamma values
    /// - Returns: True if successful
    @discardableResult
    static func setGamma(displayID: CGDirectDisplayID, red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]) -> Bool {
        var redTable = red
        var greenTable = green
        var blueTable = blue
        
        let result = CGSetDisplayTransferByTable(
            displayID,
            UInt32(red.count),
            &redTable,
            &greenTable,
            &blueTable
        )
        
        return result == .success
    }
}

