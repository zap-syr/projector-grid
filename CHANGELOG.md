# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.0] - 2026-05-03

### Added
- Event Log panel - a resizable panel at the bottom of the workspace displaying
  timestamped OSC, connectivity, and command events with colour-coded severity indicators
- Filter tabs (All / Errors / Commands / Connectivity / OSC) and a live search field
  in the Event Log toolbar, plus copy-to-clipboard and clear buttons
- "Show Logs" toggle in the View menu (Windows top menu bar and macOS menu bar) to
  show and hide the Event Log panel
- Ctrl+1 / Ctrl+2 keyboard shortcuts (Cmd+1 / Cmd+2 on macOS) to switch between the
  Controls and Monitoring views; shortcut hints shown in the View menu items
- Ctrl+1 / Ctrl+2 entries added to the Keyboard Shortcuts reference dialog

### Fixed
- All keyboard shortcuts (Ctrl+A, Ctrl+D, Ctrl+Z, Ctrl+Y, etc.) now remain active
  after switching between Controls and Monitoring views - Flutter's IndexedStack
  Visibility/ExcludeFocus mechanism was silently clearing primaryFocus on every switch,
  causing Shortcuts lookup to fail silently
- Edit Projector dialog no longer requires login and password, making them optional
  to support non-protected projectors
- Edit Projector dialog now validates that the entered IP address is not already used
  by another projector in the project

## [1.0.2] - 2026-04-30

### Added
- "Select in Group" right-click context menu item on projector cards — selects all
  cards in the same group; greyed out when the card has no group assigned
- Non-protected mode support (NTCONTROL 0): projectors without authentication are now
  discovered, added, and controlled alongside protected ones
- `ConnectionStatus.unprotected` state with a blue open-lock indicator on projector
  cards and in the monitoring table
- Auto Discovery tab now detects and lists non-protected projectors with a blue
  open-lock icon and "Non-protected mode" subtitle
- Hint text in both Manual Add and Auto Discovery tabs explaining that credentials
  are not required for non-protected projectors

### Fixed
- Unauthorized projectors no longer briefly flash as "Connected" during poll cycles -
  only offline nodes go through the cheap TCP pre-check that sets an intermediate
  connected state
- Response prefix stripping changed from fragile `indexOf('00')` to deterministic
  `startsWith('00')`, preventing false matches inside model name strings
- Workspace zoom level and scroll position are now preserved when switching between
  the Controls and Monitoring tabs
- Projector cards no longer drift away from the cursor when dragged against a
  workspace boundary and the mouse reverses direction

### Changed
- Monitoring table shows "Online" with open-lock icon for non-protected
  projectors instead of a plain online label
- Default credentials removed from login and password fields in both dialog tabs;
  validators now accept empty values
- Online count in the status bar and OSC provider includes unprotected projectors
- Command dispatch (selected, group, all) now sends to unprotected projectors

## [1.0.1] - 2026-04-29

### Added
- macOS menu bar with keyboard shortcuts for common projector operations
- CocoaPods integration for macOS native plugin support

### Fixed
- Application name on macOS now matches project branding
- Network client and server permissions added to macOS entitlements
- Monitoring table no longer overflows on macOS

### Changed
- Updated project dependencies
