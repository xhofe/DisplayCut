//
//  BlackoutProvider.swift
//  DisplayCut
//
//  Protocol defining the interface for display blackout implementations.
//

import Foundation

/// Protocol for implementing display blackout functionality.
/// Conforming types provide different methods to visually disable a display.
@MainActor
protocol BlackoutProvider {
    /// Blacks out the specified display
    /// - Parameter display: The display to blackout
    func blackout(display: Display)
    
    /// Restores the specified display from blackout state
    /// - Parameter display: The display to restore
    func restore(display: Display)
    
    /// Restores all displays that are currently blacked out
    func restoreAll()
    
    /// Checks if a display is currently blacked out by this provider
    /// - Parameter display: The display to check
    /// - Returns: True if the display is blacked out
    func isBlackedOut(display: Display) -> Bool
}

