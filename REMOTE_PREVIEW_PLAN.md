# Remote Preview — Feature Plan

Working doc for adding a live input-signal preview (Panasonic "RemoView") to
Projector Grid.
Status legend: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not applicable

Branch: `features/remote-preview`.

---

## 1. Research — how the projector's web UI does it

Investigated the PT-series web control UI at `http://192.168.0.8` (digest auth,
realm `WEB Zone`). The preview page nests several frames:

```
index.cgi → main.cgi?page=MENU_PREVIEW → rightframe.cgi
          → remote_preview.cgi → preview.cgi   ← all the logic lives here
```

`preview.cgi` renders the `<img id="RemoViewSample">` and a `<text id="RemoViewText">`
overlay, then opens **one WebSocket** and pushes frames into the `<img>`:

```js
var socket = new WebSocket('ws://' + location.hostname + '/remotepreview', 'pj-cast-protocol');
socket.addEventListener('open', () => { socket.send('start'); /* + 'alive' every 5 s */ });
socket.addEventListener('message', e => {
  if (e.data instanceof Blob) {                 // a complete JPEG
    URL.revokeObjectURL(url);
    url = URL.createObjectURL(e.data);
    ele_img.src = url;                          // <-- this is the blob: URL you saw
  } else { /* text status string */ }
});
```

### The `blob:` URL is not reusable

`blob:http://192.168.0.8/43738377-…` is a client-side object URL minted by
`URL.createObjectURL()`. It only resolves inside that one document and is revoked
on the next frame. Copying it anywhere else is useless. **The reusable thing is
the WebSocket feed underneath it**, and that we can consume directly.

### Protocol: `ws://<ip>/remotepreview`, subprotocol `pj-cast-protocol`

| Direction | Message | Meaning |
|---|---|---|
| C→S | `start` | begin streaming (send once, on open) |
| C→S | `alive` | keepalive, every 5000 ms |
| C→S | `PONG` | reply to a `PING` |
| C→S | `receive` | ack after **any** other server message |
| C→S | `preshow:1` / `preshow:0` | enter / leave **pre-show** — keeps the input board feeding the preview while the projector stays in Standby (§4.3) |
| S→C | *binary* | one complete **JPEG**, 480×270, ~25 KB |
| S→C | `PING` | liveness probe → reply `PONG` |
| S→C | `NONE` | image is valid, clear the text overlay |
| S→C | `NOSIGNAL` | "No signal" |
| S→C | `HDCP` | "HDCP-protected content" — **no image is sent**, expected, not an error |
| S→C | `TESTPATTERN` | "Projecting test pattern" |
| S→C | `ASPECT` | preview aspect ratio differs from the projected image (image still shown) |
| S→C | `STARTINGUP` | "Starting up" |
| S→C | `ROTATE` | "Image rotating" |
| S→C | `IMPOSSIBLE` | "Not able to get image from the device" |
| S→C | `BLANK` | hide both image and text |
| S→C | `REFRESH` / `SIGNAL` / `CHANGING_PRE` | UI-refresh hints for the projector's own page; we can ignore |
| S→C | `CLOSE` | server is closing the stream |

### Auth / transport notes (measured)

- The `/remotepreview` WebSocket **takes the upgrade with no `Authorization`
  header** — the first handshake returned `101 Switching Protocols` and frames
  started, even though the rest of the web UI requires digest auth. Per the user
  this holds across the fleet: **same unauthenticated socket on every model**, so
  no digest handshake to build. A `401` would be a surprise to handle if it ever
  turns up, not something to code for now.
- Transport is plain `ws://` on **fixed HTTP port 80** (same on every model per
  the user), i.e. *not* `node.port` (1024, the NTCONTROL port). Hard-code 80.
- Frame rate is ~1 fps, ~25 KB/frame — trivial bandwidth, several concurrent
  previews are fine.
- **Concurrent preview clients are fine** — verified: the projector's own web
  preview page and Panasonic's Multi Monitoring & Control Software stream at the
  same time, neither evicts the other. No tight per-projector session cap to
  design around. `CLOSE` is a graceful end-of-stream from the projector (reboot,
  input switch) — handle it as a soft state, not a crash.

### Reference capture script

`tool/remote_preview_test.dart` (to be added, per the `tool/*_test.dart`
convention): hard-coded IP near the top, opens the socket, prints text messages,
writes the first few JPEG frames to disk. Mirrors the throwaway Python probe used
during research.

---

## 2. "Preview not available"

Whenever the feed cannot be shown, the dialog/cell shows a single neutral line:
**"Preview not available"** (plus a **Retry** button in the dialog).

Trigger it on any of:

- `node.connectionStatus == offline` → don't even open a socket, show it
  immediately.
- `WebSocket.connect` throws (`SocketException`, `WebSocketException`) or exceeds
  a 5 s connect timeout.
- Handshake returns non-`101` (e.g. `401` after a digest retry also fails, `404`
  on firmware without RemoView).
- Socket closes before the first frame, or `IMPOSSIBLE` is received.
- No frame **and** no text message for ~15 s (stall watchdog).

Distinct from "Preview not available": `NOSIGNAL`, `HDCP`, `STARTINGUP`, etc. —
those mean the feed *is* working, so show their own specific text, not the
unavailable state.

State machine for the controller:

```
connecting ──success──▶ streaming ⇄ status(text)      ("No signal", "HDCP", …)
     │                      │
   failure                fatal (CLOSE / IMPOSSIBLE / socket done / stall)
     ▼                      ▼
        unavailable  ◀───────┘        → "Preview not available" + Retry
```

---

## 3. Architecture

### 3.1 Service — `lib/core/services/remote_preview_service.dart` (new)

Plain Dart, no codegen. One class owns one socket:

```dart
sealed class RemotePreviewEvent {}
class PreviewFrame     extends RemotePreviewEvent { final Uint8List jpeg; }
class PreviewStatus    extends RemotePreviewEvent { final RemotePreviewState state; final String? label; }

enum RemotePreviewState { connecting, streaming, noSignal, hdcp, testPattern,
                          startingUp, rotating, blank, unavailable }

class RemotePreviewController {
  RemotePreviewController({required this.host});         // host only; port 80 fixed
  Stream<RemotePreviewEvent> get events;
  void start();      // connect + 'start' + alive timer
  void retry();
  void dispose();    // close socket, cancel timers  ← must be idempotent
}
```

Responsibilities: connect with `protocols: ['pj-cast-protocol']`, send `start`,
`Timer.periodic(5 s)` → `alive`, answer `PING`/others, translate text messages to
`RemotePreviewState`, own the connect-timeout + stall watchdog, expose a single
broadcast stream. No Riverpod inside the service.

Pre-show (§4.3) rides two channels: the toggle command goes over this WebSocket
(`preshow:1` / `preshow:0`), but the **current** pre-show state is read over
NTCONTROL via the existing `panasonic_protocol_service.dart` (`QVX:PSMI1`). So
the preview provider (§3.2), not this service, wires the two together — the
service stays preview-only.

### 3.2 Provider — `remotePreviewProvider`

`lib/features/workspace/presentation/providers/remote_preview_provider.dart`

- `@riverpod`, **family by `nodeId`**, **not** `keepAlive` — wraps one
  `RemotePreviewController`, exposes an `AsyncValue`/sealed snapshot the UI
  watches. The socket dies when the last widget stops listening
  (`ref.onDispose(controller.dispose)`); two viewports on the same node (e.g. the
  menu-opened dialog and the table button hit in quick succession) share one
  socket while either is mounted, and nothing leaks.
- Does **not** touch `workspaceProvider` polling — preview is transient
  telemetry, never persisted, never part of the poll cycle or undo snapshots.
- Deliberately shell-agnostic: no `Navigator` / `showDialog` / window assumptions
  live in the provider or the service, so the §5.3 migration swaps only the outer
  wrapper.

### 3.3 No model change

`ProjectorNode` gets no new field. Preview is live-only.

---

## 4. UI integration

### 4.1 Right-click context menu — "Remote Preview"

`projector_card.dart` `MenuAnchor.menuChildren`: add after **Geometry
Correction**, before the divider / **Open in Browser**:

```dart
MenuItemButton(
  onPressed: () => _closeAndRun(widget.onRemotePreview),
  leadingIcon: const Icon(Icons.cast),        // or Icons.preview / Icons.monitor
  child: const Text('Remote Preview'),
),
```

Thread an `onRemotePreview` callback through `ProjectorCard` → `projector_workspace.dart`
alongside the existing `onBrightnessControl` / `onColorCorrection` wiring.

**Selection-aware target set** — follow the existing `_buildGroupMenuItems`
convention ("if the node is selected, apply to all selected"):

```dart
onRemotePreview: () {
  final selected = ref.read(selectionProvider);
  final nodes = selected.contains(node.id) && selected.length > 1
      ? projectors.where((n) => selected.contains(n.id)).toList()
      : [node];
  showRemotePreviewDialog(context, nodes);   // 1 node → single (§5.1), N → grid (§5.2)
},
```

So: right-click one card → single preview. Select a group (e.g. via **Select in
Group**, or a marquee / Ctrl-click), right-click any card in it → **one multiview
window** with a tile per selected projector (§5.2). The menu label stays
"Remote Preview" in both cases.

### 4.2 Monitoring table — "Preview" column

`monitoring_table.dart`: new `_Column`

```dart
_Column(
  id: 'preview',
  label: 'Preview',
  defaultWidth: 72,
  text: (n, _) => '',                       // nothing to auto-fit / tooltip
  sortKey: (n, _) => 0,                     // not meaningfully sortable
  cell: (context, n, _) => IconButton(
    icon: const Icon(Icons.cast, size: 18),
    tooltip: 'Open remote preview',
    onPressed: () => showRemotePreviewDialog(context, [n]),
  ),
),
```

- Register in `_allColumns` and `_columnsById`.
- **Not** in `_defaultVisibleIds` — opt-in via View ▸ Monitoring Table ▸ Columns,
  same as other non-default columns.
- Confirm the header sort path tolerates a constant `sortKey` (clicking the
  header is a no-op); if not, mark the column non-sortable in the header
  builder.
- The cell is just a launcher button, **single projector only** — the Monitoring
  table is view-only and has no selection, so there is no multiview entry point
  here. It does **not** hold a socket — showing a live "available/unavailable"
  dot per row would mean one socket per projector held open permanently;
  explicitly out of scope for v1.

### 4.3 Pre-show mode

Pre-show keeps the projector's input processing powered while the unit sits in
**Standby**, so the preview streams without lighting the lamp. Toggled over the
same socket: `preshow:1` / `preshow:0`.

- **Single window** — a "Pre-show mode" toggle in the window's control strip
  (below the viewport). **Enabled only when `node.powerStatus == standby`**; a
  powered-on projector already previews, so the button is **hard-disabled** (not
  hidden) with a hint, in every state.
- **Multiview** — one toggle acting on the **eligible subset**: tiles that are
  **both in Standby and have a live WebSocket**. Projectors that are powered on,
  offline, or whose feed failed are skipped. The button subtitle names the count
  ("On for 2 of 4").
- **Status** — while pre-show is active a `PRE-SHOW` corner tag sits over the
  image (the same slot as the `ASPECT` tag). The shutter frame colour
  (green/red) only applies once the projector is on; in Standby the frame stays
  neutral grey.
- **Pre-show is sticky on the projector** — verified: it survives the socket
  closing (enabled via the web UI, page closed, reopened → still on). So closing
  our window does **not** auto-send `preshow:0`; the toggle is the only control,
  and closing a window with pre-show still on shows a one-line hint that it stays
  active. We never save it to the project file.
- **Initial toggle state** — read it over NTCONTROL when the window opens:
  `QVX:PSMI1` → reply `PSMI1=+00000` (off) / `PSMI1=+00001` (on), through the
  existing `panasonic_protocol_service.dart` TCP link (the app already talks
  NTCONTROL to every projector). Re-query after sending `preshow:1` / `preshow:0`
  to confirm the change landed; optionally re-poll while the window is open. The
  preview WebSocket itself never reports this.

---

## 5. The preview window

**Decision: `showRemotePreviewDialog(context, nodes)` — a modal `showDialog`
now, with a clean migration to the Flutter windowing API once that reaches the
stable channel (§5.3).** One projector or a group both go through the same entry
point; length 1 → single layout, length > 1 → grid (§5.2).

### 5.0 Options considered (Flutter 3.47, Aug 2026)

| Option | Verdict |
|---|---|
| **Modal `showDialog`** ✅ now | Chosen for v1. Built-in, matches every other per-projector dialog in `projector_workspace.dart`, single widget tree so it reads `remotePreviewProvider` / `workspaceProvider` / the NTCONTROL service directly, zero new dependency, ships on the current Flutter branch. Cost the user accepted: it is modal — the workspace is blocked while a preview is open, one preview (single or grid) at a time. Can be made draggable within the barrier; not resizable beyond a preset or two. |
| **Official Flutter windowing API** (`runWidget` + `WindowController` / `RegularWindowController` + `Window` / `DialogWindow`) ✅ later | The migration target. Real OS windows that leave the main window and cross monitors, single widget tree, **state shared via Riverpod out of the box** — so moving the dialog body into a `Window` is a shell swap, not a rewrite (§5.3). Blocked today: **experimental**, flag `flutter config --enable-windowing` is **`main`-channel only** ("main or nothing"), every class is `@internal` (`import 'package:flutter/src/widgets/_window.dart'` + an `invalid_use_of_internal_member` ignore), Flutter's own docs say *"Do not use windowing APIs in production applications"*, breaking changes land **in patch releases**, no widget-test support, pre-launch checklist (flutter/flutter#177586) has no milestone. This app is a production tool on a pinned branch with a delicate `window_manager` close/quit flow — not the place for that yet. |
| **`desktop_multi_window`** (mixin.dev, v0.3.1) | Rejected. Real detached windows on the current branch, but **one Flutter engine per extra window**: separate Dart isolate/heap, no shared `ProviderContainer`, cross-window comms only as serialized method-channel messages, per-engine plugin registration in `windows/runner` + `macos/Runner` (folders the analyzer doesn't lint), tens of MB RAM per popped-out window, README needs a fork of `window_manager` (project is on `^0.5.1`), and orphaned child windows to reconcile with the existing quit flow. Disproportionate for a 480×270 feed; revisit only if a detached window becomes a hard requirement before the windowing API stabilises. |
| **In-app modeless overlay layer** | Rejected by the user — a floating `Stack`/`OverlayEntry` panel is non-blocking and multi-instance, but it cannot leave the main window or move to another monitor, which is the property they want most. |

### 5.1 The dialog — `RemotePreviewDialog`

`lib/features/workspace/presentation/widgets/remote_preview_dialog.dart`.
`showRemotePreviewDialog(BuildContext, List<ProjectorNode>)` calls `showDialog`
(`barrierDismissible: true`, so click-outside / Esc closes) with a
`ConsumerStatefulWidget` `Dialog` (not full-screen). Wired from
`projector_workspace.dart` like the other dialogs.

Body:

- a **title bar** — projector **model**, **IP**, and **group name** if it's in
  one (grid: window title + group tag). Optionally a drag handle
  (`GestureDetector.onPanUpdate` + `Transform.translate`) so it can be nudged off
  whatever you want to watch — still modal, just repositionable.
- one or more **`PreviewViewport`** widgets (§5.2) — black plane, 16:9,
  `Image.memory(frame, gaplessPlayback: true)` (`gaplessPlayback` kills the
  inter-frame flicker), 2 px frame coloured by shutter (green open / red closed /
  grey when the projector isn't on). Status rendering: **`TESTPATTERN`, `ASPECT`
  (and later `PRE-SHOW`) are corner tags over the still-visible image** — frames
  keep coming, so we annotate rather than replace; `NONE` clears the tag.
  **`NOSIGNAL` / `HDCP` / `STARTINGUP` / `ROTATE` hide the image and show centred
  plane text** (no frames come), as does **"Preview not available" + Retry**.
  Note (measured): a **built-in** colour-bars pattern arrives as plain frames
  with only `NONE`, so it shows untagged — the `TESTPATTERN` word is reserved for
  a different (pushed / pre-show) pattern source.
- the **pre-show control strip** (§4.3).

Sizing: a sensible fixed size (e.g. viewport ~640×360 for single), the grid sizes
to its tile count; no live resize handle in the modal form.

Lifecycle: each `PreviewViewport` `ref.watch`es `remotePreviewProvider(nodeId)`;
dismissing the dialog unmounts them, which drops the listeners and closes the
socket(s). Nothing persisted.

### 5.2 Multiview — group / multi-selection

When the target set has 2+ projectors (§4.1), the same dialog renders **one grid**
of tiles instead of a single viewport — titled "Remote Preview — 4 projectors"
(or the group name + count).

- **Tile** = the same `PreviewViewport` widget as the single case (single is a
  1×1 grid): 16:9 `Image.memory(..., gaplessPlayback: true)`, a caption strip
  (model + group, IP on the right), and its **own** per-tile status —
  `NOSIGNAL` / `HDCP` / **"Preview not available" + Retry** are per-tile, one
  dead projector doesn't blank the others.
- **Independent sockets** — one `remotePreviewProvider(nodeId)` per tile, N
  sockets open while the dialog is up, all torn down together on dismiss.
  Bandwidth is still negligible (~25 KB/frame @ ~1 fps × N).
- **Layout**: `GridView` with column count from tile count
  (2 → 1×2, 3–4 → 2×2, 5–6 → 3×2, 7–9 → 3×3, then scroll). Tiles keep 16:9.
- **Tile interactions**: none required in v1. (Double-click-to-isolate a tile
  needs a second dialog on top of the first — defer; it lands naturally once
  §5.3 makes each preview its own window.)
- Also reachable from a toolbar / View-menu "Preview selection" action; the
  context-menu item is just the first entry point.

### 5.3 Migration path — Flutter windowing API

When `--enable-windowing` reaches **beta/stable**, promote each preview to a real
OS window. What changes:

- `showRemotePreviewDialog(context, nodes)` → `openRemotePreviewWindow(ref, nodes)`
  that creates a `WindowController` and mounts the **same** `RemotePreviewDialog`
  body inside a `Window` / `RegularWindow` widget instead of a `Dialog`. The two
  call sites (context menu §4.1, table §4.2) change one line each.
- App bootstrap moves from `runApp` to `runWidget` — reconcile once with the
  `window_manager` / `setPreventClose` / `projector_grid/quit` flow
  (main.cpp / `main_workspace_screen.dart` / `main.dart`). This is the only
  non-trivial part.
- `remote_preview_service.dart`, `remotePreviewProvider`, `PreviewViewport`, the
  pre-show logic — **unchanged**. The widget tree stays single, so providers keep
  working across windows with no engine/state split.
- New capability unlocked: several previews open at once, each draggable outside
  the main window and onto another monitor; drop the modal barrier; add a real
  resize handle.

Keeping §3.2's "shell-agnostic" rule (no `Navigator`/window assumptions in the
service or provider) is what makes this a wrapper swap.

### 5.4 Not recommended

- **`desktop_multi_window` as a stopgap** — see §5.0; a whole second-engine
  architecture and native glue to delete later when the windowing API lands.
- **Docked pane that follows selection** (like `event_log_panel.dart`) — only
  ever shows one projector, fights the log panel for the same screen edge.

---

## 6. Phasing

- **Phase 1 — protocol + dialog** ✅ (analyzer + `flutter build windows` clean)
  - `[x]` `remote_preview_service.dart` — `RemotePreviewController`, sealed
    `RemotePreviewState`, connect-timeout + **first-frame watchdog**. Shell-
    agnostic (§3.2). Note: the projector stops pushing frames while the source
    image is static (verified — 1 frame then 20 s silence), so the watchdog
    guards only the *first* frame; after that a dropped feed is caught by the
    socket's `onError`/`onDone`, and silence just holds the last frame.
  - `[x]` `tool/remote_preview_test.dart` capture script (verified against
    `192.168.0.8` — 101 upgrade, JPEG frames, `NONE`, PING/PONG).
    Finding: the projector's **built-in test patterns stream as ordinary
    frames** with only `NONE` — no `TESTPATTERN` message. That message is for a
    different pattern source (pre-show / pushed image). So a built-in colour-bars
    pattern shows in the preview with no tag, which is correct; the
    `TESTPATTERN` → corner-tag path stays for when the message does arrive.
  - `[x]` `remotePreviewProvider` family (keyed by host/IP, not `keepAlive`).
  - `[x]` `PreviewViewport` widget — plane, shutter frame, `TESTPATTERN` /
    `ASPECT` corner tag over the live frame, centred plane text for
    `NOSIGNAL` / `HDCP` / `STARTINGUP` / `ROTATE`, Retry, offline short-circuit.
  - `[x]` `RemotePreviewDialog` + `showRemotePreviewDialog(context, nodes,
    groups:)`; 1 → single viewport, N → grid (§5.2).
  - `[x]` Context-menu "Remote Preview" item (`Icons.cast`, after Geometry
    Correction) + selection-aware wiring in `projector_workspace.dart` (§4.1).
  - `[x]` "Preview not available" + Retry per viewport; offline projectors don't
    open a socket until Retry forces it.
- **Phase 2 — table entry point + pre-show**
  - `[ ]` Monitoring-table "Preview" column (opt-in, single projector).
  - `[ ]` Pre-show toggle — single (Standby-gated, hard-disabled otherwise) +
    grid (eligible subset); init from `QVX:PSMI1`, `PRE-SHOW` plane badge,
    sticky across teardown.
  - `[ ]` Toolbar / View-menu "Preview selection" action.
- **Phase 3 — polish (all optional)**
  - `[ ]` Draggable-within-barrier dialog; a preset "large" size.
  - `[ ]` `ASPECT` warning styling; small "live" indicator + fps.
- **Later — windowing-API migration (§5.3)**, gated on `--enable-windowing`
  reaching beta/stable:
  - `[ ]` `runApp` → `runWidget`, reconciled with the `window_manager` / quit
    flow.
  - `[ ]` `showRemotePreviewDialog` → `openRemotePreviewWindow`; `Dialog` body
    re-hosted in a `Window`. Service / provider / `PreviewViewport` untouched.
  - `[ ]` Multiple concurrent windows, detach across monitors, real resize,
    double-click a grid tile to pop it out.

---

## 7. Open questions

None blocking. All the protocol unknowns from earlier drafts are resolved below.

### Resolved

- **Auth** — the `/remotepreview` WebSocket takes the upgrade unauthenticated on
  **every model** (user), same as the tested unit. No digest handshake to build.
- **Endpoint** — always `ws://<ip>:80/remotepreview`, fixed port, no `wss://`
  (user). No per-node override needed.
- **Pre-show while powered on** — button is **hard-disabled** when the projector
  is on (user), so whether `preshow:1` would no-op in that state is moot.
- **Concurrent clients** — no tight single-session limit. The projector's own
  web preview and Panasonic's Multi Monitoring & Control Software stream
  simultaneously (user-verified). `CLOSE` is a graceful shutdown hint, not an
  eviction to design around.
- **Pre-show persistence** — pre-show survives the socket closing (user-verified
  via the web UI). Teardown must not clear it; the toggle is the only control.
- **Pre-show state readback** — `QVX:PSMI1` over NTCONTROL returns
  `PSMI1=+00000` (off) / `PSMI1=+00001` (on). The toggle initialises from this
  on window open; no indeterminate state needed. (§3.1, §4.3)
