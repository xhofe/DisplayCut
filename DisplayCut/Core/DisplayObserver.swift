//
//  DisplayObserver.swift
//  DisplayCut
//
//  Monitors display configuration changes (connect/disconnect events).
//

import Foundation
import CoreGraphics
import AppKit

/// Observes display configuration changes and notifies listeners.
final class DisplayObserver {
    
    /// Callback type for display configuration changes
    typealias ChangeHandler = @MainActor () -> Void
    
    /// The handler to call when display configuration changes
    private var changeHandler: ChangeHandler?
    
    /// Whether the observer is currently active
    private(set) var isObserving = false
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Public API
    
    /// Starts observing display configuration changes.
    /// - Parameter handler: Closure called on the main thread when displays change
    func startObserving(handler: @escaping ChangeHandler) {
        guard !isObserving else { return }
        
        self.changeHandler = handler
        
        // Register for CoreGraphics display reconfiguration callback
        let result = CGDisplayRegisterReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if result == .success {
            isObserving = true
        } else {
            print("Failed to register display reconfiguration callback: \(result)")
            
            // Fallback to NSNotification if CG callback fails
            registerNotificationFallback()
        }
    }
    
    /// Stops observing display configuration changes.
    func stopObserving() {
        guard isObserving else { return }
        
        CGDisplayRemoveReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        NotificationCenter.default.removeObserver(self)
        
        isObserving = false
        changeHandler = nil
    }
    
    // MARK: - Private Helpers
    
    /// Fallback to NSNotification for display changes
    private func registerNotificationFallback() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isObserving = true
    }
    
    @objc private func handleDisplayConfigurationChange(_ notification: Notification) {
        Task { @MainActor in
            changeHandler?()
        }
    }
    
    /// Called by the CoreGraphics reconfiguration callback
    fileprivate func notifyChange() {
        Task { @MainActor in
            changeHandler?()
        }
    }
}

// MARK: - CoreGraphics Callback

/// C callback function for CGDisplayRegisterReconfigurationCallback
private func displayReconfigurationCallback(
    displayID: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    // Only notify on completion of reconfiguration
    guard flags.contains(.beginConfigurationFlag) == false else { return }
    
    // Check for relevant changes
    let isAddOrRemove = flags.contains(.addFlag) || flags.contains(.removeFlag)
    let isEnabledOrDisabled = flags.contains(.enabledFlag) || flags.contains(.disabledFlag)
    
    guard isAddOrRemove || isEnabledOrDisabled else { return }
    
    // Get the observer instance and notify
    guard let userInfo = userInfo else { return }
    let observer = Unmanaged<DisplayObserver>.fromOpaque(userInfo).takeUnretainedValue()
    observer.notifyChange()
}

