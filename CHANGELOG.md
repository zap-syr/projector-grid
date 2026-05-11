# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.2.1] - 2026-05-11

### Fixed
- App no longer crashes when a projector is deleted while a drag, snap, or
  power command is still in progress
- Errors from OSC-triggered projector commands are now printed to the debug
  console instead of disappearing silently
- Power on/off follow-up polls are now properly cancelled when the app shuts
  down, preventing callbacks from firing after the app state is torn down
- A helpful error message now appears in the Event Log when a project file
  fails to open, instead of nothing happening
- Tooltips no longer block mouse clicks and hover events on the buttons beneath
  them; the tooltip overlay is now fully transparent to pointer input
- Saving a test pattern to a favourite slot now stores it in the exact slot you
  clicked, previously it always filled the first available slot from the left

## [1.2.0] - 2026-05-06

### Added
- Geometry Correction dialog with three correction modes: Keystone, Curved, and
  Corner - accessible per projector from the right-click context menu
- Corner Correction canvas with four independently draggable points, keyboard
  arrow-key nudging, double-tap to reset individual points, and a Reset All button
- Compact numeric stepper fields with up/down buttons - tap once to step by one,
  hold to change the value continuously

### Changed
- Color Correction dialog inputs replaced with compact stepper fields
- App settings (theme mode, polling interval, OSC port) are now persisted to
  disk as JSON in the platform config directory so they survive restarts

### Fixed
- Segmented button selected-icon visibility corrected to remain consistent
  across state changes
- Default window size on macOS set to a sensible initial value
- Mouse cursor behaviour on macOS corrected to use appropriate system cursors

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
