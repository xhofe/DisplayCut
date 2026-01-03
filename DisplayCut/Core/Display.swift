//
//  Display.swift
//  DisplayCut
//
//  Display data model for representing connected monitors.
//

import Foundation
import CoreGraphics
import AppKit

// MARK: - Display Model

/// Represents a connected display with stable identifiers for persistence.
struct Display: Identifiable, Hashable {
    /// Unique identifier combining vendor, model, and serial number
    let id: DisplayIdentifier
    
    /// Whether this is the built-in display (MacBook screen)
    let isBuiltin: Bool
    
    /// Runtime-only: Current CoreGraphics display ID (not persisted)
    var cgDisplayID: CGDirectDisplayID
    
    /// Localized display name from the system
    var localizedName: String
    
    // MARK: - Initialization
    
    /// Creates a Display from a CGDirectDisplayID
    /// - Parameter cgDisplayID: The CoreGraphics display identifier
    init(cgDisplayID: CGDirectDisplayID) {
        self.cgDisplayID = cgDisplayID
        self.isBuiltin = CGDisplayIsBuiltin(cgDisplayID) != 0
        
        // Create stable identifier from hardware info
        let vendorID = CGDisplayVendorNumber(cgDisplayID)
        let modelID = CGDisplayModelNumber(cgDisplayID)
        let serialNumber = CGDisplaySerialNumber(cgDisplayID)
        self.id = DisplayIdentifier(vendorID: vendorID, modelID: modelID, serialNumber: serialNumber)
        
        // Get localized name from NSScreen
        self.localizedName = Self.getDisplayName(for: cgDisplayID) ?? Self.fallbackName(isBuiltin: isBuiltin)
    }
    
    // MARK: - Private Helpers
    
    /// Gets the localized display name from NSScreen
    private static func getDisplayName(for displayID: CGDirectDisplayID) -> String? {
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               screenNumber == displayID {
                return screen.localizedName
            }
        }
        return nil
    }
    
    /// Provides a fallback name based on display type
    private static func fallbackName(isBuiltin: Bool) -> String {
        if isBuiltin {
            return String(localized: "display.builtin")
        } else {
            return String(localized: "display.external")
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Display, rhs: Display) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Display Identifier

/// Stable identifier for a display using hardware information.
/// This remains constant across reboots, unlike CGDirectDisplayID.
struct DisplayIdentifier: Hashable, Codable {
    let vendorID: UInt32
    let modelID: UInt32
    let serialNumber: UInt32
    
    /// String representation for use as dictionary key
    var stringValue: String {
        "\(vendorID)-\(modelID)-\(serialNumber)"
    }
}

// MARK: - Display Configuration

/// Persisted configuration for a specific display
struct DisplayConfig: Codable, Hashable {
    /// The stable display identifier
    let displayID: DisplayIdentifier
    
    /// Whether the display should be blacked out
    var isBlackedOut: Bool
    
    init(displayID: DisplayIdentifier, isBlackedOut: Bool = false) {
        self.displayID = displayID
        self.isBlackedOut = isBlackedOut
    }
}

