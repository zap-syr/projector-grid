# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.0.0] - 2026-10-25

This version brings a massive update to the app: a full redesign of every
window, dialog and panel, and a lot of new functions. Telemetry alerts with
desktop notifications and sound, a Web Access page for phones, tablets and
laptops on the show network, Alignment mode, Edge Blending, a new Monitoring
view and daily log files for the night after the show.

### For Users

#### Added
- **Web Access**: a web page served by the app itself, so any phone, tablet
  or laptop on the show network can watch and control the projectors without
  installing anything. Turn it on in Preferences, Web Access (port 8080 by
  default) and open the address shown there
  - Two roles with their own PIN: a **Viewer** sees status, alerts and live
    updates; an **Operator** (only while *Allow control* is on) can also
    send power, shutter, OSD, input, test pattern and lens commands, run
    Alignment mode and refresh every projector's status. A viewer can
    *Unlock control* with the Operator PIN and *Lock* again
  - Sessions last 12 hours idle; five wrong PINs lock that address out for
    a while, doubling on each repeat. Preferences lists the signed-in
    clients with their role, signs one out or *Sign out all clients*; the
    status bar shows how many are connected
  - Three views: a table with the Monitoring columns (sort, show and hide,
    presets, reorder, resize, fit to width, density, grouping), cards in
    Compact or Extended size, and a Map of the project's card layout with
    zoom and marquee selection
  - Search and quick filters (All, Online, Attention, Offline, Standby),
    select presets (Online, Attention, Standby, Invert, a group); selected
    projectors hidden by a search or filter stay selected and every command
    names them before it goes out
  - A projector details panel, Remote Preview with Pre-show, the Active
    alerts panel with acknowledge, alert sounds, a new-alert toast and a
    count in the browser tab
  - Layouts for desktop, tablets upright and sideways, and phones upright
    and sideways, with a PIN pad and touch-sized controls on touch screens;
    light, dark or system theme
  - Fully offline: fonts and icons are bundled, nothing is loaded from the
    internet
  - The same API serves scripts and show controllers: `POST /api/login`
    with a PIN, then a bearer token
- **Telemetry alerts**: the app now watches the projectors for you
  - Rules, each with its own switch in Preferences, Alerts: *Offline*,
    *Projector error* (the projector's self-diagnosis codes, decoded into
    names such as "Fan error (F305)"), *Signal lost*, *Intake temperature*
    and *Exhaust temperature* (warning and critical thresholds with a 2 °C
    hysteresis)
  - *Signal lost* is checked every 2 seconds on powered-on projectors, so
    even a short dropout is caught. It stays until acknowledged and shows
    how long the signal was gone ("Back after 3 s")
  - An alert badge on each projector card with its own alert panel, the
    *Active alerts* panel from the status bar (grouped by projector or by
    alert, by project group, filters, *Acknowledge all*), alert tints in
    Monitoring
  - Desktop notifications (with the severity icon on Windows) and two alert
    sounds, each for all alerts or critical ones only; a notification click
    brings the window forward on Active alerts
  - OSC: `/pgrid/alert/<rule>` on every alert change,
    `/pgrid/alert/acknowledged`, and `/pgrid/status/critical` /
    `/pgrid/status/warning` with the counts of unacknowledged alerts
- **Alignment mode** (`Ctrl/Cmd+L`, or Tools, Alignment Mode): work through a
  wall one projector at a time. The focused projector shows its alignment
  pattern, the others close their shutter or show their own pattern;
  `<` / `>` step through the projectors in layout order, *Neighbours* (`N`)
  also opens the projectors next to it, *Show all* (`A`) opens every one.
  Presets *Geometry*, *Color* and *Custom* choose the patterns, *Adjust*
  opens Geometry, Color, Brightness or Edge Blending for the focused
  projector. Leaving the mode puts every shutter, pattern and shutter fade
  back as it was, also when the app quits
- **Edge Blending** dialog (projector right-click, Edge Blending): Off / On /
  User, each edge with Start and Width on a canvas with draggable zones and
  limits that keep opposite edges from crossing, Markers and Auto test
  pattern toggles. Two projectors open as a pair side by side or stacked,
  with the overlap shown and *Link* to send Width and the overlapped black
  level to both. A *Black Level* tab sets the overlapped, border and
  non-overlapped areas per R, G and B
- **Geometry Correction preview** in Keystone and Curved Correction, drawn
  from camera measurements of a real projector; Corner Correction draws the
  Linearity and Pincushion warp and uses the wider inward range of Quad
  Pixel Drive models
- **Test pattern indicator**: the active test pattern is polled and shown
  as a thumbnail on the projector card and in Monitoring
- **Quick status** popover: select one projector card and press `Space` to
  see its power, shutter, input, signal, temperatures and alerts, with
  *Show in Monitoring* and *Remote Preview*
- **Monitoring**: search (`Ctrl/Cmd+F`), quick filters with counts, Table and
  Cards views (Compact and Extended), a projector panel with every reading,
  its alerts and since when, *Preview*, *Web UI* and *Locate*
- **Event log**: filter chips (All, Alerts, Commands, Connection, OSC, Web),
  search, a command sent to several projectors as one row that opens to
  each projector's result, *Retry failed*, repeats folded with a count,
  *Locate* a projector on the canvas, *Follow* for new events, a resizable
  panel whose height is remembered
- **Log files**: every Event Log line is also written to a daily file, and
  the app's own internal errors to a second one, both kept for 14 days
  (`%APPDATA%\ProjectorGrid\logs\` on Windows,
  `~/Library/Application Support/ProjectorGrid/logs/` on macOS). Help, Open
  Logs Folder opens them, ready to send with a bug report
- **Scheduled tasks** can target several groups at once
- **Add Projectors** remembers the last login and password used; **Edit
  Projector** can change the port and masks the password
- **Keyboard Shortcuts** has a search field; `Ctrl/Cmd+G` selects the whole
  group of the selected projector
- **About** shows the version and build with links to the release notes,
  the project page, bug reports, the licenses and support

#### Changed
- **Full redesign** of the main window: a new toolbar with group and task
  counts that turns to icons in a narrow window, a control bar in cards
  (Power, Shutter and OSD rows, lens cross with Home position in its header,
  Focus and Zoom, a folded Lens setup, test pattern favourites as
  thumbnails), new projector cards (header tinted by power state, *Offline*
  and *Login failed* in words, the group as a band inside the card), a new
  status bar (online meter, alert counts, OSC and Web state, last update)
  and new tooltips
- **Every dialog redesigned**: Add Projectors (Address, IP range with a
  preview of the addresses, Discover with a manual Scan), Edit Projector,
  Groups (inline editing, 48 colours, which tasks a delete pauses),
  Scheduled Tasks (one window with the list and the editor, a command
  picker with search), Brightness Control (mode tiles, 0.1 % steps, hold to
  repeat), Color Correction (one colour at a time, presets for colour
  temperature), Geometry Correction, Remote Preview, Custom Command (shows
  both OSC addresses and which command holds a taken one), Keyboard
  Shortcuts, About and Preferences (sections in a sidebar). Dialogs show
  the projector's model, IP, group and live status in their title bar and
  fit windows down to 800 × 600
- Confirmations share one dialog that says what will change
- New fonts: Inter for the interface, IBM Plex Mono for addresses, ports
  and commands
- **Monitoring** has fewer, two-line columns (Projector, Group, Power,
  Shutter, Input and signal, Temperature, Runtime, AC, Errors, Connection,
  Test pattern), group rows with a summary, coloured stripes on problem
  rows and offline rows shown dimmed with the time they were last seen.
  Saved column layouts start over with the new columns. The Serial number
  column is gone: the serial is in the projector panel, and it is read
  only on first contact, after an edit or after a projector comes back
- Power is read with `QVX:POWI1`, so cards and Monitoring show *Warming
  up* and *Cooling*; the signal is read again once a projector has warmed
  up
- Color Correction reads only the values of the active method and mode,
  and reads them in small batches, so weaker projectors no longer answer
  some reads with an error and show defaults
- Polling runs on a background worker and skips updates that change
  nothing, so large projects no longer make the window stutter; it also
  keeps its full rate while the window is in the background, so alerts and
  the Web Access page stay current
- **A one-time scheduled task that was missed no longer runs late**: if the
  app wasn't running at its time (more than 2 minutes ago), it is listed
  under *Completed* as "Not run" with *Schedule again*, instead of firing
  the moment the app opens
- Deleting a group removes it from scheduled tasks; a task left without a
  group is paused instead of running and matching nothing. Undo brings the
  group back to its tasks and resumes them
- File, Exit now does what `Ctrl/Cmd+Q` does: it also leaves Alignment mode
  before closing

#### Fixed
- OSC status feedback on Windows no longer silently drops messages: the
  `/pgrid/status/offline` and `/pgrid/status/warning` updates sent right
  after `/pgrid/status/online` often never reached the show controller
- Color Correction's white balance shows the values of the User mode you
  switch to, instead of keeping the ones read when the dialog opened
- macOS: the window is opaque again, so the title bar no longer shows what
  is behind the window
- Trackpad on the canvas (macOS and Windows Precision Touchpad): a
  two-finger scroll scrolls instead of drawing a selection marquee or
  dragging a card, and a pinch zooms around the fingers. A click-drag on
  the trackpad still selects and moves cards
- Adding, renaming or recolouring a group, or changing its OSC address, now
  marks the project as unsaved, so closing the window asks to save instead
  of losing the group edits
- An offline projector whose port opens but that doesn't answer yet (still
  booting, or busy) stays Offline, instead of flashing online on every poll
- A busy projector's error reply is no longer shown as a reading: an AC
  voltage of "3V", a runtime of "ERR3H" or "ERR3" in the Errors column
- An IP address with leading zeros (`192.168.0.010`) is refused when adding
  or editing a projector; it slipped past the duplicate check and never
  connected

### For Developers

#### Added
- `web_ui/`: the Web Access page (Svelte 5, Vite, TypeScript), built into
  `assets/web/` and bundled with the app; `api/openapi.yaml` is the API
  contract, with golden JSON fixtures shared by the Dart and web tests
- Web server on `shelf` / `shelf_router` (`web_server_service.dart`), PIN
  sessions and an SSE hub; desktop notifications with
  `flutter_local_notifications`, sounds with `audioplayers`
- `IsolateProtocolService`: every NTCONTROL exchange runs on a worker
  isolate, which survives an uncaught error and reports it
- `AppLog` (`core/services/app_log_file.dart`): the event log and app log
  files; `FlutterError.onError`, `PlatformDispatcher.onError` and
  `debugPrint` go to the app log
- Test suite (unit, provider and widget tests, over 1,000 of them) and a CI
  workflow on Windows and macOS, plus a `web` job; the release workflow
  builds `web_ui/` before the app
- `tool/projector_simulator.dart` (loopback projectors with error codes,
  signal loss and network drops, or LAN-looking addresses with `--base`),
  `tool/geometry_measure/` (the camera
  measurement behind the Geometry preview), Edge Blending probe scripts
- The shared dialog parts in `presentation/widgets/common/` and the
  `projector-grid-visual-rules` skill

#### Changed
- Monitoring's column catalogue, status labels and temperature thresholds
  are shared by the app and the Web API
- NTCONTROL error codes are matched exactly instead of by the `ER` prefix
- Dependencies updated for Flutter 3.47.8
- `tool/projector_simulator.dart` keeps running on macOS when a client
  resets its connection

## [1.4.2] - 2026-09-16

### For Users

#### Added
- Remote Preview — see a projector's live input signal without
  opening its web UI: right-click a projector, a group, or a multi-selection
  and choose Remote Preview. A single projector opens as one large preview;
  more than one opens as a scrollable grid, each tile showing its own
  shutter-coloured frame border, name/IP caption, and a live signal tag
  (input, resolution/frame rate). Test pattern and aspect-mismatch are called
  out with a corner tag; a "No signal" / "HDCP-protected content" /
  "Starting up" / "Image rotating" message shows in place of the frame when
  there's nothing to preview yet
- Pre-show mode — a switch in the Remote Preview dialog that keeps a Standby
  projector's input signal alive for preview without powering the projector
  on; toggle it for one projector, or for every eligible (Standby, connected)
  projector in a group/multiview at once. Only available once that
  projector's preview feed has actually connected
- Monitoring table: drag a column header to reorder it, drag its edge to
  resize it, or double-click that edge to auto-fit it to its content; row
  density presets (Compact/Standard/Comfortable); a "Merge into groups" view
  that groups rows under their assigned group; a new Light Runtime column and
  coloured temperature/status cells. Column visibility, presets
  (Essentials/Thermal/Signal), and a "show all columns" option are available
  from View ▸ Monitoring Table
- Control bar: the Input selector is now a dropdown covering every known
  projector input instead of a fixed set of buttons, and a new labeled
  dropdown was added for lens calibration presets

#### Changed
- Every dialog now shares the same title bar — a title and a close button
  (✕) in the top-right corner — instead of the mix of "Close" buttons and
  stray X icons different dialogs used before, Preferences included; the
  Add Projectors, Manage Groups, and Scheduled Tasks dialogs also moved their
  primary action button out of the title bar into a right-aligned footer
  button. The dialog body now sits one tone apart from that header band
  instead of matching it exactly, so the two read as separate layers instead
  of blending together
- Geometry Correction's Correction Mode selector is now a segmented button
  instead of a dropdown, matching the rest of the app's mode toggles

#### Fixed
- A single projector telemetry query timing out during a poll (e.g. the
  errors query) no longer shows the raw failure text in the Monitoring table
  or logs a false hardware-error event — that field now keeps its last known
  value until the next successful poll instead
- A zoomed/selected projector card's hover area no longer stops short of its
  actual (scaled-up) visual bounds
- macOS menu bar no longer rebuilds on every telemetry poll tick
- The New/Edit Group dialog no longer leaks a text field controller each
  time it's opened
- Light theme's accent colour (Save/primary buttons, the active tab,
  selected segmented options) is a real blue again instead of a muted grey —
  a side effect of 1.4.1's softer, less-saturated surface colours that ended
  up desaturating the accent along with them
- Top menu bar: every dropdown item's label now starts at the same left
  edge, whether or not it shows a checkmark, instead of checkable items
  (Controls, Show Logs, column toggles, …) sitting further right than plain
  ones in the same menu

### For Developers

#### Added
- `RemotePreviewController` (`core/services/remote_preview_service.dart`) — a
  `dart:io` `WebSocket` client for the projector's `ws://<ip>/remotepreview`
  RemoView endpoint (subprotocol `pj-cast-protocol`), reduced to a
  `RemotePreviewState` stream (`RemotePreviewConnecting` /
  `RemotePreviewFrame` / `RemotePreviewNotice` / `RemotePreviewUnavailable`)
  plus a `signalEvents` stream fired on the socket's `SIGNAL` message
- `ProjectorWebStatusService` (`core/services/projector_web_status_service.dart`)
  — HTTP digest-auth client for the projector's own
  `/cgi-bin/simple_status_hidden.cgi` status page, used as the Standby-safe
  signal source NTCONTROL's `QIN`/`QVX:NSGS1` can't provide (they return
  `ER401` outside full power)
- `remotePreviewProvider` and `previewSignalStatusProvider` (family providers
  per projector) drive `RemotePreviewDialog`/`PreviewViewport`;
  `WorkspaceNotifier.refreshNode`/`applyWebSignal`/`claimNodeForExternalPoll`
  let the preview feed refresh a single node's telemetry without racing the
  regular poll cycle
- Shared `DialogTitleBar` widget (`presentation/widgets/dialog_title_bar.dart`)
  used by every dialog

#### Fixed
- Discovered-projector list in Add Projectors no longer logs a `ListTile`
  "no Material ancestor" ink warning to the debug console
- Light theme's `primary`/`onPrimary`/`secondaryContainer`/
  `onSecondaryContainer` are re-derived from the seed colour through
  `DynamicSchemeVariant.tonalSpot` (the variant dark mode already uses) and
  layered onto the neutral scheme via `.copyWith(...)`, instead of inheriting
  the neutral variant's desaturated values along with the surface tones

#### Changed
- `tool/projector_polling_test.dart` updated for `pollProjectorTelemetry`'s
  `(ProbeResult, Map?)` tuple return
- `app_theme.dart`: `ThemeData.dialogTheme.backgroundColor` now set to
  `colorScheme.surfaceContainerLow`, one step off `DialogTitleBar`'s
  `surfaceContainerHigh` on the same container ramp

## [1.4.1] - 2026-09-07

### For Users

#### Changed
- Light theme now uses a softer grey surface ramp and a neutral color scheme
  variant instead of a more saturated one
- Popup menus and dropdowns now have a visible border and drop shadow, making
  them easier to distinguish from the content behind them
- General app optimization and performance improvements: reduced unnecessary
  UI repaints and rebuilds while dragging projector cards, marquee-selecting,
  and during telemetry polling; per-projector network concurrency during
  polling is now capped and scales down automatically for larger projects,
  avoiding overwhelmed projector hardware or exhausted OS connection limits;
  polling now automatically slows down while the window is minimized or
  unfocused, and pulls a fresh update when you return after being away

#### Fixed
- OSC: changing the receive port, network device, or send IP/port in
  Preferences while OSC was enabled now takes effect immediately instead of
  requiring a restart; the "OSC enabled" setting is also now correctly
  restored on launch; if OSC can't bind its receive port (e.g. it's already
  in use) the failure is now logged instead of silently showing as enabled
- Action commands (power, shutter, input, etc.) sent to a device that fails
  the NTCONTROL handshake are no longer reported as successful
- Manual refresh (F5 / the Refresh menu item) now correctly resets the
  automatic polling countdown; the polling interval in Preferences is now
  clamped to a safe 30-3600 second range
- A corrupted or malformed custom command entry no longer discards every
  other saved custom command - only that entry is skipped
- Protected-mode projectors returning a challenge token in an unexpected
  format now report an explicit authentication error instead of silently
  sending a command that gets rejected without explanation
- Editing a projector on a non-default port now reconnects using that
  projector's actual port instead of always assuming port 1024
- Deleting a group now also warns if any scheduled tasks target it, since
  those tasks would otherwise keep running on schedule but silently match
  nothing afterward
- Intake/exhaust temperature now displays correctly for projectors that
  report a single value instead of the usual Celsius/Fahrenheit pair
- Opening the Open/Save As dialog now logs a clear error in the Event Log if
  the native file picker itself fails to launch, instead of failing silently
- Brightness Control, Color Correction, and Geometry Correction dialogs now
  show a notification when a command fails to send, instead of failing
  silently

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
