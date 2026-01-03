//
//  MenuBarView.swift
//  DisplayCut
//
//  Menu bar dropdown UI showing displays and settings.
//

import SwiftUI

/// Main menu content view displayed in the menu bar dropdown
struct MenuBarView: View {
    @ObservedObject var displayManager: DisplayManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Displays section
            displaySection
            
            Divider()
                .padding(.vertical, 4)
            
            // Blackout mode picker
            blackoutModePicker
            
            Divider()
                .padding(.vertical, 4)
            
            // Auto-blackout toggle
            autoBlackoutToggle
            
            Divider()
                .padding(.vertical, 4)
            
            // Quit button
            quitButton
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Display Section
    
    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("menu.displays")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            
            ForEach(displayManager.displays) { display in
                DisplayRow(
                    display: display,
                    isBlackedOut: displayManager.isBlackedOut(display: display),
                    onToggle: {
                        displayManager.toggleBlackout(for: display)
                    }
                )
            }
        }
    }
    
    // MARK: - Blackout Mode Picker
    
    private var blackoutModePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("menu.blackoutMode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            
            ForEach(BlackoutMode.allCases, id: \.self) { mode in
                Button(action: {
                    displayManager.blackoutMode = mode
                }) {
                    HStack {
                        Image(systemName: displayManager.blackoutMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(displayManager.blackoutMode == mode ? .blue : .secondary)
                        
                        Text(mode.localizedName)
                        
                        Spacer()
                    }
                }
                .buttonStyle(MenuRowButtonStyle())
            }
        }
    }
    
    // MARK: - Auto-blackout Toggle
    
    private var autoBlackoutToggle: some View {
        Button(action: {
            displayManager.autoBlackoutBuiltin.toggle()
        }) {
            HStack {
                Image(systemName: displayManager.autoBlackoutBuiltin ? "checkmark.square.fill" : "square")
                    .foregroundStyle(displayManager.autoBlackoutBuiltin ? .blue : .secondary)
                
                Text("menu.autoBlackout")
                
                Spacer()
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }
    
    // MARK: - Quit Button
    
    private var quitButton: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack {
                Image(systemName: "power")
                    .foregroundStyle(.red)
                
                Text("menu.quit")
                
                Spacer()
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

// MARK: - Display Row

/// A single display row in the menu
private struct DisplayRow: View {
    let display: Display
    let isBlackedOut: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // Display icon
                Image(systemName: display.isBuiltin ? "laptopcomputer" : "display")
                    .foregroundStyle(isBlackedOut ? .secondary : .primary)
                
                // Display name
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.localizedName)
                        .foregroundStyle(isBlackedOut ? .secondary : .primary)
                    
                    // Status indicator
                    Text(isBlackedOut ? "display.blackedOut" : "display.enabled")
                        .font(.caption2)
                        .foregroundStyle(isBlackedOut ? .orange : .green)
                }
                
                Spacer()
                
                // Toggle indicator
                Image(systemName: isBlackedOut ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(isBlackedOut ? .orange : .green)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

// MARK: - Menu Row Button Style

/// Custom button style for menu rows with hover effect
struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.accentColor.opacity(0.3)
        } else if isHovering {
            return Color.primary.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(displayManager: DisplayManager())
        .frame(width: 280)
}

