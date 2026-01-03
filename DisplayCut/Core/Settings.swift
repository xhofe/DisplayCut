//
//  Settings.swift
//  DisplayCut
//
//  Persistence model for app settings using UserDefaults.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Blackout Mode

/// Available modes for blacking out displays
enum BlackoutMode: String, Codable, CaseIterable {
    /// Creates a black window overlay on the display
    case window = "window"
    
    /// Uses software gamma adjustment and DDC brightness control
    case softwareDimming = "dimming"
    
    /// Localized display name for the mode
    var localizedName: String {
        switch self {
        case .window:
            return String(localized: "menu.mode.window")
        case .softwareDimming:
            return String(localized: "menu.mode.dimming")
        }
    }
}

// MARK: - App Settings

/// Main settings model for the application
struct AppSettings: Codable {
    /// Whether to automatically blackout the built-in display when external displays are connected
    var autoBlackoutBuiltin: Bool = false
    
    /// The current blackout mode
    var blackoutMode: BlackoutMode = .window
    
    /// Per-display configuration
    var displayConfigs: [DisplayConfig] = []
    
    // MARK: - Display Config Helpers
    
    /// Gets or creates a configuration for the specified display
    mutating func config(for displayID: DisplayIdentifier) -> DisplayConfig {
        if let existing = displayConfigs.first(where: { $0.displayID == displayID }) {
            return existing
        }
        let newConfig = DisplayConfig(displayID: displayID)
        displayConfigs.append(newConfig)
        return newConfig
    }
    
    /// Updates the blackout state for a specific display
    mutating func setBlackedOut(_ isBlackedOut: Bool, for displayID: DisplayIdentifier) {
        if let index = displayConfigs.firstIndex(where: { $0.displayID == displayID }) {
            displayConfigs[index].isBlackedOut = isBlackedOut
        } else {
            displayConfigs.append(DisplayConfig(displayID: displayID, isBlackedOut: isBlackedOut))
        }
    }
    
    /// Checks if a display is configured as blacked out
    func isBlackedOut(displayID: DisplayIdentifier) -> Bool {
        displayConfigs.first(where: { $0.displayID == displayID })?.isBlackedOut ?? false
    }
}

// MARK: - Settings Manager

/// Manages persistence of app settings to UserDefaults
@MainActor
final class SettingsManager: ObservableObject {
    /// Shared singleton instance
    static let shared = SettingsManager()
    
    /// UserDefaults key for settings storage
    private static let settingsKey = "DisplayCutSettings"
    
    /// Current app settings
    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }
    
    private init() {
        self.settings = Self.load()
    }
    
    // MARK: - Persistence
    
    /// Loads settings from UserDefaults
    private static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return AppSettings()
        }
        
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return AppSettings()
        }
    }
    
    /// Saves current settings to UserDefaults
    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }
}

