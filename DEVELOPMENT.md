# Development Guide

This document covers how to set up the development environment, understand the codebase, and contribute to Projector Grid.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) - stable channel, 3.47 or newer (requires Dart SDK `^3.13.0`, bundled with Flutter)
- A desktop target: Windows or macOS
- [Node.js](https://nodejs.org/) 24.15 or newer - only to build the Web Access page (`web_ui/`)

Verify your setup:

```bash
flutter doctor
```

## Getting Started

```bash
# Clone the repository
git clone https://github.com/zap-syr/projector-grid.git
cd projector-grid

# Install dependencies
flutter pub get

# Run code generation (required on first clone)
dart run build_runner build --delete-conflicting-outputs

# Build the Web Access page into assets/web/ (git doesn't keep it; without it
# Web Access serves a "not built" notice)
cd web_ui && npm ci && npm run build && cd ..

# Run the app in debug mode
flutter run -d windows   # or macos
```

## Project Structure

```
lib/
├── main.dart                        # Window setup, log files, ProviderScope
├── app/app.dart                     # MyApp widget (theme + root screen)
├── core/
│   ├── docs/osc_reference_html.dart # Embedded OSC reference HTML
│   ├── services/                    # Transport and platform code, no Riverpod
│   │   ├── panasonic_protocol_service.dart   # NTCONTROL over TCP
│   │   ├── isolate_protocol_service.dart     # Runs every NTCONTROL call on a worker isolate
│   │   ├── osc_service.dart                  # OSC over UDP, in and out
│   │   ├── remote_preview_service.dart       # Remote Preview WebSocket to the projector's web UI
│   │   ├── web_server_service.dart           # Web Access server (shelf)
│   │   ├── web_api.dart, web_auth.dart, ...  # Its routes, PIN sessions, SSE hub, static files
│   │   ├── desktop_notification_service.dart # Alert notifications
│   │   ├── alert_sound_service.dart          # Alert sounds
│   │   ├── app_log_file.dart, log_files.dart # Daily event and app log files
│   │   └── app_config_dir.dart               # Per-platform config directory
│   └── theme/                       # Material 3 themes, status thresholds
└── features/workspace/
    ├── domain/                      # Models and pure logic (alerts, telemetry parsing,
    │                                #   schedules, geometry, Web API DTOs, ...)
    └── presentation/
        ├── providers/               # Riverpod state (Notifier-based, codegen)
        ├── screens/                 # main_workspace_screen.dart
        └── widgets/                 # widget files, grouped by dialog or panel

web_ui/                              # The Web Access page (Svelte 5, see below)
test/                                # unit/, providers/, widgets/, helpers/, fixtures/
tool/                                # Manual scripts and the projector simulator
```

## Architecture Overview

### State Management

All state uses Riverpod (`flutter_riverpod` + `riverpod_annotation`). Providers use the `@riverpod` codegen annotation - each provider class extends a generated `_$ClassName` base and has a corresponding `.g.dart` file. **Never edit `.g.dart` files directly.**

Key providers:

| Provider | Responsibility |
|---|---|
| `workspaceProvider` | Projector node list, groups, undo/redo stack, polling timers |
| `projectStateProvider` | Current file path, dirty flag, recent projects list |
| `protocolServiceProvider` | The shared protocol service (`keepAlive`); tests override it with a fake |
| `appSettingsProvider` | Theme, polling interval, OSC, Web Access and alert settings, active view, log panel |
| `oscProvider` | OSC UDP server/client lifecycle (`keepAlive`) |
| `customCommandsProvider` | User-defined commands with auto-generated OSC slugs |
| `eventLogProvider` | Rolling event log, capped at 5000 rows (a batch command or folded repeats is one row) (`keepAlive`) |
| `scheduledTasksProvider` | Timed/recurring task list and its scheduler `Timer` (`keepAlive`) |
| `alertsProvider` | Active alerts, reconciled from workspace state by `domain/alerts.dart` (`keepAlive`) |
| `signalWatchProvider` | Signal lost detection: `QVX:NSGS1` every 2 s on powered-on projectors (`keepAlive`) |
| `alignmentProvider` | Alignment mode, and what it captured so exit puts every projector back |
| `webServerProvider` | Web Access server lifecycle, and the data source its routes read (`keepAlive`) |

The full list, with the smaller selector providers, is in `CLAUDE.md`.

### Data Models

`ProjectorNode`, `ProjectorGroup`, and `ScheduledTask` are Freezed immutable classes. When adding fields to any of them:

1. Edit the `.dart` source file.
2. Regenerate with `dart run build_runner build --delete-conflicting-outputs`.
3. Never touch the generated `.freezed.dart` files.

`CustomCommand` and `LogEvent` are plain Dart classes (no Freezed, no codegen). `CustomCommand` has manual `toJson`/`fromJson`. Extend either directly without running code generation.

Logic that can be tested on its own goes into pure functions under `domain/` (for example `telemetry_parsing.dart`, `alerts.dart`, `schedule_due.dart`) rather than into private widget or notifier methods.

### Network Protocols

**NTCONTROL** (`panasonic_protocol_service.dart`): opens a new TCP connection per command and closes it after the reply; there is no persistent socket per projector. Authentication uses an MD5 hash of a challenge token. Commands are plain-text strings (`PON` = power on, `OSH:1` = shutter close). The app's instance is an `IsolateProtocolService`, which runs every call on a worker isolate so polling doesn't stall the UI: a new public method on the service must be routed there too.

**OSC** (`osc_service.dart`): UDP-based. Receives commands on a configurable port and maps OSC addresses to projector actions. Custom commands produce slugs like `/pgrid/all/custom/dynamic-contrast` or `/pgrid/group/<group-name>/custom/dynamic-contrast`. The service also broadcasts projector status outbound (`/pgrid/status/online`, `/pgrid/status/offline`, and the unacknowledged alert counts `/pgrid/status/critical`, `/pgrid/status/warning`) to a configurable send IP and port whenever status changes, plus one `/pgrid/alert/<rule>` or `/pgrid/alert/acknowledged` message per alert change.

**Remote Preview** (`remote_preview_service.dart`): a WebSocket to the projector's own web UI on port 80 (not the NTCONTROL port), receiving about one JPEG frame per second. Design in `plan/REMOTE_PREVIEW_PLAN.md`.

**Web Access** (`web_server_service.dart`): an HTTP server in the app that serves the `web_ui/` page and its API (see below).

### Persistence

Project files, app settings and window geometry are JSON in the platform config directory, and the daily log files sit in its `logs/` folder (kept 14 days):

- Windows: `%APPDATA%\ProjectorGrid\`
- macOS: `~/Library/Application Support/ProjectorGrid/`

## Development Workflow

### Code Generation

Riverpod and Freezed both require code generation. Run this after any change to files that contain `@riverpod` or `@freezed` annotations:

```bash
dart run build_runner build --delete-conflicting-outputs
```

During active development, use watch mode to regenerate automatically:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Linting and Analysis

The project uses `flutter_lints`. Run the analyzer before committing; only `lib/` and `test/` are linted:

```bash
flutter analyze
```

### Formatting

Format all Dart files with:

```bash
dart format .
```

### Running Tests

```bash
flutter test                                        # the whole suite
flutter test test/unit/telemetry_parsing_test.dart  # one file
```

Tests live in `test/unit/` (pure logic), `test/providers/` (Riverpod, with a `ProviderContainer`) and `test/widgets/`, with shared fakes in `test/helpers/`. Two rules:

- The network is always faked: override `protocolServiceProvider` with `FakeProtocolService`. Only `test/unit/protocol_service_test.dart` opens sockets, to a loopback fake projector.
- Any test that builds a provider or the app calls `useTempConfigDir()`, otherwise it reads and can overwrite your real settings.

On Windows, `flutter_tester` occasionally crashes in the Dart VM profiler, showing as a batch of tests that "did not complete" with no error. Rerun, or use `flutter test --concurrency=1`.

### Continuous Integration

`.github/workflows/ci.yml` runs on Windows and macOS for pushes and pull requests to `main`: code generation, `dart format --set-exit-if-changed lib test`, `flutter analyze lib test` and `flutter test`. A `web` job checks that `types.gen.ts` matches `openapi.yaml`, then runs `check`, `lint`, `test` and `build` in `web_ui/`.

### Testing Without Projectors

`tool/projector_simulator.dart` runs fake NTCONTROL projectors on loopback addresses
(127.0.0.1, 127.0.0.2, …, port 1024) and writes a matching project file:

```bash
dart run tool/projector_simulator.dart                 # 6 projectors
dart run tool/projector_simulator.dart 12              # any count up to 250
dart run tool/projector_simulator.dart --demo-errors   # start with self-diagnosis codes set
dart run tool/projector_simulator.dart 16 --base=192.168.0.101   # LAN-looking addresses
```

Open the printed `.pgrid` path via File → Open. The simulated projectors answer the
poll cycle and track power, shutter, input, test pattern, shutter fade, Edge Blending
and Geometry registers, so controls, Monitoring, Alignment mode and the dialogs all work.
Commands they receive are printed; Ctrl+C stops them.

While it runs, type into its console to test alerts and connection states:

```
err 3 F305 U200     projector 3 reports these self-diagnosis codes
clear all           remove them
sig 3 off | on      input signal gone / back (sig all blip: a short dropout)
net 3 off | on      network cable out / back in
list                who reports what
```

On macOS, add loopback aliases first. `--base` needs its addresses to exist on the
machine (a loopback adapter on Windows, `lo0` aliases on macOS). The script's header
has the commands for both.

### Web Access page (`web_ui/`)

The page phones and laptops open when Web Access is on: Svelte 5 + TypeScript, built
with Vite into `assets/web/`, which the app bundles and serves. The API between them is
`web_ui/api/openapi.yaml`; the Flutter tests write golden fixtures to
`test/fixtures/api/` and the web tests check them against it, so a field changed on one
side only fails CI. Run these in `web_ui/`:

```bash
npm ci                # install (first time, or after package-lock.json changes)
npm run dev:mock      # page + a fake API (no app needed) - Viewer PIN 1234, Operator 5678
npm run dev           # page with /api proxied to the running app on port 8080
npm run gen:api       # regenerate src/lib/api/types.gen.ts after editing openapi.yaml
npm run check         # svelte-check, warnings fail
npm run lint          # ESLint + Prettier check (npm run format fixes formatting)
npm test              # Vitest, including the contract test
npm run build         # into ../assets/web/; rerun the app, it bundles them when built
```

After changing what the API returns, regenerate the fixtures:
`flutter test --update-goldens test/unit/web_api_dto_test.dart`.

## Building for Release

```bash
(cd web_ui && npm ci && npm run build)   # first: the Web Access page
flutter build windows --release
flutter build macos --release
```

Releases are automated via GitHub Actions (`.github/workflows/release.yml`). Pushing a tag in `v*.*.*` format first runs the full CI workflow (`ci.yml`) on the tagged commit; only if it passes does it build for Windows and macOS (the Web Access page is built first) and create a GitHub Release with the installer and DMG attached and the tag's section of `CHANGELOG.md` as its notes. The assets keep fixed names (`ProjectorGrid_Setup.exe`, `ProjectorGrid-macOS.dmg`), so README.md's `releases/latest/download/` links always point at the newest release and never need updating.

## Contributing

All contributions are welcome - bug reports, feature requests, and code changes.

Before opening a pull request, please open an issue first to discuss the change. This avoids duplicate effort and keeps the scope of PRs focused.

### PR Checklist

For new PRs, please go through the following checklist:

- [ ] `flutter analyze` reports no issues.
- [ ] `dart format .` has been run and all changed files are formatted.
- [ ] `flutter test` passes, and new logic comes with tests.
- [ ] If `web_ui/` changed: `npm run check`, `npm run lint` and `npm test` pass there.
- [ ] The branch is clean: commits are logically separated and have descriptive messages.
- [ ] The PR body describes what changed and why.

Once the checklist is complete, request a review from one of the maintainers. We will review as soon as possible.

### Commit Style

Use short, imperative subject lines that describe the change:

```
feat: add lens-shift preset saving
fix: reconnect after TCP timeout
refactor: extract polling logic into separate class
```

Common prefixes: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.

### Code Conventions

- Follow Dart/Flutter idioms and the rules enforced by `flutter_lints`.
- Keep providers and widgets focused - one responsibility per file.
- Use Freezed for `ProjectorNode`, `ProjectorGroup` and `ScheduledTask`; other state classes (`AppSettings`, `ProjectState`, `CustomCommand`) are plain Dart. Do not mutate state directly in either case.
- Do not add fallback handling or validation for cases that cannot occur at runtime.
- Comments should explain *why*, not *what* - well-named identifiers already do that.
