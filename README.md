# DisplayCut

A macOS menu bar application for controlling display blackout on multiple monitors. DisplayCut allows you to selectively black out individual displays, with support for automatic built-in display blackout when external displays are connected.

## Features

- **Multi-Display Support**: Manage blackout state for each connected display independently
- **Two Blackout Modes**:
  - **Window Mode**: Uses fullscreen black window overlays (works on all displays)
  - **Software Dimming Mode**: Uses gamma adjustment and DDC brightness control (for supported displays)
- **Auto-Blackout**: Automatically black out the built-in display when external displays are connected
- **Mouse Guard**: Prevents mouse cursor from entering blacked-out displays
- **Persistent Settings**: Remembers blackout states across app restarts and display reconnections
- **Display Detection**: Automatically detects when displays are connected or disconnected

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/DisplayCut.git
cd DisplayCut
```

2. Open the project in Xcode:
```bash
open DisplayCut.xcodeproj
```

3. Build and run the project (⌘R)

4. The app will appear in your menu bar with a display icon

## Usage

### Basic Usage

1. Click the display icon in your menu bar
2. Select a display from the list
3. Click on the display to toggle its blackout state

### Blackout Modes

Choose between two blackout modes in the menu:

- **Window Mode**: Creates a fullscreen black window overlay. This is the default mode and works reliably on all displays.
- **Software Dimming Mode**: Uses gamma adjustment and DDC brightness control. Provides deeper control but requires DDC support for external displays.

### Auto-Blackout

Enable "Auto-Blackout" to automatically black out the built-in display when external displays are connected. The built-in display will be restored when all external displays are disconnected.

### Display Management

- Each display shows its current state (enabled or blacked out)
- Built-in displays are marked with a laptop icon
- External displays are marked with a display icon
- Blacked-out displays show an orange status indicator

## Architecture

The application is built using SwiftUI and follows a modular architecture:

- **Core**: Display management, settings persistence, and display observation
- **Blackout**: Blackout provider implementations (Window and Software Dimming)
- **Utilities**: DDC control, gamma control, and mouse guard functionality
- **Views**: Menu bar interface

### Key Components

- `DisplayManager`: Central manager for display enumeration and blackout state
- `BlackoutProvider`: Protocol for blackout implementations
- `WindowBlackoutProvider`: Window-based blackout implementation
- `SoftwareBlackoutProvider`: Gamma/DDC-based blackout implementation
- `MouseGuard`: Prevents mouse cursor from entering blacked-out displays
- `SettingsManager`: Handles persistent settings storage

## Technical Details

### Display Identification

Displays are identified using a stable identifier based on vendor ID, model ID, and serial number. This ensures that blackout states persist across reboots and display reconnections, even if the CoreGraphics display ID changes.

### DDC Control

For external displays that support DDC/CI, the software dimming mode can control brightness directly. This provides a more hardware-level blackout compared to window overlays.

### Gamma Control

The software dimming mode uses CoreGraphics gamma tables to darken displays. Original gamma values are saved and restored when displays are un-blackouted.

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Built with SwiftUI and AppKit
- Uses CoreGraphics for display management
- DDC control implementation for external display brightness


