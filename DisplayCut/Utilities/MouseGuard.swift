//
//  MouseGuard.swift
//  DisplayCut
//
//  Prevents mouse cursor from entering blacked-out displays.
//

import Foundation
import CoreGraphics
import AppKit

/// Monitors mouse movement and prevents cursor from entering disabled displays.
final class MouseGuard {
    
    /// Shared singleton instance
    static let shared = MouseGuard()
    
    /// Set of display frames that the mouse should not enter
    private var blockedFrames: [DisplayIdentifier: CGRect] = [:]
    
    /// Event tap for monitoring mouse movement
    private var eventTap: CFMachPort?
    
    /// Run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?
    
    /// Whether the guard is currently active
    private(set) var isActive = false
    
    /// Lock for thread-safe access to blockedFrames
    private let lock = NSLock()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Adds a display to the blocked list
    func blockDisplay(_ display: Display) {
        guard let screen = screen(for: display.cgDisplayID) else { return }
        
        lock.lock()
        blockedFrames[display.id] = screen.frame
        lock.unlock()
        
        // Start monitoring if not already active
        if !isActive {
            startMonitoring()
        }
    }
    
    /// Removes a display from the blocked list
    func unblockDisplay(_ display: Display) {
        lock.lock()
        blockedFrames.removeValue(forKey: display.id)
        let isEmpty = blockedFrames.isEmpty
        lock.unlock()
        
        // Stop monitoring if no more blocked displays
        if isEmpty && isActive {
            stopMonitoring()
        }
    }
    
    /// Removes all displays from the blocked list
    func unblockAll() {
        lock.lock()
        blockedFrames.removeAll()
        lock.unlock()
        
        stopMonitoring()
    }
    
    /// Updates the frame for a display (call after display configuration changes)
    func updateDisplayFrame(_ display: Display) {
        lock.lock()
        let hasDisplay = blockedFrames[display.id] != nil
        lock.unlock()
        
        guard hasDisplay, let screen = screen(for: display.cgDisplayID) else { return }
        
        lock.lock()
        blockedFrames[display.id] = screen.frame
        lock.unlock()
    }
    
    // MARK: - Private Methods
    
    /// Finds the NSScreen for a display ID
    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }
    }
    
    /// Starts monitoring mouse movement
    private func startMonitoring() {
        guard !isActive else { return }
        
        // Create event tap to monitor mouse movement
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) |
                                      (1 << CGEventType.leftMouseDragged.rawValue) |
                                      (1 << CGEventType.rightMouseDragged.rawValue) |
                                      (1 << CGEventType.otherMouseDragged.rawValue)
        
        // Store self pointer for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                mouseEventCallback(proxy: proxy, type: type, event: event, userInfo: userInfo)
            },
            userInfo: selfPtr
        )
        
        guard let eventTap = eventTap else {
            print("MouseGuard: Failed to create event tap. May need Accessibility permissions.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isActive = true
        }
    }
    
    /// Stops monitoring mouse movement
    private func stopMonitoring() {
        guard isActive else { return }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isActive = false
    }
    
    /// Handles mouse events and constrains cursor position
    fileprivate func handleMouseEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        let mouseLocation = event.location
        
        // Check if mouse is in any blocked frame
        lock.lock()
        let frames = blockedFrames
        lock.unlock()
        
        for (_, blockedFrame) in frames {
            if blockedFrame.contains(mouseLocation) {
                // Find the nearest allowed position
                let constrainedPosition = constrainPosition(mouseLocation, awayFrom: blockedFrame)
                
                // Warp cursor to the constrained position
                CGWarpMouseCursorPosition(constrainedPosition)
                
                // Update event location
                event.location = constrainedPosition
                
                return Unmanaged.passUnretained(event)
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Constrains a position to stay outside a blocked frame
    private func constrainPosition(_ position: CGPoint, awayFrom blockedFrame: CGRect) -> CGPoint {
        var newPosition = position
        
        // Find the closest edge and push the cursor outside
        let distanceToLeft = position.x - blockedFrame.minX
        let distanceToRight = blockedFrame.maxX - position.x
        let distanceToTop = position.y - blockedFrame.minY
        let distanceToBottom = blockedFrame.maxY - position.y
        
        let minHorizontal = min(distanceToLeft, distanceToRight)
        let minVertical = min(distanceToTop, distanceToBottom)
        
        if minHorizontal < minVertical {
            // Push horizontally
            if distanceToLeft < distanceToRight {
                newPosition.x = blockedFrame.minX - 1
            } else {
                newPosition.x = blockedFrame.maxX + 1
            }
        } else {
            // Push vertically
            if distanceToTop < distanceToBottom {
                newPosition.y = blockedFrame.minY - 1
            } else {
                newPosition.y = blockedFrame.maxY + 1
            }
        }
        
        return newPosition
    }
}

// MARK: - Event Tap Callback

/// C callback function for CGEvent tap
private func mouseEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    
    let mouseGuard = Unmanaged<MouseGuard>.fromOpaque(userInfo).takeUnretainedValue()
    return mouseGuard.handleMouseEvent(event, type: type)
}
