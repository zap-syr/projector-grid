# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.4.0] - 2026-08-25

### For Users

#### Added
- Window size, position, and maximized state are now remembered across
  restarts instead of always reopening at a fixed 1280×720 centered on
  screen
- Projector cards now highlight their border and show a pointer cursor on
  hover, making it clearer which card you're about to click or drag
- Releasing a dragged projector now eases smoothly into its snapped grid
  position instead of jumping there instantly; the selection border also
  transitions smoothly instead of snapping on/off
- The status bar now shows when projectors were last refreshed, with a
  spinner while a refresh (F5, the Refresh menu item, or the automatic
  poll) is in progress; it's also visible in the Monitoring view
  now instead of disappearing outside Controls
- F now zooms/pans the workspace to fit the selected projectors (or all
  projectors, if none are selected); Shift+F always fits all projectors
  regardless of selection

#### Changed
- Redesigned the Color Correction dialog: color entries and color-temperature
  groups are now flat, always-visible cards instead of collapsible sections,
  the Color Temperature tab's mode dropdown was replaced with a segmented
  button to match the Color Matching tab, and card backgrounds are now
  visually distinct from the dialog surface
- Commands sent to selected projectors, a group, or all projectors are now
  dispatched concurrently in batches of up to 100 instead of one at a time,
  so large installs feel much closer to simultaneous
- Projector polling now runs concurrently in batches of up to 100 instead of
  sequentially, keeping a full poll cycle fast even with 100+ projectors on
  the workspace
- The Keyboard Shortcuts dialog now shows ⌘/⇧ symbols on macOS instead of
  Windows-style "Ctrl"/"Shift" labels
- Raised the minimum supported macOS version from 10.15 to 12.0, required by
  the updated toolchain
- The Edit menu now only has Undo/Redo; Refresh, Manage Groups, Scheduled
  Tasks, and (Windows) Preferences moved into a new Tools menu, which also
  gained an Add Projectors entry

#### Fixed
- Geometry Correction: dragging a Corner Correction handle no longer
  rebuilds the entire dialog on every frame of the drag; switching a
  Linearity/Pincushion slider between Auto and Manual no longer resets its
  numeric stepper's typed value
- Brightness Control: dragging the Light Output or Max Light Output slider
  no longer rebuilds the entire dialog on every frame; removed the
  distracting tick marks that appeared on the Light Output slider once Max
  Light Output was set below 76%
- macOS: Redo had two different, conflicting shortcuts (Cmd+Y and
  Cmd+Shift+Z); Cmd+Shift+Z is now the only one, matching every other macOS
  app
- Status bar: the Offline indicator dot was grey instead of red, unlike
  every other offline indicator in the app (projector cards, Monitoring
  table)
- Closing the app immediately after resizing or moving the window could
  discard unsaved project changes, because window-geometry saving could
  win a race against the unsaved-changes confirmation dialog and close the
  app before it had a chance to appear
- Pressing F5 while a refresh was already in progress could start a second,
  overlapping poll cycle across every projector instead of being ignored
- The app no longer opens off-screen if the window was last positioned on a
  monitor that's since been disconnected; the restored position is now
  checked against the displays actually connected at launch
- A saved window position on a monitor to the left of or above the primary
  display — a common multi-monitor layout — was being incorrectly discarded
  even when that monitor was still connected, reopening the window centered
  instead of restoring it
- macOS: Lens Shift "slow speed" (Ctrl+Arrow) now also works with
  Cmd+Arrow, matching what the Keyboard Shortcuts dialog already showed
- macOS: quitting via the app menu, or Cmd+Q when no window was focused,
  skipped the unsaved-changes prompt entirely, unlike every other way of
  closing the app
- The colored Cross Hatch test pattern icons (Red/Green/Blue/Cyan/Magenta/
  Yellow) showed a solid color swatch with faint grid lines instead of a
  recognizable crosshatch; they now use a black background with grid lines
  in the pattern's color

### For Developers

#### Changed
- Upgraded to Flutter 3.47.1 and Dart 3.13.1
- Windows builds now use the Impeller rendering engine by default (previously
  Skia)
- Updated flutter_svg, window_manager, package_info_plus, and other
  dependencies to their latest compatible versions
- Selection state (`isSelected`) moved out of `ProjectorNode` into a
  dedicated `SelectionNotifier` (`selection_provider.dart`), so selection no
  longer round-trips through the domain model or gets captured in undo/redo
  snapshots
- Release installers are now named with the version number
  (`ProjectorGrid_Setup_{version}.exe`, `ProjectorGrid-macOS-{version}.dmg`)
  instead of a fixed filename
- Selecting/deselecting a projector card now only rebuilds that specific
  card instead of the entire workspace grid
- Freezed's collection-immutability opt-out is now scoped to just
  `ScheduledTask` (the one model that needs it) via a per-class annotation,
  instead of disabled globally for every model via `build.yaml`
- Config-directory path construction, previously duplicated across 6
  different files, is now a single shared helper
- macOS build now uses Swift Package Manager instead of CocoaPods for
  plugin integration

## [1.3.0] - 2026-05-18

### Added
- Scheduled Tasks - automate projector commands on a once, daily, or weekly
  schedule; each task targets all projectors or a specific group and is
  managed via the new Scheduled Tasks dialog in the toolbar
- Scheduled tasks are stored inside the project file (.pgrid) so tasks always
  travel with the project they belong to; opening a different project loads
  that project's tasks automatically

### Fixed
- Opening a project file with a specially crafted filename and then saving
  could inject arbitrary commands into the OS file dialog script on Windows
  and macOS; the filename is now properly escaped before being passed to
  PowerShell and AppleScript
- OSC: a runaway show controller sending the same command address in a tight
  loop could flood the app with hundreds of concurrent projector commands per
  second; each OSC address is now rate-limited to one dispatch per 50 ms
- Loading a maliciously crafted project file containing an excessive number of
  projector nodes no longer hangs the app; files with more than 500 nodes are
  now rejected with an error in the Event Log
- Out-of-range port numbers in project files are now silently clamped to the
  valid TCP range (1-65535) instead of being passed through to socket calls
- Network scan no longer opens all 254 probe connections simultaneously;
  addresses are now checked in batches of 50, reducing peak socket usage and
  preventing resource exhaustion on constrained systems; a Cancel Scanning
  button is now available to stop the scan mid-run while keeping
  already-discovered projectors in the list
- Text field labels across all dialogs are now visually dimmed when the field
  is empty and unfocused, preventing them from being mistaken for entered
  values; the label returns to full prominence once a value is present or the
  field is focused

## [1.2.2] - 2026-05-11

### Fixed
- Workspace scrollbars no longer freeze after long sessions - on Windows and
  macOS, switching away from the app while holding Ctrl/Cmd could cause the
  key-up event to be dropped, permanently locking the scroll views into
  zoom-only mode until the app was restarted
- Polling no longer stacks up overlapping cycles when projectors are slow to
  respond; each poll now waits for the previous one to complete before
  scheduling the next, preventing runaway async operations after many hours
  of use
- Changing the polling interval in Preferences while a poll was in flight
  could spawn two concurrent poll chains; a generation counter now ensures
  only one chain is ever active
- Power on/off follow-up timers are now removed from the internal list as soon
  as they fire, preventing unbounded memory growth during long sessions with
  frequent power commands

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
