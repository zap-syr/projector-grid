# Projector Grid — Performance & Architecture Optimization Plan

## Executive Summary

An in-depth performance and architectural audit of **Projector Grid** revealed several critical bottlenecks affecting GPU rendering, CPU cycles during user interactions, and network socket management when communicating with Panasonic projector hardware.

This document outlines the identified bottlenecks, their root causes, architectural solutions, and a prioritized implementation roadmap.

### Progress (branch `features/fixes`)

| Item | State |
|---|---|
| 1.1 RepaintBoundary — StatusBar / spinner / main sections | ✅ Done |
| 1.2 Isolate `GridPainter` + per-card `RepaintBoundary` | ✅ Done |
| 1.3 Marquee selection `setState` | ✅ Done |
| 2.1 `statusSummaryProvider` (+ `TopMenuBar` watch narrowing — folded in) | ✅ Done |
| 2.2 Decouple drag coords from global state | ✅ Done |
| 3.1 Socket concurrency / batch size | ✅ Done |
| 3.2 Lifecycle-throttled polling | ✅ Done (revised approach — see §3.2) |

All items reviewed against current source; per-section notes record where the audit's
claims or code snippets needed correction. Runtime profiling (DevTools §5) not yet run.

---

## 1. Critical Rendering & Repaint Isolation (GPU & UI Thread)

### 1.1 Unbounded Window Repaints Caused by Animated Progress Indicators — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean.
- `status_bar.dart`: `CircularProgressIndicator` wrapped in `RepaintBoundary` (stops the
  per-frame `markNeedsPaint` at the source rather than letting it bubble to the route layer).
- `main_workspace_screen.dart` (`_WorkspaceBody.build`): `StatusBar`, `ProjectorWorkspace`,
  `ControlBar`, `MonitoringTable`, and `EventLogPanel` each wrapped in their own
  `RepaintBoundary`.
- Deviation: the code snippet below assumes a flat `Column`; the real tree has a
  `_WorkspaceBody` → `IndexedStack` → `FocusScope` layout, so boundaries were placed to
  match the actual structure.
- Severity note: the spinner only animates *while a poll cycle is in flight* (a few seconds
  per 60 s interval), not continuously — real impact is smaller than described, but the fix
  is cheap and correct.


- **Location:** [`StatusBar`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/status_bar.dart#L84-L90), [`MainWorkspaceScreen`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/screens/main_workspace_screen.dart#L128)
- **Problem:** When telemetry polling runs, `CircularProgressIndicator` spins continuously using an `AnimationController.repeat()`. Because neither the spinner, the `StatusBar`, nor the parent containers have a `RepaintBoundary`, every frame (60 to 120 FPS) triggers `markNeedsPaint()` which bubbles up to the root window `RenderView`. The entire application window (including canvas, grid, and all static cards) is continuously repainted into GPU memory.
- **Impact:** Heavy GPU load, increased battery drain, fan noise, and micro-stutters during background polling.
- **Solution:**
  1. Wrap `CircularProgressIndicator` and [`StatusBar`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/status_bar.dart) in `RepaintBoundary`.
  2. Wrap major layout sections in [`MainWorkspaceScreen`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/screens/main_workspace_screen.dart) (`StatusBar`, `ProjectorWorkspace`, `ControlBar`, `MonitoringTable`, `EventLogPanel`) in dedicated `RepaintBoundary` widgets.

```dart
// main_workspace_screen.dart
Column(
  children: [
    const RepaintBoundary(child: StatusBar()),
    Expanded(
      child: IndexedStack(
        index: isMonitoringView ? 1 : 0,
        children: [
          FocusScope(
            node: _controlsScopeNode,
            child: const Row(
              children: [
                Expanded(child: RepaintBoundary(child: ProjectorWorkspace())),
                RepaintBoundary(child: ControlBar()),
              ],
            ),
          ),
          FocusScope(
            node: _monitoringScopeNode,
            child: const RepaintBoundary(child: MonitoringTable()),
          ),
        ],
      ),
    ),
    if (showLogs) RepaintBoundary(child: EventLogPanel(maxHeight: maxLogHeight)),
  ],
)
```

---

### 1.2 Interactive Card Movement & Canvas Repaints — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean.
- `projector_workspace.dart`: `GridPainter` was the *parent* `CustomPaint` wrapping the card
  `Stack`, so it shared a single layer with every card and `GridPainter.paint()` (~300
  `drawLine` calls across 3000 px) re-ran on every pointer move during a drag —
  `shouldRepaint` does **not** guard this, because `RenderCustomPaint` calls `painter.paint()`
  unconditionally whenever it is asked to paint. Fixed by inverting the relationship: the
  grid is now a `Positioned.fill` + `RepaintBoundary` as the bottom layer of the card `Stack`.
- `projector_card.dart`: each card's `Transform.scale` subtree wrapped in `RepaintBoundary`.
- Deviation from the snippet below: `RepaintBoundary(child: ProjectorCard(...))` **cannot**
  wrap the card from outside — it would sit between the `Stack` and the card's root
  `AnimatedPositioned`, triggering the "Positioned widgets must be placed directly inside
  Stack widgets" assertion. The boundary was placed *inside* the card, below
  `AnimatedPositioned`, achieving the same per-card layer isolation.

- **Location:** [`ProjectorWorkspace`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart#L682-L745), [`ProjectorCard`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_card.dart)
- **Problem:** 
  1. The background canvas grid (`CustomPaint(painter: GridPainter(...))`) spans 3000×3000 px and shares the same render layer as the projector cards.
  2. Dragging a card triggers updates on every pointer move event, forcing Flutter to repaint the entire 3000×3000 px grid and all other stationary projector cards.
- **Solution:**
  1. Isolate the `GridPainter` into its own `RepaintBoundary`.
  2. Wrap each [`ProjectorCard`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_card.dart) in `RepaintBoundary` inside the workspace `Stack`.

```dart
// projector_workspace.dart
RepaintBoundary(
  child: CustomPaint(
    painter: GridPainter(
      Theme.of(context).dividerColor.withValues(alpha: 0.1),
      _gridStep * _currentZoom,
    ),
  ),
),
Stack(
  clipBehavior: Clip.none,
  children: [
    ...nodes.map(
      (node) => RepaintBoundary(
        key: ValueKey('boundary_${node.id}'),
        child: ProjectorCard(
          key: ValueKey(node.id),
          node: node,
          ...
        ),
      ),
    ),
  ],
)
```

---

### 1.3 Rubber-band (Marquee) Selection Rebuilds — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean, `dart format` applied.
- `_selectionStart` / `_selectionCurrent` (setState-driven `Offset?` fields) replaced by a
  plain `Offset? _selectionAnchor` + a `ValueNotifier<Rect?> _marqueeRect` (disposed in
  `dispose`).
- `onPanStart/Update/End` no longer call `setState` — they write `_marqueeRect.value`, so
  `ProjectorWorkspace.build()` (and the ~100 `ProjectorCard` configs) is not re-run on
  every pointer move. `selectNodesInRect` is still called per move (that path already only
  rebuilds cards whose selection membership flipped, via `selectionProvider.select`).
- The overlay is now a `_MarqueePainter extends CustomPainter` with `super(repaint:
  _marqueeRect)`, mounted once via `Positioned.fill` + `IgnorePointer` + `CustomPaint`;
  the marquee drag repaints only that overlay.
- Deviation from the audit's suggestion: used a `CustomPainter` fed by the notifier via
  `super.repaint` rather than a `ValueListenableBuilder` — a `Positioned`/`Positioned.fill`
  cannot sit under a `ValueListenableBuilder` inside a `Stack` (parent-data chain breaks),
  and a full-canvas `RepaintBoundary` would allocate a 3000×3000 layer.
- Coordinates unchanged in effect: rect stored in screen (zoomed) space for painting,
  divided by `_currentZoom` only for node hit-testing.
- Not addressed (pre-existing, out of scope): no `onPanCancel` handler, so a cancelled
  pan leaves the marquee on screen until the next interaction — same as before.

- **Location:** [`ProjectorWorkspace`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart#L640-L675)
- **Problem:** During marquee selection (`onPanUpdate`), `setState(() { _selectionCurrent = details.localPosition; })` is invoked directly on `_ProjectorWorkspaceState`. This causes `ProjectorWorkspace.build()` to re-evaluate on every pixel of mouse drag, recreating the widget tree and all card instances.
- **Solution:** Extract the marquee rectangle overlay into a dedicated `CustomPainter` widget driven by an independent `ValueNotifier<Rect?>` or isolated sub-widget, preventing the parent `ProjectorWorkspace` and all card widgets from rebuilding during selection drags.

---

## 2. State Management & Rebuild Granularity (Riverpod & CPU)

### 2.1 Monolithic `workspaceProvider` Invalidation on Telemetry Polling — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean (only the 2
pre-existing, unrelated lints noted in 1.2/1.3).
- Added `status_summary_provider.dart`: a record-returning `@riverpod` function
  (single pass over `nodes`, unlike the audit's 3-pass sample). `StatusBar` now watches
  `statusSummaryProvider` instead of the raw `workspaceProvider` list; Dart record
  structural equality means it only rebuilds when a count actually changes.
- Folded in — `TopMenuBar` had the identical defect (verified via DevTools rebuild
  counts, 2026-09-01): `top_menu_bar.dart:133` did a bare `ref.watch(workspaceProvider)`
  purely to refresh Undo/Redo enabled state, rebuilding the menu bar on every poll tick
  and drag tick since it shared the outer layer with `MainToolbar`.
  - Added `edit_history_status_provider.dart` returning `({bool canUndo, bool canRedo})`.
    Turned out simpler than originally scoped: no notifier-side notify-plumbing was
    needed — every real `_undoStack`/`_redoStack` mutation (`_saveSnapshot`, `undo`,
    `redo`) already reassigns `state` in the same method (confirmed by reading every
    call site), so a provider that watches `workspaceProvider` and reads the notifier's
    `canUndo`/`canRedo` getters recomputes at exactly the right times; record equality
    then dedupes away the polling/drag ticks that leave undo/redo unchanged.
  - `TopMenuBar` now watches `editHistoryStatusProvider` for the Undo/Redo menu items
    instead of the raw list.
  - Also wrapped `TopMenuBar` + `MainToolbar` in `RepaintBoundary` in
    `main_workspace_screen.dart` as defense-in-depth.

- **Location:** [`workspaceProvider`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart#L232-L285), [`StatusBar`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/status_bar.dart#L13-L29)
- **Problem:**
  - `workspaceProvider` stores `List<ProjectorNode>` as a single monolithic state array.
  - When telemetry arrives for a single node (e.g. `runtime` or `lampHours` changes), a new `state` list is emitted.
  - In `StatusBar`, `ref.watch(workspaceProvider)` re-executes the build method, recalculating summary counts (`online`, `offline`, `warnings`, `total`) even when connection statuses did not change.
- **Solution:**
  - Use `.select()` with value equality or create a dedicated computed provider for status summaries:
  
```dart
// status_summary_provider.dart
@riverpod
({int total, int online, int offline, int warnings}) statusSummary(Ref ref) {
  final nodes = ref.watch(workspaceProvider);
  return (
    total: nodes.length,
    online: nodes.where((n) => n.connectionStatus == ConnectionStatus.connected || n.connectionStatus == ConnectionStatus.unprotected).length,
    offline: nodes.where((n) => n.connectionStatus == ConnectionStatus.offline).length,
    warnings: nodes.where((n) => n.errors != 'NO ERRORS' && n.errors != '-').length,
  );
}
```

---

### 2.2 Global State Mutation During Interactive Card Dragging — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean (same 2 pre-existing,
unrelated lints as before).
- `projector_workspace.dart`: added `ValueNotifier<Map<String, Offset>> _dragOverrides`
  (node id → live workspace-coordinate position while a drag is in progress). `onPanUpdate`
  now writes to it instead of calling `notifier.setNodePositionsFromDrag` on every pointer
  move — `workspaceProvider` is untouched during the gesture, so `ProjectorWorkspace.build()`
  no longer re-runs per move (it previously did, via its own bare `ref.watch(workspaceProvider)`,
  recreating all ~100 `ProjectorCard` configs on every tick — the "Additional gap" noted below
  the roadmap table). `onPanEnd` now does the one real commit:
  `notifier.setNodePositionsFromDrag(...)` with the final accumulated delta, then clears
  `_dragOverrides`, then the existing `snapNodeToGrid`/`endMove` calls, unchanged.
- Added local `_clampX`/`_clampY` mirroring `WorkspaceNotifier`'s (same formula, `_cardWidth`/
  `_cardHeight` already existed in this file) so the live preview lands exactly where the
  `onPanEnd` commit will — no jump at the workspace edge.
- `projector_card.dart`: the `isDragging` bool parameter (which went stale under this design —
  it was computed once per now-decoupled `ProjectorWorkspace.build()`) is replaced by a
  `ValueListenable<Map<String, Offset>> dragOverrides` parameter. `AnimatedPositioned` is now
  built inside a `ValueListenableBuilder` reading `dragOverrides[node.id]`; the heavy card
  subtree (menu, decorations, text) is passed through as `ValueListenableBuilder`'s `child` so
  it's never rebuilt — only the tiny `AnimatedPositioned` wrapper rebuilds per drag tick, for
  whichever card(s) are actually being dragged (multi-select drags populate one map entry per
  affected node). Confirmed safe against the `Positioned`-must-be-a-direct-`Stack`-descendant
  rule from 1.2/1.3: `ValueListenableBuilder` is not a `RenderObjectWidget` (only inserting
  another render widget, like `RepaintBoundary`, in that spot would break it).
- Review confirmed accurate: `setNodePositionsFromDrag` does **not** call
  `_notifyStateChanged()`, so the OSC broadcast was never spammed during drags — unaffected
  either way.

- **Location:** [`ProjectorWorkspace`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart#L739-L744)
- **Problem:** Every drag move event calls `notifier.setNodePositionsFromDrag(...)`, mutating the global Riverpod state. This causes all global listeners across the application to react to continuous pointer movements.
- **Solution:** Keep interactive drag deltas local to the workspace or within an ephemeral `ValueNotifier<Map<String, Offset>>` during active gestures, and commit the final coordinates to `workspaceProvider` only once on `onPanEnd`.

---

## 3. Network Architecture & Socket Management (NTCONTROL & Hardware Safety)

### 3.1 High Concurrency & Socket Explosion During Polling — ✅ DONE

**Status:** Implemented on `features/fixes`. `dart analyze` clean (same 2 pre-existing,
unrelated lints as before). Approach changed from the original plan below after a
research pass (web search + fetching Panasonic's own LAN Control Protocol PDF and
Command Control FAQ) — see notes.

**Research findings (superseding the original "lower `_networkBatchSize`" plan):**
- Panasonic never publishes a max-concurrent-connections number for the NTCONTROL port
  (checked the official LAN protocol PDF, the Command Control FAQ, and several projector
  manuals). The protocol is documented as connect → send one command → get one response →
  disconnect (or 30s idle timeout) — one command per connection cycle, no pipelining. `ERR3`
  is officially "Busy state or unavailable period" — Panasonic's own spec names exactly the
  failure mode this item worried about.
- No official number, but this device class commonly runs lwIP-style embedded stacks, whose
  stock profiles cap out at 5–16 *total* TCP connections for the whole device (shared with
  its web UI, etc.) — a 10-wide burst from polling alone is a plausible way to exhaust that
  pool by itself.
- Client-side (the PC running this app) is not the real constraint on Windows: the old
  "max 10 half-open outbound connections" throttle was removed starting Vista SP2, and
  Windows 10/11's default ephemeral port range (49152–65535, ~16k ports) comfortably covers
  even the old 1000-socket worst case.
- **macOS is a separate, concrete, currently-live bug independent of projector count**: the
  default per-process open-file soft limit (`ulimit -n`) is 256, and nothing in this codebase
  raises it. At the pre-fix design (10 sockets/node × `_networkBatchSize` 100), a batch of
  just ~26 projectors already exceeded 256 open file descriptors — this could plausibly cause
  spurious "offline"/error states on macOS at far smaller scale than 50–150 nodes, for a
  reason having nothing to do with the projector hardware.
- The real fix belongs at the *per-node* concurrency layer (currently 10 simultaneous
  connections to the same projector), not `_networkBatchSize` (which only bounds how many
  *different* projectors overlap — the 1000-socket worst case is spread across ~100 different
  IPs, never 1000 at one projector). The user explicitly did not want `_networkBatchSize`
  reduced, and fixing the per-node layer resolves both the projector-side risk and the
  macOS fd-limit bug without touching it.

**Implemented — bounded per-node concurrency pool with a project-size-based dynamic cap:**
- `panasonic_protocol_service.dart`: added `_runBounded<T>`, a small fixed-worker-pool
  helper (no external dependency) that runs a list of task closures with at most
  `concurrency` in flight at once, preserving result order. `pollProjectorTelemetry` now
  takes a `{int concurrency = 2}` parameter and runs its 10 telemetry queries through
  `_runBounded` instead of a flat `Future.wait`.
- `workspace_provider.dart`: added `_telemetryConcurrencyFor(totalNodes)` — ≤15 nodes → 5,
  ≤40 nodes → 3, otherwise → 2. Computed once per poll cycle in `_pollAllProjectors` (from
  `currentIds.length`) and threaded through `_pollSingleProjector` to
  `pollProjectorTelemetry(..., concurrency: ...)`. The two ad-hoc single-node poll call
  sites (`addProjectors`, `_checkAndSetNodeStatus`) use the same tiered function against the
  current node count for consistency.
- At the user's stated 50–150 scale this lands on concurrency=2: worst case total in-flight
  sockets = `_networkBatchSize` (100, unchanged) × 2 = 200 — under macOS's 256 default (fixing
  that bug too) and comfortably under Windows' ephemeral-port ceiling, while still polling all
  10 queries per node in ~5 waves of 2 instead of paying full sequential latency.
- Not implemented: consolidating all 10 queries onto a single reused connection per node
  (would cut connections further, to 1 per node, and remove 9 redundant handshakes/MD5
  computes) — considered as a "more thorough" alternative but not chosen, since it trades
  away the parallel-queries speed (10 sequential round-trips vs. ~5 waves of 2) for a benefit
  the pool approach already captures. Worth revisiting later if handshake overhead itself
  becomes a measured concern.

- **Location:** [`PanasonicProtocolService.pollProjectorTelemetry`](file:///D:/Flutter%20Dev/projector-grid/lib/core/services/panasonic_protocol_service.dart#L280-L291), [`workspaceProvider`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart#L584)
- **Problem:**
  - `_networkBatchSize` is configured to `100` nodes.
  - For each node, `pollProjectorTelemetry` fires 10 simultaneous TCP connection requests via `Future.wait([_sendSingleCommand(... x10)])`.
  - **Risk:** 100 nodes × 10 concurrent requests = **up to 1,000 simultaneous TCP sockets** attempting to open against the network and hardware controllers.
  - Embedded NICs on Panasonic projectors often support only 1 to 4 concurrent TCP connections. Firing 10 parallel TCP handshakes at the same projector IP causes socket timeouts, TCP resets (`RST`), or dropped packets.
- **Solution:**
  1. **Limit per-node concurrency:** Pipeline telemetry queries sequentially or in small pairs (max 2 parallel connections per IP) using a dedicated worker queue.
  2. **Reduce global batch size:** Lower `_networkBatchSize` to a safe threshold (e.g. 10–20 nodes concurrently).
  3. **Sequential Pipeline Helper:**

```dart
// Serial execution per projector prevents hardware TCP buffer overflow
Future<List<String>> _sendSequentialCommands(
  String ip, int port, String login, String password, List<String> commands
) async {
  final results = <String>[];
  for (final cmd in commands) {
    results.add(await _sendSingleCommand(ip, port, login, password, cmd));
  }
  return results;
}
```

---

### 3.2 Lifecycle-Aware Network Activity — ✅ DONE (revised approach)

**Status:** Implemented on `features/fixes`. `dart analyze` clean (same 2 pre-existing,
unrelated lints as before).

**Review:** The observation was correct (plain `Timer`, no lifecycle gating), but the
audit's suggested fix — pause polling entirely while minimized/unfocused — was rejected:
for a projector *monitoring* tool, going fully silent means the event log stops catching
projectors going offline / hardware faults precisely when nobody is looking at the window.
Asked the user directly; agreed middle ground: **slow down, don't stop**, and catch up
immediately on return.

**Implemented:**
- `workspace_provider.dart`: `WorkspaceNotifier` now `with WindowListener`
  (`package:window_manager`, already a dependency — used the same way
  `_WindowGeometryPersistence` in `main.dart` does), registered/unregistered in
  `build()`/`ref.onDispose()`.
- Tracks `_isWindowMinimized` and `_isWindowFocused` separately (`onWindowMinimize`/
  `onWindowRestore`/`onWindowFocus`/`onWindowBlur`); backgrounded = either one true, so
  clicking away to another app without minimizing counts the same as minimizing.
- `_scheduleNextPoll` multiplies the user-configured interval by
  `_backgroundIntervalMultiplier` (3x) when backgrounded, computed fresh on every
  reschedule rather than mutating `_pollingIntervalSeconds` itself — so a foreground/
  background transition takes effect on the very next tick without needing to cancel and
  re-arm the timer immediately, and the user's actual configured interval is never
  overwritten.
- On returning to the foreground (restore or refocus), calls `refreshAll()` immediately
  instead of waiting out the slower cadence — same semantics as a manual F5/Refresh
  (resets the countdown too), so the UI never shows stale background-rate data right when
  you look back at it.
- Deviation from the original snippet: used `window_manager`'s `WindowListener` rather
  than `WidgetsBindingObserver.didChangeAppLifecycleState` — this lives in a Riverpod
  notifier, not a widget, and `window_manager` gives precise minimize/restore/focus/blur
  events (already proven in this codebase) rather than Flutter's coarser desktop lifecycle
  states.

- **Location:** [`workspaceProvider`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart)

---

## 4. Prioritized Implementation Roadmap

| Priority | Task | Status | Complexity | Impact | Target Files |
|---|---|---|---|---|---|
| **P0 (Critical)** | Add `RepaintBoundary` around `StatusBar`, `CircularProgressIndicator`, and main window sections | ✅ Done | Low (15 mins) | Massive GPU drop (eliminates 60 FPS full-window repaints) | [`main_workspace_screen.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/screens/main_workspace_screen.dart), [`status_bar.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/status_bar.dart) |
| **P0 (Critical)** | Isolate `GridPainter` and individual `ProjectorCard` widgets with `RepaintBoundary` | ✅ Done | Low (15 mins) | Eliminates full-screen repaints during card dragging | [`projector_workspace.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart), [`projector_card.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_card.dart) |
| **P1 (High)** | Fix socket explosion in `pollProjectorTelemetry` & throttle per-node concurrency | ✅ Done | Medium (1 hour) | Prevents projector NIC overload, eliminates connection drops | [`panasonic_protocol_service.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/core/services/panasonic_protocol_service.dart), [`workspace_provider.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart) |
| **P1 (High)** | Add fine-grained `statusSummaryProvider` to decouple `StatusBar` from node telemetry changes — **also narrow `TopMenuBar`'s bare `workspaceProvider` watch to an `editHistoryStatusProvider`** (same defect, confirmed via rebuild counts) | ✅ Done | Low (45 mins) | Prevents unnecessary `StatusBar` **and menu-bar/toolbar** rebuilds/repaints on every telemetry tick and card-drag tick | [`status_bar.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/status_bar.dart), [`top_menu_bar.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/top_menu_bar.dart), `status_summary_provider.dart` |
| **P2 (Medium)** | Decouple interactive card dragging coordinates from global Riverpod state until `onPanEnd` | ✅ Done | Medium (2 hours) | Eliminates global Riverpod rebuild cycles on mouse moves | [`projector_workspace.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart), [`workspace_provider.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart) |
| **P2 (Medium)** | Separate Marquee Selection rubber-band rectangle from `ProjectorWorkspace` `setState` | ✅ Done | Low (45 mins) | Prevents card widget reconstruction during area selections | [`projector_workspace.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/widgets/projector_workspace.dart) |
| **P3 (Low)** | Add desktop lifecycle throttling for auto-polling when window is minimized | ✅ Done | Low (30 mins) | Reduces background network traffic on idle workstations, without losing offline/fault detection | [`workspace_provider.dart`](file:///D:/Flutter%20Dev/projector-grid/lib/features/workspace/presentation/providers/workspace_provider.dart) |

> **Review notes (not in original audit):**
> - **P3 revised:** fully pausing polling while minimized would've stopped the event log
>   from capturing projectors dropping offline / hardware faults exactly when the operator
>   isn't watching. Implemented instead as a 3x-slower background cadence plus an immediate
>   refresh on return to the foreground — see §3.2.
> - **Additional gap (partially closed by 2.2):** `ProjectorWorkspace.build()` still re-runs on
>   *every telemetry poll cycle* (`ref.watch(workspaceProvider)`), recreating all ~100
>   `ProjectorCard` configs — `RepaintBoundary` bounds raster cost, not rebuild cost. 2.2 closed
>   this specifically for *dragging* (drags no longer touch `workspaceProvider` mid-gesture), but
>   the poll-cycle case remains. A full fix needs layout state (id/x/y/groupId) split from
>   per-node telemetry (`.select` or a family provider) — larger refactor, worth scheduling as
>   its own item.
> - **Shared constant:** `_dispatchToNodes` also uses `_networkBatchSize = 100` (1 socket
>   per node, less severe than polling's 10×), so lowering that constant helps both paths.

---

## 5. Verification & Profiling Checklist

1. **Repaint Verification (Flutter DevTools):**
   - Enable **Highlight Repaints** in DevTools.
   - Verify that polling telemetry only highlights the 12×12 px indicator area.
   - Verify that dragging a card only highlights that specific card or canvas, keeping sidebars and toolbars static.
2. **Rebuild Tracking (Flutter DevTools):**
   - Enable **Track Widget Rebuilds**.
   - Verify that changing a projector's temperature or runtime does not rebuild `StatusBar`, `ControlBar`, or non-relevant cards.
3. **Network & Socket Inspection (Wireshark):**
   - Filter by `tcp.port == 1024`.
   - Verify that concurrent TCP handshakes to any single projector IP do not exceed 2 simultaneous connections.
   - Verify that TCP connections cleanly terminate with proper `FIN`/`ACK` sequences without orphaned sockets.
