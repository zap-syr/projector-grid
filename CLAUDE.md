# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Projector Grid is a Flutter **desktop** app (Windows + macOS only) for controlling and monitoring multiple
Panasonic projectors over a local network. It talks two protocols: **NTCONTROL** over TCP to each projector,
and **OSC** over UDP to/from show-control systems.

See `DEVELOPMENT.md` for the contributor-facing setup guide; this file is the quick reference for working in the code.

## Commands

```bash
# First clone / after pulling changes to @riverpod or @freezed files
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # auto-regen during active work

flutter run -d windows        # or: -d macos
flutter analyze               # must be clean before committing
dart format .                 # must be run before committing
flutter test                  # full suite: test/unit, test/providers, test/widgets
flutter test test/unit/telemetry_parsing_test.dart   # a single file

flutter build windows --release
flutter build macos --release
```

```bash
# Web Access page (web_ui/, Svelte 5 + Vite; Node 24.15+) — run inside web_ui/
npm ci
npm run dev:mock      # page + fake API from mocks/, no app needed (PINs 1234 / 5678)
npm run dev           # /api proxied to the running app on :8080
npm run gen:api       # after editing api/openapi.yaml → src/lib/api/types.gen.ts
npm run check && npm run lint && npm test   # all must pass before committing
npm run build         # → ../assets/web/ (gitignored; the app bundles it)

# After changing a Web API JSON shape: rewrite the golden fixtures the web contract test reads
flutter test --update-goldens test/unit/web_api_dto_test.dart
```

Code generation is mandatory: every `@riverpod` provider and every `@freezed` model has a generated
`.g.dart` / `.freezed.dart` sibling. **Never edit generated files.** If a build fails right after pulling,
re-run `build_runner` first.

### Tests (`test/`)

- `test/unit/` pure logic, `test/providers/` Riverpod (`ProviderContainer`), `test/widgets/`
  widget tests; shared fakes and harnesses in `test/helpers/`.
- Network is always faked: override `protocolServiceProvider` with `FakeProtocolService`.
  Only `test/unit/protocol_service_test.dart` touches sockets (a loopback
  `FakeProjectorServer`).
- **Any test that builds a provider or the app must call `useTempConfigDir()`** — otherwise
  it reads and can overwrite the real user's settings in the platform config dir.
- Widgets branch on `defaultTargetPlatform == TargetPlatform.macOS`, never `dart:io` `Platform.isMacOS`:
  tests run as a non-Mac target on every host, so the macOS CI runner sees the same tree as Windows.
- Keep logic testable by putting it in pure functions under `domain/` (see
  `telemetry_parsing.dart`, `geometry_values.dart`, `schedule_due.dart`) rather than private
  widget/notifier methods.
- On the dev laptop `flutter_tester.exe` can crash with the same Dart VM profiler AV as the
  debug app (see below) — a batch of "did not complete" tests with no error. Rerun, or use
  `flutter test --concurrency=1`.
- CI (`.github/workflows/ci.yml`) runs codegen, `dart format --set-exit-if-changed lib test`,
  `flutter analyze lib test` and `flutter test` on Windows and macOS, and a `web` job that
  checks `types.gen.ts` matches `openapi.yaml`, then `check`, `lint`, `test` and `build`
  in `web_ui/`. The release workflow builds `web_ui/` before the Flutter build.

### Standalone protocol scripts (`tool/`)

`tool/*_test.dart` are **not** `flutter test` files — they are manual integration scripts run with
`dart run tool/<name>.dart`. Several have hard-coded projector IPs / OSC ports near the top that you edit
before running. `tool/osc_test.dart` requires the app to be running with OSC enabled.
`tool/projector_simulator.dart [count]` is the opposite direction: it runs fake projectors on
127.0.0.1…N (port 1024; `--base=<ip>` starts elsewhere, e.g. LAN-looking addresses for screenshots) and writes a matching `.pgrid` to the temp dir — open it in the app to
test polling, controls and Alignment mode without hardware (macOS needs `lo0` aliases, see its header).
It also takes `ERRS2` error codes for alert testing: `--demo-errors` at start, or `err 3 F305` /
`clear all` / `list` typed into its console while it runs.
`tool/svg2png/` is a Node helper for regenerating lens-shift icons; `tool/generate_icon.dart` builds the app icon.
`tool/geometry_measure/` is Python (own venv, see its README): it films a projector's Keystone / Curved
Correction with a webcam and fits `geo_model.py`, the reference model for the Geometry preview
(`plan/GEOMETRY_PREVIEW_PLAN.md`); `export_fixture.py` writes the preview's test fixture.

## Architecture

### Layering

Feature-first under `lib/features/workspace/`:

- `domain/` — models. `ProjectorNode`, `ProjectorGroup`, `ScheduledTask` are **Freezed** immutable classes
  (add a field → edit `.dart` → run `build_runner`). `CustomCommand` and `LogEvent` are **plain Dart**
  (no codegen; `CustomCommand` has hand-written `toJson`/`fromJson`).
- `presentation/providers/` — all state, Riverpod `@riverpod` codegen Notifiers.
- `presentation/{screens,widgets}/` — UI. `main_workspace_screen.dart` owns the top-level `Shortcuts`/`Actions`
  tree and the window-close flow.

`lib/core/` holds cross-cutting services (protocols, theme, config-dir, embedded OSC docs). `lib/main.dart`
does window setup; `lib/app/app.dart` is just `MaterialApp` + theme.

### State (Riverpod)

| Provider | Responsibility |
|---|---|
| `workspaceProvider` | projector node list, group assignments, undo/redo stack, polling timers, optimistic-update timers |
| `projectStateProvider` | current file path, dirty flag, recent-projects list |
| `protocolServiceProvider` | the shared `PanasonicProtocolService` (`keepAlive`); a provider so tests can override it with a fake |
| `appSettingsProvider` | theme mode, polling interval, OSC port/enabled, which view is active, log panel visibility |
| `oscProvider` | OSC UDP server/client lifecycle (`keepAlive`) |
| `customCommandsProvider` | user-defined commands + auto-generated OSC slugs |
| `eventLogProvider` | rolling event log, capped at 5000 *rows* (`keepAlive`): a batch command or a run of folded repeats is one row however many events it holds (`capLogRows` in `domain/event_log_rows.dart`) |
| `scheduledTasksProvider` | timed/recurring task list + its scheduler `Timer` (`keepAlive`) |
| `selectionProvider` / `pollStatusProvider` | current card selection; per-projector poll-in-flight state |
| `editHistoryStatusProvider` / `statusSummaryProvider` | small derived/selector providers (undo-redo availability for the Edit menu; online/offline/warning counts for the status bar) that dedupe by structural equality so they don't rebuild on every telemetry tick |
| `alertsProvider` | active alerts (`keepAlive`), reconciled from workspace state and the signal watch by pure functions in `domain/alerts.dart` |
| `signalWatchProvider` | Signal lost detection (`keepAlive`): `QVX:NSGS1` every 2 s on powered-on projectors while the rule is on, staggered, at most 16 in flight, skipping nodes `WorkspaceNotifier.isNodeBusy`; logic in `domain/signal_watch.dart` |
| `alertNotificationsProvider` | turns raised alerts into desktop notifications and the alert sound (`keepAlive`), batching alerts raised close together; the services behind it are in `alert_delivery_providers.dart` so tests can fake them |
| `alignmentProvider` | Alignment mode: the focused projector, neighbours/others patterns, and what entry captured so exit puts every shutter and pattern back; holds no widget state so the web page drives it too |
| `remotePreviewProvider` / `previewSignalStatusProvider` | per-projector "Remote Preview" (RemoView) WebSocket feed and its web-UI-driven signal status — see `remote_preview_service.dart` below |
| `preShowProvider` | one projector's Pre-show state while a Remote Preview of it is open in the app or on a web page (not `keepAlive`) |
| `webServerProvider` / `webClientsProvider` | Web Access server lifecycle (`keepAlive`), also the `WebApiSource` its routes read from; the signed-in clients for the status bar and Preferences |
| `monitoringViewProvider` / `monitoringFilterProvider` / `monitoringPanelProvider` | Monitoring layout (saved to `monitoring_view.json`), search and quick filter (session only), the open projector panel |

`workspaceProvider` polls every projector on an interval. Undo/redo snapshots **strip transient telemetry**
before storing and **merge live telemetry back** on restore (`_stripTransient` / `_mergeWithTelemetry`) so
undoing a layout change never rolls back power/temperature readings.

### Network protocols (`lib/core/services/`)

- **`panasonic_protocol_service.dart`** — opens a **new** TCP connection per command and closes it
  right after the response; there is no persistent per-projector socket. Auth = MD5 hash of a
  challenge token. Commands are plain text (`PON` power on, `OSH:1` shutter close). See the
  `panasonic-ntcontrol` skill for the full wire format and connection-concurrency limits.
  The app's instance (`protocolServiceProvider`) is an `IsolateProtocolService`
  (`isolate_protocol_service.dart`) that runs every call on a worker isolate so polling
  doesn't stall the UI — a new public method on the service must be routed there too.
- **`osc_service.dart`** — UDP. Inbound: maps OSC addresses to projector actions; custom commands get slugs
  like `/pgrid/all/custom/dynamic-contrast` (or `/pgrid/group/<group-name>/custom/<slug>`). Outbound: broadcasts `/pgrid/status/{online,offline,critical,warning}` to a
  configured send IP/port on every status change (`critical`/`warning` count unacknowledged alerts), and
  `/pgrid/alert/<rule>` / `/pgrid/alert/acknowledged` from `alertsProvider.events`.
- **`remote_preview_service.dart`** — "Remote Preview" (RemoView) live view: a WebSocket client to
  the projector's own web UI (`ws://<ip>:80/remotepreview`, or `ws://<ip>:8080/` on a PT-RZ34K,
  tried in that order — not the NTCONTROL port),
  receiving ~1fps JPEG frames and text status messages. Transport-only, no Riverpod/UI in this
  file — `remote_preview_provider.dart` and `preview_signal_status_provider.dart` wrap it for
  state, `remote_preview_dialog.dart`/`preview_viewport.dart` render it. Full design in
  `plan/REMOTE_PREVIEW_PLAN.md`.

### Persistence

Project files and app settings are JSON in the platform config dir (`app_config_dir.dart`):
`%APPDATA%\ProjectorGrid\` (Windows), `~/Library/Application Support/ProjectorGrid/` (macOS).
Window geometry is persisted separately (`window_prefs_service.dart`), debounced during drag and saved once on close.

### Window close / quit flow (subtle)

`setPreventClose(true)` is set so the app can show an unsaved-changes dialog before closing.

- `_MainWorkspaceScreenState.onWindowClose` (`main_workspace_screen.dart`) is the **only** place that decides
  whether the window actually closes — it runs the confirm dialog, then `windowManager.destroy()`.
- `_WindowGeometryPersistence` in `main.dart` is a second `WindowListener` that **only ever saves geometry**;
  it must never call `destroy()` or it would race the confirmation dialog and lose unsaved changes.
- macOS system-menu Quit bypasses `onWindowClose`; it comes in via the `projector_grid/quit` MethodChannel
  (`confirmQuit` / `markTerminationApproved`).

### IndexedStack focus quirk

`_WorkspaceBody` keeps a `FocusScopeNode` per view and re-focuses after every Controls/Monitoring switch.
`IndexedStack` wraps inactive children in `Visibility` → `ExcludeFocus`, which otherwise leaves
`primaryFocus == null` and silently kills all `Shortcuts` (Ctrl+A, Ctrl+Z, …). Don't remove the
`_requestViewFocus` post-frame callback.

### Windows debug-mode crash

JIT (debug) builds on the dev laptop can die with an access violation inside `flutter_windows.dll`
(Dart VM `ThreadInterrupter` / profiler stack-walk race). Release builds are unaffected. There is no
workaround in the runner (`windows/runner/main.cpp` is the stock template): rerun the debug app, or
test in a release build.

## Deliberate deviations from the flutter-desktop-arch skill

The `flutter-desktop-arch` skill's generic guidance doesn't match this project in a few places.
These are intentional choices, not gaps to "fix":

- **No routing.** The skill defaults to `go_router` (`app/router.dart`). This app is a single
  window with two views (Controls/Monitoring) switched via `IndexedStack` in
  `main_workspace_screen.dart` — there's nothing to deep-link or navigate between, so a router
  would add indirection with no payoff. See the "IndexedStack focus quirk" note above before
  touching that switch.
- **No `Result<T>`/`Either<Failure, T>`.** The skill's error-handling section recommends wrapping
  data-layer calls in a Result/Either sum type. This project already has a stricter rule under
  Conventions below — no fallback handling or validation for cases that cannot occur at
  runtime — and layering a Result type on top of that would just be ceremony around errors the
  code already isn't meant to swallow. Exceptions propagate to `AsyncValue.error` or get logged
  via `eventLogProvider`.
- **No `path_provider`/`drift`/`Hive`.** The skill recommends `path_provider` for file paths and
  `drift`/`Hive` for persistence. This app hand-rolls its per-platform config directory in
  `app_config_dir.dart` (`%APPDATA%`/`HOME` env vars) and persists everything as plain JSON files
  — there's no relational data or large key-value store that would justify a database dependency.
  Don't introduce these packages when working on persistence.

## Conventions

- One responsibility per provider/widget file. Never mutate state in place — Freezed `copyWith` or a new
  plain-Dart instance.
- Do **not** add fallback handling or validation for cases that cannot occur at runtime.
- Comments explain *why*, not *what*.
- Commit subjects are imperative with a prefix: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- The analyzer excludes all platform folders (`windows/`, `macos/`, `build/`, …); only `lib/` and `test/` are linted.
