# Improvement Plan

Working doc for the backend/UI review + the "Focus on Selected/All" feature.
Status: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not applicable

## Backend / Architecture

1. `[dropped]` ~~Reuse one TCP socket across the 10 telemetry commands per poll~~
   — Incorrect on my part. Per `.claude/skills/panasonic-ntcontrol/SKILL.md`
   ("Connection lifetime"), the protocol requires connect → one command →
   disconnect, and the projector re-handshakes fresh on every new connection.
   The current per-command socket lifecycle in `_sendSingleCommandEx`
   (`lib/core/services/panasonic_protocol_service.dart`) is correct as-is and
   matches the documented/expected protocol behavior. No change.

2. `[x]` **Parallelize command dispatch** — `sendCommandToSelected` /
   `sendCommandToGroup` / `sendCommandToAll` in
   `lib/features/workspace/presentation/providers/workspace_provider.dart`
   now share one `_dispatchToNodes` helper that fires commands to target
   nodes concurrently via `Future.wait`, batched in chunks of 100
   (`_networkBatchSize`) rather than one unbounded `Future.wait` over every
   target. Batching matters at scale (target installs run 120-150+
   projectors, up to the 500-node project-file cap) mainly to bound peak
   open sockets on the controlling machine — macOS's default per-process
   file-descriptor limit is the tightest constraint of the three (client OS,
   network/switch, projector), the other two are a non-issue at this scale.
   100 was chosen as a safety margin well under typical FD ceilings while
   still keeping "send to all" feeling effectively simultaneous.

3. `[x]` **Parallelize polling** — `_pollAllProjectors` in
   `workspace_provider.dart` now batches nodes through the same
   `_networkBatchSize` (100, shared with `_dispatchToNodes` — the two were
   using separate constants with the same meaning, now one) rather than
   awaiting each node's full telemetry chain sequentially. This mattered more
   than dispatch batching: a single node's poll is up to 11 sequential
   connect/command/disconnect round-trips (1 probe + 10 telemetry queries),
   so unbatched sequential polling across N nodes could make one full poll
   cycle take longer than the 60s default interval itself once N gets into
   the hundreds. Batching only overlaps *different* nodes' polls with each
   other — each node's own chain still runs one command at a time, per the
   protocol's connection-lifetime rule.

4. `[x]` **Move selection out of the domain model** — `isSelected` removed
   from `ProjectorNode` entirely (`lib/features/workspace/domain/projector_node.dart`).
   Added `SelectionNotifier` (`presentation/providers/selection_provider.dart`),
   a `@riverpod class` holding just `Set<String> selectedIds`. All selection
   methods on `WorkspaceNotifier` (`selectNodeOnDown/OnTap`, `selectAll`,
   `deselectAll`, `selectNodesInGroup`, marquee select, `deleteSelected`,
   `sendCommandToSelected`, drag/snap-to-grid for multi-select) now read/write
   `selectionProvider` instead of mapping `copyWith(isSelected: ...)` over the
   whole node list. `_stripTransient` no longer needs to reset `isSelected`
   (it's simply not on the model anymore); `_restoreSnapshot` and `setNodes`
   (project load) now explicitly clear the selection provider, matching the
   old implicit behavior. `deleteNode`/`deleteSelected` prune the id(s) from
   `selectionProvider` so it can't accumulate stale ids for removed nodes.
   `ProjectorCard` takes a new `isSelected` bool prop instead of reading
   `node.isSelected`; `projector_workspace.dart` watches `selectionProvider`
   and passes membership down per-card; `control_bar.dart`'s "any selected"
   watch now selects on `selectionProvider` directly instead of scanning
   `workspaceProvider`'s node list. `dart analyze` and `flutter test` clean.

5. `[ ]` Expose `PanasonicProtocolService` via a Riverpod provider instead of
   constructing it inline in `WorkspaceNotifier`, for testability.
   `PanasonicProtocolService` (`lib/core/services/panasonic_protocol_service.dart`)
   is stateless — no instance fields, every method opens its own fresh socket
   per call — so today's 5 separate `final _x = PanasonicProtocolService();`
   instantiations (`workspace_provider.dart:16`, plus one each in
   `brightness_control_dialog.dart`, `geometry_correction_dialog.dart`,
   `color_correction_dialog.dart`, `add_projector_dialog.dart`) aren't a
   correctness problem. This is purely about testability/DI: `WorkspaceNotifier`
   (node state, polling, command dispatch — the most complex/least-tested
   piece of state in the app) has no way to swap in a fake protocol service,
   so unit-testing dispatch batching, offline-node skipping, or polling status
   transitions would require a real reachable projector (or nothing at all,
   which is presumably why none of that logic has test coverage today). Fix:
   add a small `@riverpod PanasonicProtocolService protocolService(Ref ref) =>
   PanasonicProtocolService();`-style provider, have `WorkspaceNotifier` read
   it via `ref` instead of constructing its own, then tests can
   `ProviderContainer(overrides: [protocolServiceProvider.overrideWithValue(FakeProtocolService())])`
   and drive `WorkspaceNotifier` against canned responses with no network
   involved. No functional/behavior change for the running app. Scope
   decision when implemented: the plan only really needs `WorkspaceNotifier`
   converted (the 4 dialog call sites are simple call-and-forget usages in
   `State` classes, not really unit-testable in isolation anyway) — but could
   convert all 5 for consistency if preferred. Discussed 2026-08-22, deferred
   — not implemented yet.

6. `[ ]` Surface OSC parse/dispatch failures (unknown address, unknown group,
   unknown custom-command slug, malformed message) into `eventLogProvider`
   instead of only `debugPrint`, so they're visible in the running app.
   All failure paths in `OscService._processMessage`/`_handleDatagram`
   (`lib/core/services/osc_service.dart`) currently only `debugPrint`:
   malformed packet parse failure (line 217), unknown custom-command slug —
   2 sites, for `/pgrid/all/custom/...` and `/pgrid/group/.../custom/...`
   (lines 240, 278), unknown command path not in `_oscCommandMap` — 2 sites
   (lines 248, 283), group address missing its command segment (line 260),
   group name that doesn't resolve to a configured group (line 268), any
   address not matching `/pgrid/all/`, `/pgrid/group/`, or `/pgrid/status`
   at all (line 300), and runtime dispatch errors from
   `sendCommandToAll`/`sendCommandToGroup` throwing, caught via
   `.catchError` (lines 238, 246, 276, 288). `debugPrint` only shows up in
   an attached debug console during `flutter run` — in a packaged release
   build (what actually ships to a show) there's no console at all, so none
   of this is visible to whoever is running the app. This matters
   specifically for this app because its whole purpose is being the OSC
   bridge for QLab/TouchDesigner integrations — a mistyped address, a stale
   custom-command slug (renamed/deleted after a cue was already
   programmed), or a wrong group name currently just silently does nothing,
   with zero feedback inside the app; during a live show, if a cue doesn't
   trigger a projector, the operator has no way to tell why from the app
   itself. Contrast with the *success* path: `osc_provider.dart`'s
   `OscNotifier._wireCallbacks()` already logs every successfully resolved
   OSC command into `eventLogProvider` (visible in the Event Log panel) —
   this item is about adding the missing failure-side equivalent of that
   existing, working pattern. Implementation: `OscService` is deliberately
   decoupled from Riverpod/`LogEvent`/app state (same as its existing
   `onCommand`/`getStatus`/`resolveGroupId`/`resolveCustomCommand` callback
   hooks), so add one more hook in that style —
   `void Function(String message, {bool isError})? onIssue;` — call it from
   each failure site instead of `debugPrint`, then wire it in
   `osc_provider.dart`'s `_wireCallbacks()` to push a `LogEvent` into
   `eventLogProvider` (`LogSeverity.warning` for user/config mistakes —
   unknown address/slug/group; `LogSeverity.error` for genuine failures —
   parse error, dispatch exception). No change to command-handling behavior
   itself, just making failures visible where successes already are.
   Discussed 2026-08-23, deferred — not implemented yet.

7. `[ ]` Add a global error handler (`FlutterError.onError` /
   `PlatformDispatcher.instance.onError`) in `main.dart`.

8. `[x]` **Persist window size/position** — `main.dart` used to hardcode
   `WindowOptions(size: Size(1280, 720), center: true, ...)` on every launch
   regardless of how the window was last resized/moved/maximized. Added
   `lib/core/services/window_prefs_service.dart` (`WindowPrefs` +
   `WindowPrefsService`), a small Riverpod-independent JSON-file-backed
   class — deliberately separate from `AppSettingsNotifier` because it must
   be read in `main()` before `runApp`/`ProviderScope` exist, so it can't go
   through `ref.read`. Same load/save-to-JSON pattern as
   `AppSettingsNotifier`, its own file (`window_prefs.json`, next to
   `app_settings.json` in the same per-platform config dir).
   `main.dart` now reads saved prefs before building `WindowOptions`
   (falling back to the old 1280×720 centered default on first run, or if
   `WindowPrefs.fromJson`'s sanity clamp rejects corrupt/wildly-off-screen
   values — not real multi-monitor validation, just a basic guard), restores
   position via `windowManager.setPosition` and re-maximizes via
   `windowManager.maximize()` after show if needed. A new
   `_WindowGeometryPersistence` (`with WindowListener`) listens for
   resize/move/maximize/unmaximize and debounces saves by 500ms (these
   events fire continuously while dragging); close is special-cased via
   `windowManager.setPreventClose(true)` + `onWindowClose` forcing one final
   synchronous save before calling `windowManager.destroy()` itself, so a
   resize immediately followed by closing isn't lost to the debounce.
   Verified by seeding `window_prefs.json` and running `flutter run -d
   windows` for both the first-run (no prefs) and restore-from-saved-prefs
   paths — no crashes, no window_manager errors, both paths render
   correctly. `dart analyze` and `flutter test` clean.

9. `[ ]` (Flagged only, no action requested) Projector credentials are
   stored in plaintext in `.pgrid` project files.

## UI / UX

1. `[x]` **Add hover state to `ProjectorCard`** — `_ProjectorCardState`
   (`lib/features/workspace/presentation/widgets/projector_card.dart`) now
   tracks `_isHovered` via a `MouseRegion` (`cursor: SystemMouseCursors.click`,
   `onEnter`/`onExit`) wrapped around the card's `GestureDetector`; the card's
   `Container` became an `AnimatedContainer` (120ms) so the border transition
   animates rather than snapping. Border color logic, tuned over a few passes
   against a live mockup and real in-app testing: selected stays
   `colorScheme.primary` (width 2, unchanged); unselected+hovered is
   `colorScheme.primary` at 85% opacity (width 1) — bright/blue enough to read
   clearly without being mistaken for selection; unselected+idle is
   `colorScheme.outline` (same as before this change — earlier attempts using
   `theme.dividerColor`/`colorScheme.outlineVariant` either turned out to be
   literally identical to the hover color under this app's M3 theming with no
   explicit `dividerColor` override (`dividerColor ??= colorScheme.outline` is
   Flutter's own M3 default, per `theme_data.dart`), or made idle cards blend
   into the workspace background/grid too much). `SystemMouseCursors.click`
   verified correct for macOS at the framework level: it maps natively to
   `NSCursor.pointingHandCursor` there, unlike `SystemMouseCursors.move`
   (which this codebase already special-cases per-platform elsewhere, in
   `projector_workspace.dart`, because macOS has no native equivalent) — no
   platform branching needed for `click`. `dart analyze` and `flutter test`
   clean.
2. `[dropped]` ~~Add tooltips to the status icons on `ProjectorCard`~~ — the
   icons (power, shutter, warning, lock, connection dot) are considered
   self-explanatory enough as-is; not worth the added UI. Decided
   2026-08-23, no change.
3. `[x]` **Animate selection border / drag-snap transitions** — selection
   border animation came for free from item 1's `AnimatedContainer` (border
   color/width already transitions on select/deselect). Drag-snap: added
   `isDragging` to `ProjectorCard` and converted its outer `Positioned` to
   `AnimatedPositioned` (130ms, `Curves.easeOut`, `Duration.zero` while
   `isDragging`) so the post-release `snapNodeToGrid` correction
   (`workspace_provider.dart`) eases into place instead of teleporting.
   `projector_workspace.dart` derives `isDragging` from the existing
   `_panStartPositions` drag-tracking map (no new state) and now clears it
   *before* calling `notifier.snapNodeToGrid`/`endMove` in `onPanEnd`, so the
   rebuild that applies the snapped position also sees `isDragging == false`
   and animates. Follow-up fix: zoom changes rescale the same `left`/`top`
   values (`node.x/y * zoom`) that drag-snap animates, so without a guard
   every card would visibly "jump" on each zoom step too — added `_lastZoom`
   tracking in `_ProjectorCardState` so a zoom change (detected by comparing
   `widget.zoom` against the last-built value) forces `Duration.zero`,
   leaving only genuine `node.x`/`node.y` changes (the actual snap) animated.
   `dart analyze` and `flutter test` clean.
4. `[x]` **Make `KeyboardShortcutsDialog` platform-aware (Cmd vs Ctrl
   labels)** — the underlying key bindings were already cross-platform
   (`projector_workspace.dart`'s `Shortcuts` map registers both a `control`
   and a `meta` `LogicalKeySet` for every listed shortcut); only the dialog's
   *display* was Windows-only, hardcoding the literal string `'Ctrl'` for
   every modifier. Added a `_KeyBadge._platformLabel` mapping
   (`keyboard_shortcuts_dialog.dart`) applied at render time —
   `'Ctrl'` → `'⌘'`, `'Shift'` → `'⇧'` on macOS, unchanged elsewhere — so the
   `_Shortcut`/`_Section` data lists stay generic and `const`. Noted but out
   of scope here: the Project-section shortcuts (New/Open/Save/Exit) are
   wired through the native OS menu bars, not this `Shortcuts` widget, so
   their real macOS bindings weren't verified as part of this pass; and Redo
   (`Ctrl`/`Cmd`+`Y`) has a separate, already-flagged inconsistency on macOS
   (two different bindings — see UI/UX item 5) that a label fix alone
   doesn't address. `dart analyze` and `flutter test` clean.
5. `[x]` **Reconcile the two different macOS Redo bindings** — removed the
   redundant `LogicalKeySet(meta, keyY)` entry from the in-canvas
   `Shortcuts` map (`projector_workspace.dart`), leaving Cmd+Shift+Z (native
   Edit menu, `mac_menu_bar.dart`) as the one macOS Redo binding, matching
   platform convention. Windows/Linux Ctrl+Y is unaffected.
   `KeyboardShortcutsDialog`'s Edit section now shows the binding that's
   actually live per platform — `['Ctrl', 'Shift', 'Z']` (→ ⌘⇧Z via the
   item-4 label mapping) on macOS, `['Ctrl', 'Y']` elsewhere — instead of a
   single hardcoded row that only matched Windows. `dart analyze` and
   `flutter test` clean.

6. `[x]` **Surface last telemetry refresh time + visible feedback for F5.**
   Today there's no way to tell when the workspace last polled — no
   timestamp tracked anywhere — and `refreshAll()`
   (`workspace_provider.dart:204`, called by both the 60s auto-poll timer
   via `_pollAllProjectors()` and F5/the Refresh menu items in
   `top_menu_bar.dart`/`mac_menu_bar.dart`/`main_workspace_screen.dart`)
   gives zero visible feedback — it just quietly re-polls in the
   background, so pressing F5 looks like it did nothing. Proposed fix: add
   a small, separate Riverpod notifier (e.g. `pollStatusProvider`) holding
   `{DateTime? lastCompletedAt, bool isPolling}`, set from
   `_pollAllProjectors()` — deliberately kept separate from
   `WorkspaceNotifier`'s node-list `state` (same reasoning as
   `selectionProvider` in Backend/Architecture item 4: a refresh timestamp
   isn't part of the undo/redo-snapshotted node state and shouldn't be
   dragged into it or project-file serialization). Surface it in
   `status_bar.dart` (already a persistent bar with live `_StatusItem`
   counts — natural fit) as a plain absolute timestamp, e.g.
   `Last refresh: 14:32:07` (simpler than a live "Xs ago" countdown, which
   would need its own ticking `Timer` just for cosmetic freshness), plus a
   small spinner shown while `isPolling` is true so F5/auto-poll gives
   immediate visible acknowledgment. Scoped out: a *per-projector*
   last-successfully-polled timestamp (e.g. in the Monitoring table or a
   card tooltip) would be a separate, larger feature — useful for "is this
   specific projector's data stale" rather than "did a refresh cycle run at
   all" — treated as a possible future add-on, not part of this item.
   Discussed 2026-08-23, deferred — not implemented yet.

   **Prerequisite implemented 2026-08-23**: `StatusBar` was only ever
   rendered inside the Controls branch of `_WorkspaceBody`'s `IndexedStack`
   (`main_workspace_screen.dart`) — nested inside a `Row`/`Column` alongside
   `ProjectorWorkspace`/`ControlBar` — so it (and every count it shows)
   vanished entirely when switching to the Monitoring view. Hoisted
   `StatusBar()` out of that branch to be a shared sibling directly above
   the `IndexedStack` in `_WorkspaceBody.build`, so it now renders once
   regardless of which view is active; the Controls branch is now just
   `Row([Expanded(ProjectorWorkspace()), ControlBar()])`, Monitoring is
   unchanged. Trade-off surfaced and accepted before implementing: today
   `StatusBar` and `ControlBar`'s tab header happen to share the same
   height/color and sit in the same row, reading as one continuous band —
   hoisting `StatusBar` a level up breaks that visual continuity (confirmed
   via a mockup before implementing), since `ControlBar` only exists in the
   Controls branch and disappears entirely in Monitoring, leaving
   `StatusBar` as its own full-width band there. Accepted as worth it for
   the counts (and the future last-refresh indicator above) actually being
   visible in Monitoring. Follow-up: since `StatusBar` and `ControlBar`'s
   tab header now stack directly on top of each other with no gap (right
   column, Controls view), matching background colors made them look like
   one merged block — changed `StatusBar`'s background
   (`status_bar.dart`) from `colorScheme.surfaceContainerHighest` to
   `colorScheme.surfaceContainerHigh` (one M3 elevation tier down, rather
   than an arbitrary new color) so the two read as distinct bands.
   `ControlBar`'s header is unchanged. `dart analyze` and `flutter test`
   clean.

   **Feature itself implemented 2026-08-23**: added
   `lib/features/workspace/presentation/providers/poll_status_provider.dart`
   — a small `@riverpod class PollStatusNotifier` holding
   `PollStatus {DateTime? lastCompletedAt, bool isPolling}`, `started()`/
   `completed()` methods. Wired into `WorkspaceNotifier._pollAllProjectors()`
   (`workspace_provider.dart`): `started()` at the top, `completed()` in a
   `finally` block so `isPolling` always resets even if a batch throws —
   covers both the 60s auto-poll and F5/Refresh (`refreshAll()` just calls
   the same method). Surfaced in `status_bar.dart` as a new right-aligned
   `_RefreshStatusItem` (pushed there via `Spacer()`): idle shows a small
   clock icon + `Last refresh: HH:MM:SS` (`—` before the first poll
   completes, since polling only starts on a 60s delay, not immediately on
   launch), `isPolling` swaps the icon for a 12px `CircularProgressIndicator`
   and the label to `Refreshing…`. Verified with `flutter run -d windows`
   (clean launch, no errors, verified process exits cleanly). `dart analyze`
   and `flutter test` clean.

## Pre-Release Code Review (2026-08-23)

Ran a full code review (`/code-review high`) of the accumulated uncommitted
work before shipping 1.4.0. Two confirmed, fixed bugs; the rest are lower
priority and left for later.

- `[x]` **Window-close race could discard unsaved changes.** The
  window-persistence `WindowListener` added in item 8 (`main.dart`)
  unconditionally called `windowManager.destroy()` in its own
  `onWindowClose`. Verified against the actual pinned `window_manager`
  0.5.2 source (`pubspec.lock`): its close-event dispatch loop calls every
  registered listener's `onWindowClose` without awaiting any of them, so
  both listeners start concurrently. `_WindowGeometryPersistence`'s chain
  (two fast platform-channel calls + a synchronous file write) reliably
  finished and destroyed the window *before*
  `_MainWorkspaceScreenState.onWindowClose`'s (`main_workspace_screen.dart`)
  blocking unsaved-changes confirmation dialog could even render — a dirty
  project's changes could be silently discarded on close. Fix: removed the
  `windowManager.destroy()` call from `_WindowGeometryPersistence.onWindowClose`
  entirely — it now only ever saves geometry.
  `_MainWorkspaceScreenState.onWindowClose` remains the sole place that
  decides whether the window is actually allowed to close. `dart analyze`
  clean, verified via `flutter run -d windows` (clean launch, no errors).

- `[x]` **F5 could double-poll.** `_pollAllProjectors()`
  (`workspace_provider.dart`) had no re-entrancy guard — `refreshAll()`
  (F5/Refresh) and the 60s auto-poll timer chain could both invoke it
  concurrently, since neither checked `pollStatusProvider.isPolling`
  first. On a large install, pressing F5 mid-cycle started a second full
  poll over every node simultaneously (doubling sockets/log events), and
  whichever cycle's `finally` completed first would stop the status bar's
  spinner while the other kept silently running, then flicker again on its
  completion. Fix: added an early-return guard at the top of
  `_pollAllProjectors()` checking `ref.read(pollStatusProvider).isPolling`.
  `dart analyze` clean, verified via `flutter run -d windows`.

The remaining 7 findings from the same review, deferred — none blocking
this release:

- `[x]` **Selection change rebuilds the entire card grid.**
  `ProjectorWorkspace.build()` (`projector_workspace.dart`) used to watch
  `selectionProvider` at the top level, so any selection change
  reconstructed the whole `nodes.map((node) => ProjectorCard(...))` list
  and re-ran `build()` for every card, not just the ones whose membership
  actually flipped — undercutting the stated goal of item 4
  (`selection_provider.dart`'s own doc comment says selection was pulled
  out of `ProjectorNode` specifically so selecting/deselecting doesn't
  force wide rebuilds). Fix: `ProjectorCard` (`projector_card.dart`)
  converted from `StatefulWidget` to `ConsumerStatefulWidget`; it no
  longer takes an `isSelected` prop and instead watches
  `selectionProvider.select((ids) => ids.contains(node.id))` internally,
  so only the card(s) whose membership actually changes rebuild — same
  `.select()` idiom `control_bar.dart`'s "any selected" watch already
  used. Removed the top-level `ref.watch(selectionProvider)` from
  `ProjectorWorkspace.build()`; the four call sites that needed the full
  selection set (Focus intent, Delete intent, drag-affected-nodes
  computation, delete-confirmation dialog) now do a fresh
  `ref.read(selectionProvider)` inside their own callback instead, since
  those only run on user action, not on every build, so a read (not a
  watch) is correct there. `dart analyze` clean, verified via `flutter
  run -d windows` (clean launch, no errors).

- `[x]` **`build.yaml` disables Freezed immutability for every model, not
  just the one field that needed it.** `make_collections_unmodifiable:
  false` (`build.yaml`) applied globally to all `@freezed` classes
  (`ProjectorNode`, `ProjectorGroup`, etc.), not scoped to whichever field
  motivated it. Traced via `git log -- build.yaml`: it was added in
  `aa2bc67` (SDK/dependency-bump commit), and the only generated code that
  commit actually changed was `ScheduledTask.weekdays` (`List<int>?`) —
  the only collection field across all three domain models. Fix: deleted
  `build.yaml` entirely (Freezed's default, immutability-on, now applies
  project-wide again); `scheduled_task.dart`'s `@freezed` changed to
  `@Freezed(makeCollectionsUnmodifiable: false)` (Freezed 3.x supports
  this as a per-class annotation parameter, confirmed against the
  installed `freezed_annotation` 3.1.0 source), scoping the opt-out to
  just the one class/field that needs it. Regenerated with `dart run
  build_runner build --delete-conflicting-outputs`: `scheduled_task
  .freezed.dart` came out byte-identical (confirming no behavior change
  for `ScheduledTask`), `ProjectorNode`/`ProjectorGroup` now get the
  unmodifiable-collection protection back with no code changes needed
  (neither has a collection field today, so no generated-code diff there
  either — the protection is live for any collection field added to them
  in the future). `dart analyze` clean, verified via `flutter run -d
  windows` (clean launch, no errors).

- `[x]` **Restored window position isn't checked against live monitor
  bounds.** `WindowPrefs.fromJson` (`window_prefs_service.dart`) only
  sanity-clamps x/y to a wide numeric range (`[-100, 20000]`), not against
  which displays are actually connected — already flagged as a known,
  accepted limitation in item 8's own write-up ("not real multi-monitor
  validation, just a basic guard"), not a newly-discovered gap. Fix: added
  `_isPositionOnScreen` (`main.dart`), which fetches the currently-connected
  displays via `screen_retriever`'s `getAllDisplays()` (already resolved
  transitively through `window_manager` at 0.2.2 — added as an explicit
  direct dependency in `pubspec.yaml` since it's now imported directly) and
  checks whether the saved `(x, y, width, height)` rect overlaps any
  display's visible bounds; fails open (treats the position as valid) on
  any platform-call error so a transient failure can't discard otherwise-
  good prefs. Called right after `WindowPrefsService.load()` in `main()`:
  if the saved position doesn't overlap any connected display, `savedPrefs`
  is reset to `null`, falling back to the existing default-centered
  1280×720 path (the same path already used for first-run/no-saved-prefs).
  Verified both branches directly: seeded `window_prefs.json` with an
  in-clamp-range but unreachable position (`x: 9000, y: 9000`) and
  confirmed via a temporary debug log that it was discarded; restored the
  real saved position (`x: 766, y: 63`) and confirmed it was accepted —
  temporary logging removed after verification. `dart analyze` clean,
  verified via `flutter run -d windows` (clean launch, no errors, both
  paths).

- `[ ]` **Batch-dispatch loop duplicated across three call sites.** The
  "batches of `_networkBatchSize`, `Future.wait` per batch" loop appears
  near-verbatim in both `_pollAllProjectors` and `_dispatchToNodes`
  (`workspace_provider.dart`), plus a third, differently-sized version
  (batch size 50) in `panasonic_protocol_service.dart`'s `scanNetwork`.
  Not a bug — a future bulk-network operation is likely to copy-paste this
  pattern again rather than reuse a shared helper, and the batch-size
  constants must be kept in sync by hand across three sites. A shared
  `_forEachBatched<T>(items, batchSize, action)` helper would remove the
  duplication.

- `[x]` **Config-directory path logic duplicated a fifth time.**
  `WindowPrefsService._filePath` (`window_prefs_service.dart`)
  re-implemented the same Windows/macOS `%APPDATA%\ProjectorGrid\` /
  `~/Library/Application Support/ProjectorGrid/` path construction already
  duplicated in `app_settings_provider.dart`, `custom_commands_provider.dart`,
  `project_provider.dart`, and `docs_service.dart` — and, discovered while
  fixing this, a **6th** undocumented copy in `control_bar.dart`
  (`_favoritesFilePath`, for `test_pattern_favorites.json`) that the
  original review missed. Fix: added `appConfigFilePath(String filename)`
  (`lib/core/services/app_config_dir.dart`), one shared helper with the
  same Windows/macOS/Linux branching; all 6 call sites' `_filePath`-style
  getters are now one-line calls into it (`window_prefs.json`,
  `app_settings.json`, `custom_commands.json`, `recent.json`,
  `osc_reference.html`, `test_pattern_favorites.json`) — pure
  deduplication, same resolved paths, no functional change. `dart analyze`
  clean, verified via `flutter run -d windows` (clean launch, no errors,
  all six config files load correctly through the shared helper).

- `[dropped]` ~~New providers don't follow this codebase's `keepAlive`
  convention for cross-cutting state.~~ — **the finding as originally
  written was factually wrong.** It claimed `workspaceProvider`/
  `eventLogProvider`/`scheduledTasksProvider` "all use
  `@Riverpod(keepAlive: true)`", so `PollStatusNotifier`/`SelectionNotifier`
  (plain `@riverpod`, autoDispose) were the odd ones out. Checked the
  generated `.g.dart` files directly (`isAutoDispose` is unambiguous
  there): `eventLogProvider` and `scheduledTasksProvider` are keepAlive
  (`isAutoDispose: false`), but `workspaceProvider` itself is **not** —
  it's plain `@riverpod`, `isAutoDispose: true`, same as
  `selectionProvider` and `pollStatusProvider`. So the real split is 3
  autoDispose (`workspaceProvider`, `selectionProvider`,
  `pollStatusProvider`) vs. 2 keepAlive (`eventLogProvider`,
  `scheduledTasksProvider`), not 2-vs-3 as claimed. Since
  `selectionProvider`/`pollStatusProvider` are companion state to
  `workspaceProvider` specifically — always watched by the same
  always-mounted widgets (`ProjectorWorkspace`/`ControlBar`/`StatusBar`,
  kept alive by the `IndexedStack` in `main_workspace_screen.dart` even
  when the Monitoring view is active) — their being autoDispose is
  already consistent with the provider they're paired to; converting them
  to keepAlive would make them inconsistent with *that* provider just to
  match two unrelated ones. No practical effect either way today, since
  `MainWorkspaceScreen` is the app's one permanent screen and nothing
  unmounts these watchers during normal use. Decision: no code change —
  the finding's premise doesn't hold up, so there's nothing to fix here.
  Discussed 2026-08-24.

- `[dropped]` ~~Narrow race: maximized bounds can be saved as
  restored-window geometry.~~ `_WindowGeometryPersistence._saveNow()`
  (`main.dart`) persists `windowManager.getBounds()`/`isMaximized()`
  fresh whenever called, including via `onWindowClose`'s direct,
  non-debounced call. If the user un-maximizes and closes the window
  immediately (before the native restore animation — which isn't
  instant on Windows/macOS — fully settles), `_saveNow()` could capture
  a stale or mid-transition rect instead of the final restored size.
  Root cause is native window-animation timing that `window_manager`'s
  Dart API doesn't expose a "transition finished" signal for; the only
  real mitigations (an artificial settle-delay in `onWindowClose`, or
  tracking last-known-good restored bounds and distrusting fresh reads
  during a suspected in-flight transition) trade real complexity or
  close-responsiveness for a bug whose worst case is purely cosmetic —
  the next launch opens at a slightly-off restored size once, and
  self-corrects the moment the window is resized or moved again.
  Decided 2026-08-24: accepted as a known limitation, not worth chasing.

### Follow-up Code Review (2026-08-24)

Ran a second `/code-review high` pass after closing out the 9 findings above,
to check the fixes themselves didn't introduce or overlook anything. Two
confirmed, fixed bugs; the rest (pre-existing, unrelated to this review's
fixes) noted for later.

- `[x]` **`WindowPrefs.fromJson`'s sanity clamp defeated the new
  monitor-bounds fix for the most common real trigger.** The clamp
  (`window_prefs_service.dart`) rejected any saved `x`/`y` below `-100`.
  A monitor positioned left of or above the primary display — a
  completely normal setup — produces legitimately large negative
  coordinates (e.g. a 1920px-wide monitor to the left gives `x ≈ -1920`).
  Since this clamp runs inside `fromJson`, `WindowPrefsService.load()`
  already returned `null` for that case before the new
  `_isPositionOnScreen` check (added earlier in this same review pass,
  `main.dart`) ever got a chance to run its real per-display validation —
  so the window just silently re-centered instead of restoring, same as
  before that fix, for the single most common case it was meant to
  handle correctly. Fix: widened the clamp to `[-20000, 20000]` on both
  axes (symmetric with the existing upper bound) — still rejects clearly
  corrupt data, no longer rejects realistic multi-monitor offsets. Real
  per-display validation still happens downstream via
  `_isPositionOnScreen`; this clamp only needs to catch broken data now.
  Verified directly: a `x: -1920` prefs value is now accepted, a
  `x: -999999` one is still rejected. `dart analyze` clean, verified via
  `flutter run -d windows`.

- `[x]` **Keyboard Shortcuts dialog labeled Lens Shift "slow speed" as ⌘
  on macOS, but it was Ctrl-only — pressing Cmd+Arrow did nothing.**
  `_KeyBadge._platformLabel` (`keyboard_shortcuts_dialog.dart`) maps
  every `'Ctrl'` label to `'⌘'` on macOS, on the documented assumption
  that "every one of these shortcuts is registered with both control and
  meta modifiers" — true for every other Ctrl-labeled entry (verified by
  cross-checking each one: Select All/Deselect All/Undo in
  `projector_workspace.dart`; New/Open/Save/Save As/Exit/view-toggle in
  `main_workspace_screen.dart` + native `mac_menu_bar.dart`; Redo is
  handled separately with its own explicit per-platform label, already
  correct; Ctrl+Click/Ctrl+Drag/Ctrl+Scroll go through
  `_checkIsMultiSelect()`, which already checks both control and meta
  keys) — but false for the 4 Lens Shift "slow speed" bindings
  (`projector_workspace.dart`), which were `control: true` only, no
  `meta: true` variant. Fix: added the missing `meta: true` `SingleActivator`
  variants for all 4 (up/down/left/right), mirroring how every other
  Ctrl-bound entry in that same `Shortcuts` map already registers both —
  makes the binding match what the dialog already (correctly) displays,
  rather than changing the label to match the narrower binding. `dart
  analyze` clean, verified via `flutter run -d windows`.

Full shortcut audit (cross-checked every entry in
`keyboard_shortcuts_dialog.dart` against its actual `Shortcuts`/menu
binding in `projector_workspace.dart`, `main_workspace_screen.dart`, and
`mac_menu_bar.dart`): the Lens Shift row above was the only mismatch found.
Everything else — Project, Canvas Navigation, Selection, Projector Control,
Edit, View sections — already had correct, platform-complete bindings.

Other findings from this pass, pre-existing and unrelated to the 9 findings
this review pass was checking, not acted on: `updateNode`/`addNodes`
(`workspace_provider.dart`) call the per-node status check directly,
bypassing the `pollStatusProvider.isPolling` guard added for F5-vs-auto-poll
overlap — a low-severity race if a projector's IP is edited mid-poll-cycle;
`status_bar.dart`'s `_formatTime` duplicates one already in
`event_log_panel.dart`; `WindowPrefs.fromJson`'s `width < 400`/`height < 300`
floor is looser than the enforced `Size(800, 600)` window minimum
(`main.dart`); the new `await screenRetriever.getAllDisplays()` call in
`main()` adds a small amount of blocking work before `runApp()`, on top of
the pre-existing synchronous prefs-file read.

### macOS On-Device Testing (2026-08-25)

Tested the accumulated 1.4.0 work on a real Mac. Two real bugs found and
fixed; one pre-existing rendering issue flagged for later, not fixed here.

- `[x]` **Quitting via the app menu or Cmd+Q (no Flutter view focused)
  skipped the unsaved-changes prompt entirely.** `windowManager`'s
  `setPreventClose(true)` + `onWindowClose` (`main_workspace_screen.dart`)
  only intercepts the window's own close button — the native macOS "Quit"
  app-menu item (and Cmd+Q when no Flutter view has focus to intercept it
  first) calls `NSApplication.terminate` directly, which never goes through
  `NSWindowDelegate.windowShouldClose` at all, so a dirty project could be
  discarded silently. Fix: `AppDelegate.swift` now overrides
  `applicationShouldTerminate`, defers termination (`.terminateLater`), and
  asks Dart over a new `projector_grid/quit` `MethodChannel` (`confirmQuit`)
  — answered by `_handleQuitChannelCall` in `main_workspace_screen.dart`,
  which runs the same `TopMenuBar.confirmUnsavedChanges` dialog every other
  close path already uses. Since `windowManager.destroy()` itself calls
  `NSApp.terminate(nil)` under the hood, re-entering
  `applicationShouldTerminate` a second time, the two Dart-side paths that
  already ran their own confirmation (`onWindowClose`, the in-app
  Exit/Cmd+Q shortcut) now call a new `_markTerminationApproved()` first,
  which sets a one-shot flag on the native side so that re-entry doesn't
  prompt twice. `dart analyze` clean.

- `[x]` **Migrated macOS from CocoaPods to Swift Package Manager.** Removed
  `macos/Podfile`/`Podfile.lock` and the CocoaPods `#include?` lines from
  both xcconfig files; `Runner.xcodeproj` now references
  `FlutterGeneratedPluginSwiftPackage` directly instead of
  `Pods_Runner.framework`, and the `.xcworkspace` no longer references
  `Pods.xcodeproj`. No CocoaPods steps existed in
  `.github/workflows/release.yml` to update.

- `[ ]` **Flagged, not fixed: Impeller render glitches on Intel Macs.**
  Surfaced only after upgrading to the latest Flutter/Dart toolchain (see
  "For Developers" in `CHANGELOG.md`'s `[1.4.0]` section) — not present
  before that upgrade, so likely an Impeller regression in the newer engine
  rather than an app-code bug. Worked around for now by setting
  `FLTEnableImpeller = false` in `macos/Runner/Info.plist` (forces Skia on
  macOS). Deliberately left out of `CHANGELOG.md`'s "Fixed" list since it's
  a workaround for a side effect of this same release's Flutter upgrade,
  not an independent bug fix. Revisit later: retry with Impeller enabled on
  a subsequent Flutter version to see if it's been fixed upstream, and only
  then decide whether to drop this override.

## Bug Fixes (outside the review above)

- `[ ]` **Recurring `ui::AXTree` accessibility errors — NOT fixed, root cause
  is an upstream Flutter/Windows engine bug.** Still occurs in Geometry
  Correction (corner-handle drag + Manual mode) and Brightness Control
  (User 1/2/3 modes) after the code-quality pass below — confirmed by
  testing, the pass did not resolve it. Researched and traced to a known,
  currently-open Flutter engine defect (not fixable from application code):
  Windows' `ui::AXTree` sync breaks when an `OverlayPortal`-backed floating
  subtree (a `Tooltip`, or `DropdownMenu`'s popup via `MenuAnchor`) has its
  overlay child hidden/removed while nearby UI is also updating — the owning
  widget is never told its grafted semantics child is gone, so the Windows
  accessibility bridge holds a stale node reference. See
  [flutter/flutter#182444](https://github.com/flutter/flutter/issues/182444)
  and [flutter/flutter#134456](https://github.com/flutter/flutter/issues/134456);
  the fix PR ([flutter/flutter#190344](https://github.com/flutter/flutter/pull/190344))
  is still open/unmerged as of 2026-08-22. The one app-level workaround
  identified — replacing `DropdownMenu` with `SegmentedButton` in both
  dialogs, as the earlier Color Correction dialog fix already did — was
  explicitly declined (dropdown is being kept in both dialogs). Severity is
  low: the error is console-only, does not affect mouse/keyboard use, and
  only matters to a Windows screen-reader user interacting with these two
  dialogs. Decision: leave as-is, revisit only if that PR ships or if actual
  screen-reader users report a problem.

- `[x]` **Code-quality pass in Geometry Correction / Brightness Control**
  (made while investigating the above; kept because each is a real, separate
  improvement, not because it fixed the AXTree errors). In
  `geometry_correction_dialog.dart`: (1)
  `_CornerCorrectionCanvasState._onHandlePanUpdate` used to mutate corner
  state and rely on a *parent*-level `setState(() {})` (`onCornerChanged`) to
  repaint, rebuilding the whole Corner Correction body (tooltip, segmented
  button, 6 sliders) on every pointer-move frame of a drag even though
  nothing outside the canvas reads those fields — removed the callback
  entirely, canvas now rebuilds only itself via local `setState` (pan-update,
  double-tap, arrow-key paths); this is a real decoupling + perf win,
  independent of accessibility. (2) `_sliderRow`'s manual-mode stepper was
  conditionally wrapped in `IgnorePointer(Opacity(...))` only when disabled,
  which destroyed/recreated the stepper's Element — and its typed value/focus
  — every Auto/Manual toggle; now always wrapped, only `ignoring`/`opacity`
  toggle, so the stepper survives the toggle. This was a genuine
  previously-unnoticed correctness bug, now fixed. In
  `brightness_control_dialog.dart`: extracted a self-contained `_PercentSlider`
  widget (replacing two near-duplicated `Row`+`Slider` blocks) that tracks its
  own value locally while dragging and only commits to the parent
  (`onCommit`) at drag-end — the parent's `_lightOutput`/`_maxLightOutput`
  are now purely committed values instead of being mutated on every drag
  frame. Minor behavior change: live cross-slider clamping (dragging Max
  Light Output used to visually shrink Light Output in real time) now only
  applies once the Max Light Output drag ends. `dart analyze` and
  `flutter test` clean.

## New Feature: Focus on Selected / Focus on All

`[x]` Implemented 2026-08-23. `F` → focus selected projectors (falls back to
focusing all if nothing is selected); `Shift+F` → focus all projectors
regardless of selection. Added `FocusOnNodesIntent` and a `CallbackAction`
to `projector_workspace.dart`'s existing `Shortcuts`/`Actions` pair (same
scoping as the `I`/`O` shutter shortcuts), and a new `_focusOnNodes(targets)`
method: computes a canvas-space bounding box over the targets using each
card's fixed 120×100 size (`projector_card.dart`) plus 60px padding, fits
zoom to the current viewport (clamped to the existing 0.5–2.0 range, same
as manual zoom), and centers the scroll offset. Entries added to
`KeyboardShortcutsDialog`'s "Canvas Navigation" section.

**Bug found and fixed 2026-08-23**: pressing `F` a second time on the same
selection (after scrolling elsewhere, with the zoom level unchanged from
the first press) silently failed to visually move the viewport — though
the mouse cursor's hover/highlight was already responding at the *correct*
new position, and a manual scroll would suddenly "snap" everything into
place. Root cause: `_focusOnNodes` unconditionally used the same
`ScrollPosition.correctPixels()`-before-`setState()` trick as `_setZoom`
(meant to avoid a 1-frame jitter when zoom changes resize the canvas). But
that trick only takes visible effect by piggybacking on the relayout that a
*genuine* `_currentZoom` change forces (`canvasWidth`/`canvasHeight` are
derived from it) — `_setZoom` itself never hits this path without a real
zoom change, since it early-returns when `newZoom == _currentZoom`.
`_focusOnNodes` had no equivalent guard: when the target zoom matched the
current one (the repro case), `correctPixels()` silently updated
`ScrollPosition.pixels` — which is why hit-testing, which reads the live
`pixels` value directly, already looked correct — but nothing forced a
relayout, so the actual paint never caught up until a real scroll event ran
through the normal, notifying scroll pipeline and forced a repaint. Fix:
split `_focusOnNodes` into two paths — a plain `jumpTo()` (which notifies
and repaints on its own) when the zoom isn't changing, and the
`correctPixels()` trick only when it is. Verified via `flutter run -d
windows` (clean launch, no runtime errors); `dart analyze` clean.

## Second Code Review Pass (2026-08-30)

Ran `/code-review high` over all of `lib/`, plus a targeted verifier pass on
the trickier `workspace_provider.dart` candidates. 14 findings, all
CONFIRMED or PLAUSIBLE, none fixed yet — recorded here before starting so
there's a checklist to work through.

1. `[x]` **OSC never restarts on relaunch despite a saved "enabled"
   setting.** `OscNotifier.build()` (`osc_provider.dart:17`) always started
   inactive regardless of the persisted `AppSettings.oscActive` value, and
   nothing in `main.dart`/`app.dart` called `start()` at launch. Fix:
   `build()` now reads `appSettingsProvider.oscActive` and, if `true`, fires
   `start()` without awaiting it — the same fire-and-forget-from-`build()`
   idiom `WorkspaceNotifier.build()` already uses for `_startPolling()`.
   `start()`'s own state mutations (`state = ...`, `setOscActive(true)`) all
   happen after its `await _service.start(...)`, i.e. after `build()`'s
   synchronous phase has already returned, so this doesn't hit Riverpod's
   modify-during-build restriction. `dart analyze` clean.

2. `[x]` **Changing the OSC port/IP while OSC stays enabled doesn't rebind
   the live socket.** `_save()` (`preferences_dialog.dart:83`) only called
   `oscNotifier.start()`/`.stop()` when the on/off toggle itself changed —
   editing the receive port or send IP/port while OSC stayed on updated the
   settings UI but left the actual `RawDatagramSocket` bound to the old
   port/sending to the old IP until OSC was manually toggled off and back
   on. Fix: `_save()` now captures `oldSettings` before writing any new OSC
   fields, computes `connectionParamsChanged` (network device/receive
   port/send IP/send port each compared against `oldSettings`), and — when
   OSC stays enabled across the save but a connection parameter changed —
   calls a new `OscNotifier.restart()` (`stop()` then `start()`) instead of
   doing nothing. `dart analyze` clean.

3. `[x]` **One malformed custom command wipes all custom commands.**
   `CustomCommand.fromJson` (`custom_command.dart:28`) does unguarded type
   casts, and `_load()` (`custom_commands_provider.dart:16`) used to wrap
   the whole `list.map()` in one try/catch — a partial write to
   `custom_commands.json` (crash/power loss mid-save) leaving one entry
   malformed threw during `.map()`, the catch returned `[]`, and every
   previously-saved custom command disappeared with no error shown; the
   next save then persisted the now-empty list, permanently losing them.
   Fix: `_load()` now parses each entry in its own try/catch inside a loop,
   skipping just the malformed one instead of discarding the whole list;
   the outer try/catch still covers the separate case where the file isn't
   valid JSON at all. `dart analyze` clean.

4. `[dropped]` ~~Blank login/password bypasses the documented Panasonic
   factory defaults.~~ Originally flagged because `addProjectors()`
   (`workspace_provider.dart:530`) does `config['login'] ?? ''`, and
   `config['login']` is already an empty string (not `null`) when the Add
   Projector dialog's fields are left blank, so `ProjectorNode`'s
   `@Default('admin1')`/`@Default('panasonic')` never actually applies. Not
   a bug: `admin1`/`panasonic` was only ever the factory default on older
   Panasonic firmware — newer firmware ships with different factory
   defaults (`dispadmin`/`@Panasonic`), so hardcoding a substitution for a
   blank field would silently guess wrong for current projectors. The
   `@Default` on the model is effectively a leftover from when there was
   one universal default; auto-filling on blank isn't actually correct
   behavior to add. Current behavior (blank stays blank) is intentional —
   the user is expected to know what credentials, if any, their specific
   projector/firmware needs when adding it; the app shouldn't guess or
   prompt. Decided 2026-08-31, no change.

5. `[x]` **Unparsed auth challenge token silently sends the command
   unauthenticated.** `commandPrefix` (`panasonic_protocol_service.dart:130`)
   defaulted to the unauthenticated `'00'` and was only overwritten if the
   challenge-token regex matched — if a protected-mode handshake's token
   didn't cleanly match (odd firmware/proxy), the command was sent anyway
   without the MD5 digest instead of erroring out, and the caller just saw
   a generic failure with no signal it was actually an unparsed-token
   issue. Fix: when `isProtected` is true but the token regex doesn't
   match, `_sendSingleCommandEx` now returns `('Error: Unrecognized Auth
   Token', false)` immediately instead of falling through to the
   unauthenticated `'00'` prefix — same convention already used for
   `'Error: Invalid Handshake'` a few lines up, so existing callers that
   check for an `'Error'`-prefixed/containing response (`_pingProjector`,
   `probeProjector`, `pollProjectorTelemetry`'s initial QID check) already
   treat it correctly as a failure. `dart analyze` clean.

6. `[x]` **`updateNode` hardcodes port 1024 for its post-edit connectivity
   check.** `updateNode()` (`workspace_provider.dart:785`) called
   `_checkAndSetNodeStatus(id, ip, 1024)` instead of the node's real
   configured port, unlike every other call site in the file (which pass
   `node.port`). Editing a projector on a non-default port via Edit
   Projector made the immediate reconnect check probe the wrong port, so
   the card showed offline right after a valid edit until the next full
   poll cycle (up to 60s) silently corrected it. Fix: `updateNode` now
   reads the node's existing `port` via `state.where((n) => n.id ==
   id).firstOrNull?.port` (same idiom already used elsewhere in this file)
   before mutating state, and passes that to `_checkAndSetNodeStatus`
   instead of the literal `1024` — Edit Projector doesn't expose port
   editing, so the node's port is unchanged by this method regardless.
   `dart analyze` clean.

7. `[x]` **Deleting a group orphans any scheduled task that targeted it.**
   `deleteGroup()` (`workspace_provider.dart:168`) unassigns nodes from the
   deleted group but never touches `scheduledTasksProvider` — a
   `ScheduledTask` whose `targetGroupId` points at the deleted group keeps
   firing on schedule but matches zero nodes forever, with no warning at
   delete time (the confirmation dialog only mentioned projector
   unassignment) and no error at fire time. Decided against auto-cleanup
   (reassigning/disabling the orphaned tasks) in favor of just warning —
   fix: `_confirmDeleteGroup` (`manage_groups_dialog.dart`) now also counts
   `ref.read(scheduledTasksProvider).where((t) => t.targetGroupId ==
   group.id).length` and, when non-zero, appends a
   `"N scheduled task(s) target this group and will stop doing anything
   once it's deleted."` line to the existing confirmation dialog, same
   pattern as the existing projector-unassignment warning. `dart analyze`
   clean.

8. `[dropped]` ~~No-signal status displays as a raw `"0"` instead of "NO
   SIGNAL".~~ Originally flagged because signal parsing
   (`workspace_provider.dart:381`) normalizes to `"NO SIGNAL"` only for the
   `ER401` error, the literal string `"NO SIGNAL"`, or an empty string —
   the protocol reference documents `QVX:NSGS1` returning raw `"0"` for
   no-signal, which isn't covered. In practice, real projectors have never
   been observed returning `NSGS1=0` for a no-signal state — a no-signal
   condition shows up as the `ER401` error (already handled), and any
   non-error response is real signal-present telemetry. Treated as a
   theoretical case per the protocol doc that doesn't occur on real
   hardware, not worth coding around. Decided 2026-08-31, no change.

9. `[x]` **Plain-format temperature readings are missing the °C suffix.**
   Intake/exhaust temperature parsing (`workspace_provider.dart:397`) had an
   if/else-if chain for a slash-delimited format and the `ER401` error case,
   but no final `else` to append `"°C"` for a plain unsplit response value —
   that fell through undecorated. In practice, real projectors always
   respond with a Celsius/Fahrenheit pair delimited by `/` (confirmed
   2026-08-31), so the slash-format branch is the one that's actually hit —
   but added the missing `else` defensively anyway, in case a
   projector/firmware ever sends just one plain value: now appends `°C`
   directly to a non-empty plain value instead of leaving it undecorated.
   `dart analyze` clean.

10. `[ ]` **DST spring-forward can silently skip a scheduled task.** `_isDue`
    (`scheduled_tasks_provider.dart:56`) requires an exact
    `now.hour == dh && now.minute == dm` match for daily/weekly tasks with
    no catch-up logic. A task scheduled for a clock time that gets skipped
    entirely on the DST spring-forward night (e.g. 2:30 AM when the clock
    jumps 1:59:59 → 3:00:00) never fires that day, with no log entry.

11. `[x]` **Unhandled exception if the native file-picker process can't
    launch.** `_showOpenDialog`/`_showSaveDialog` (`project_provider.dart:209`)
    call `Process.run('powershell'/'osascript', ...)` with no try/catch, and
    none of their callers (`saveProject`, `saveProjectAs`,
    `pickAndOpenProject`) caught it either — if PowerShell is
    blocked/missing or `osascript` unavailable on a locked-down machine, the
    `ProcessException` propagated out of a plain `onPressed` handler as an
    unhandled error, with save/open silently failing with no explanation.
    Fix: `pickAndOpenProject` and `saveProjectAs` (the two callers, since
    `saveProject` routes through `saveProjectAs` when there's no current
    file path) now wrap their `_showOpenDialog`/`_showSaveDialog` call in
    try/catch, logging `'Failed to open the file picker: $e'` to
    `eventLogProvider` and returning `false` — same pattern already used by
    `openProject`'s existing catch block and `_writeToFile`. The static
    dialog helpers themselves are unchanged; the catch lives at the call
    site since they don't have `ref` access. `dart analyze` clean.

12. `[x]` **3 dialogs bypass centralized command logging.**
    `brightness_control_dialog.dart`, `color_correction_dialog.dart`, and
    `geometry_correction_dialog.dart` each instantiate their own
    `PanasonicProtocolService` and called `sendRawCommand` directly,
    bypassing `workspace_provider.dart`'s centralized `_dispatchToNodes`
    path that logs success/failure as `LogEvent`s — a failed write from one
    of these three dialogs (network blip, auth issue) was invisible, unlike
    the same kind of command sent through the toolbar/control-bar. All 3
    dialogs are plain `StatefulWidget` with no `ref`/Riverpod access, so
    routing through the centralized dispatch (or writing to
    `eventLogProvider` directly) would've meant converting them to
    `ConsumerStatefulWidget` plus adding a new public single-node dispatch
    method to `WorkspaceNotifier` — considered and explicitly declined as
    disproportionate for this fix. Went with a lighter, self-contained fix
    instead: each dialog's write-command methods now capture
    `sendRawCommand`'s response and, on `null` (failure), call a new
    `_notifyFailure(cmd)` helper that shows a `ScaffoldMessenger` `SnackBar`
    with `'Failed to send: ${commandLabel(cmd)}'` — same
    `ScaffoldMessenger.of(context).showSnackBar` pattern already used
    elsewhere in this codebase (`add_projector_dialog.dart`), no Riverpod
    involved. Geometry's four generic senders (`_sendMode`/`_sendInt`/
    `_sendDeg`/`_sendThrow`) converted from single-expression arrow
    functions to `async` bodies to capture the response; `_sendBool`
    unchanged since it just delegates to `_sendInt`. `dart analyze` clean
    (project-wide, not just the 3 files).

13. `[x]` **`OscService.start()` has no reentrancy guard.**
    (`osc_service.dart:171`) Overlapping `start()` calls could bind a second
    `RawDatagramSocket` without closing the first, leaking a socket — e.g.
    rapid toggling or a race between a Preferences save and app init. Fix:
    added a `_startGeneration` counter (same idiom as `_pollingGeneration`
    in `workspace_provider.dart`), bumped at the top of both `start()` and
    `stop()`. After `RawDatagramSocket.bind()`'s `await` resolves, `start()`
    checks whether its captured generation is still current — if a newer
    `start()`/`stop()` call superseded it while the bind was pending, the
    freshly-bound socket is closed immediately instead of being kept as
    `_socket`, so a losing concurrent call can't leak its bind. `dart
    analyze` clean.

14. `[~]` **Per-node polling is 11+ sequential connections, plus a
    redundant probe.** `pollProjectorTelemetry`
    (`panasonic_protocol_service.dart:185`) opened ~10-11 sequential new TCP
    connections with a full handshake/auth per projector per poll cycle,
    and `_pollSingleProjector` (`workspace_provider.dart`) sent a redundant
    extra `probeProjector` query before that chain even started (`QID` sent
    twice per node per poll cycle — once to classify reachability/auth via
    the now-dropped `probeProjector`, once again as `pollProjectorTelemetry`'s
    own first query). Not a bug — batching only overlapped *across* nodes,
    not within one — but worth addressing at the target scale of 120-150+
    projectors per install.

    Both parts now fixed, 2026-08-31:
    - The 10 telemetry queries after the initial `QID` check now fire
      concurrently via `Future.wait` instead of one at a time — same
      concurrent-queries-to-one-projector pattern already used by
      `geometry_correction_dialog.dart`'s `_loadCorner()`. The initial `QID`
      check stays first/sequential since it's a short-circuit (no point
      starting the other 10 if the projector's unreachable).
    - `probeProjector` deleted entirely (its only caller was
      `_pollSingleProjector`, immediately followed by
      `pollProjectorTelemetry` — no other call site existed) and its
      classification logic (`offline`/`unauthorized`/`online`/`unprotected`,
      same order/conditions as before) folded directly into
      `pollProjectorTelemetry`'s own initial `QID` check, which switched from
      `_sendSingleCommand` to `_sendSingleCommandEx` to also get `isProtected`
      for that classification. `pollProjectorTelemetry` now returns
      `(ProbeResult, Map<String, dynamic>?)` instead of just the nullable
      map; `_pollSingleProjector` destructures both from the one call instead
      of making two separate calls. `dart analyze` and `dart format` clean.

    **Pending: recheck on real hardware** (requested by user before
    committing) — confirm both changes behave correctly against actual
    projector models/firmware during a real poll cycle, not just the
    geometry dialog's existing read-only concurrent-query usage.
