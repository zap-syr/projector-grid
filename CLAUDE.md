# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (Windows desktop)
flutter run -d windows

# Build for Windows
flutter build windows

# Analyze for lint/type errors
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Regenerate code after modifying annotated files (freezed models, riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs
```

## Architecture Overview

This is a **Flutter desktop app** (Windows/macOS) for managing and controlling Panasonic projectors over TCP/IP using the Panasonic NTCONTROL protocol.

### Layer Structure

The app uses a single feature (`workspace`) with a clean layered structure:

- **`lib/core/`** — Shared services and theme
  - `services/panasonic_protocol_service.dart` — All projector TCP communication
  - `services/osc_service.dart` — OSC UDP listener/sender (incoming commands → NTCONTROL, outgoing status)
  - `theme/app_theme.dart` — Material 3 light/dark themes

- **`lib/features/workspace/`**
  - `domain/projector_node.dart` — The core `ProjectorNode` model (Freezed immutable data class with enums: `PowerStatus`, `ShutterStatus`, `ConnectionStatus`)
  - `presentation/providers/workspace_provider.dart` — The single Riverpod `WorkspaceNotifier` that holds all state
  - `presentation/providers/osc_provider.dart` — `OscNotifier` (`@Riverpod(keepAlive: true)`) wiring `OscService` to workspace
  - `presentation/providers/app_settings_provider.dart` — Persisted app settings (polling interval, theme, OSC config)
  - `presentation/screens/main_workspace_screen.dart` — Root screen, toggles between two views
  - `presentation/widgets/` — All UI widgets

### State Management

Everything is managed by a single `@riverpod` class: `WorkspaceNotifier` (provider: `workspaceProvider`). It holds `List<ProjectorNode>` as its state. All mutations go through this notifier.

Key behaviors:
- **Polling**: Auto-polls all projectors every 60 seconds via `Timer.periodic`. Connected nodes get full telemetry; offline nodes get a simple TCP ping.
- **Optimistic UI**: Power/shutter commands update state immediately before server confirmation.
- **Immutable state**: Always reassign `state = state.map(...).toList()` — never mutate in place.
- **`onStateChanged` hook**: Nullable `VoidCallback` on `WorkspaceNotifier`. Called after every state-affecting mutation (add/delete, undo/redo, optimistic updates, polling results). Used by `OscNotifier` to push real-time status over UDP.
- **Groups**: `WorkspaceNotifier` holds a `List<ProjectorGroup>` alongside projector state. Groups have a name, `oscAddress` (e.g. `/group/stage`), and list of projector IDs. `sendCommandToGroup(groupId, cmd)` and `sendCommandToAll(cmd)` send NTCONTROL commands with optimistic UI.

### Two Main Views

Toggled via `SegmentedButton` in `MainToolbar`:
1. **Controls view** (grid): `ProjectorWorkspace` + `ControlBar` side panel
   - `ProjectorWorkspace`: Infinite scrollable canvas (3000×3000) with zoom (50%–200%), draggable `ProjectorCard` nodes, marquee selection, grid snapping (20px grid)
   - `ControlBar`: Sends commands to selected projectors (power, shutter, OSD, inputs, lens shift, focus, zoom, test patterns)
2. **Monitoring view** (table): `MonitoringTable` — tabular display of all projector telemetry

### Panasonic NTCONTROL Protocol

`PanasonicProtocolService` communicates over raw TCP (default port 1024). Each command opens a new socket connection.

Authentication handshake:
1. Projector sends `NTCONTROL 1 <8-char-hex-token>` (or `NTCONTROL 0` for no auth)
2. Client responds with `MD5(login:password:token)` prepended to command

Key commands used: `QID` (model), `QSN` (serial), `QPW` (power), `QSH` (shutter), `QIN` (input), `QVX:NSGS1` (signal), `QVX:RTMS1` (runtime), `QTM:0/1` (temps), `QVX:VMOI2` (voltage), `QVX:ERRS2` (errors)

Action commands: `PON`/`POF` (power on/off), `OSH:0/1` (shutter open/close), `IIS:*` (input select), `OTS:*` (test patterns), `VXX:LNSI*` (lens/focus/zoom motor control)

### OSC Protocol

`OscService` listens on a configurable UDP port and sends status over UDP.

**Incoming** — address patterns handled:
- `/pgrid/all/{command}` — send NTCONTROL command to all projectors
- `/pgrid/group/{group-name}/{command}` — send to a named group (resolved via `oscAddress`)
- `/pgrid/status` — force-send all 3 current status values immediately

**Outgoing** — 3 messages sent whenever their value changes:
- `/pgrid/status/online` — count of connected projectors
- `/pgrid/status/offline` — count of offline projectors
- `/pgrid/status/warning` — count with errors or unauthorized status

Change detection: `_lastOnline/Offline/Warnings` cached; only changed values are transmitted. `sendStatusForced()` bypasses this for on-demand requests.

`OscNotifier` uses `@Riverpod(keepAlive: true)` — the provider (and its UDP socket) lives for the entire app lifetime. OSC is configured in Preferences → OSC tab (network device, receive port, send IP, send port).

**Command map**: Full map in `osc_service.dart` covering power, shutter, OSD, inputs, lens shift/home/calibration, focus, zoom, test patterns, picture mode, back color, startup logo, projection method, shutter fade in/out, quad pixel drive.

### Code Generation

Three files are auto-generated and should not be edited manually:
- `lib/features/workspace/domain/projector_node.freezed.dart` — from `@freezed` annotation
- `lib/features/workspace/presentation/providers/workspace_provider.g.dart` — from `@riverpod` annotation
- `lib/features/workspace/presentation/providers/osc_provider.g.dart` — from `@Riverpod(keepAlive: true)` annotation

Run `build_runner` after any changes to `projector_node.dart`, `workspace_provider.dart`, or `osc_provider.dart`.

### Workspace Interaction Model

- **Click** node: select (deselects others)
- **Ctrl/Cmd + click**: multi-select toggle
- **Ctrl/Cmd held + drag** on canvas: marquee box selection (scrolling is disabled during this)
- **Ctrl/Cmd held + scroll wheel**: zoom
- **Middle mouse drag**: pan the canvas
- **Drag node**: move it; on `onPanEnd` it snaps to 20px grid
- **Right-click** node: context menu with the following items:
  - **Edit** — open the projector edit dialog
  - **Brightness Control** — open brightness control dialog
  - **Color Correction** — open color correction dialog
  - **Open in Browser** — opens `http://{ipAddress}` in the system default browser
  - *(divider)*
  - **Assign to Group** — submenu listing all groups; assigns/removes the node from a group
  - *(divider)*
  - **Delete** — multi-select aware: if the right-clicked node is part of a multi-selection, all selected nodes are deleted together with a count in the confirmation dialog
- **Delete key**: delete selected nodes (with confirmation dialog)

### Tool Scripts

Standalone Dart scripts in `tool/` (not Flutter tests, run with `dart tool/<file>.dart`):
- `tool/osc_codec_test.dart` — OSC encode/decode roundtrip + UDP loopback test
- `tool/osc_test.dart` — End-to-end integration: sends OSC commands to the running app on port 8000, listens for status replies on port 9000
- `tool/projector_protocol_test.dart` — Manual TCP connection test against a real projector
- `tool/projector_polling_test.dart` — Manual polling simulation against a real projector

### Assets

SVG icons in `assets/icons/` for directional buttons (up/down/left/right × slow/normal/fast). Loaded via `flutter_svg`.
