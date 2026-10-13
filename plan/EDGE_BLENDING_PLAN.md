# Edge Blending — Implementation Plan

## Context

The user wants to control Edge Blending on Panasonic projectors (reference models: PT-RQ35K and
PT-RZ34K) directly from Projector Grid instead of opening VSS or Geometry Manager Pro.

- Command source: `d:\Flutter\support files\Panasonic - Edge Blending - Sheet1.csv`.
- UI references:
  - **Mockup** (Claude Design canvas): <https://claude.ai/artifact/BaMmVBj2LTZQFdsFijHDW6>,
    artboard *Edge Blending dialog*. An early draft for the general look only, not kept up to
    date: **where it differs from this plan, this plan wins** (decided 2026-10-12).
  - **Geometry Manager Pro** — large canvas with start/width lines drawn over the raster; below
    it, a table Upper/Lower/Left/Right × Enable/Start/Width, plus an "Overlapped Black Level"
    R/G/B block with per-edge "Interlocked" checkboxes; separate "Black Level Adjustment" tab.
  - **VSS** — right-hand panel with *Edge Blending / Black Level* tabs, a mode dropdown, a
    "Projecting markers" checkbox and a cross layout of Upper/Left/Right/Lower checkboxes
    around a rectangle.

Goal: a new **Edge Blending** item in the projector card's context menu (next to Geometry
Correction) that opens a dialog in the style of the existing `GeometryCorrectionDialog`:
interactive canvas on the left + well-structured controls on the right.

**Agreed decisions:** both tabs (Edge Blending + Black Level) in the first iteration;
limits derived from model resolution + read-back after writes; the dialog controls a single
projector.

---

## 1. Command analysis (from the CSV)

Three syntax families — important for parsing:

| Family | Set | Query | Reply | Used for |
|---|---|---|---|---|
| **VXX** | `VXX:KEY=+0000N` | `QVX:KEY` | `KEY=+0000N` | mode, widths, interlocked flags |
| **Legacy short** | `VGU:1`, `VEU:0716` (4 digits, no sign) | `QGU`, `QEU` | bare value `1`, `0716` | edge enable, start, marker, black border width |
| **RGBW tuple** | `VJI:000,000,000,000` / `VXX:EBBS0=000,000,000,000` | `QJI` / `QVX:EBBS0` | `W,R,G,B` (3 digits each, 0–255) | black levels |

### Edge Blending tab

| Parameter | Set | Query | Range |
|---|---|---|---|
| Mode Off / On / User | `VXX:EDBI0=+0000{0,1,2}` | `QVX:EDBI0` | — |
| Enable Upper/Lower/Left/Right | `VGU/VGB/VGL/VGR:{0,1}` | `QGU/QGB/QGL/QGR` | bool |
| Start U/L/L/R | `VEU/VEB/VEL/VER:NNNN` | `QEU/QEB/QEL/QER` | 0…max |
| Width U/L/L/R | `VXX:EUWI0/EBWI0/ELWI0/ERWI0=+NNNNN` | `QVX:…` | 0…max |
| Markers | `VGM:{0,1}` | `QGM` | bool |
| Auto test pattern | `VXX:EATI1=+0000{0,1}` | `QVX:EATI1` | bool |

**Start/Width limits per model** (sheet values; superseded by §8):
- RQ35K: V (Upper/Lower) = 2272, H (Left/Right) = 3712 (`2400−128` / `3840−128`).
- RZ34K: Upper 1023, Lower 1199, Left 1023, Right 1919.
- **Live (§8), RQ25K and RZ34K:** the ceiling is the full raster (no −128) and opposite edges
  share it by width. The sheet's per-edge constants are not the real rule on either model.

### Black Level tab

| Parameter | Set | Query |
|---|---|---|
| Mode: Soft edge + Black level / Black level only | `VXX:EBMI1=+0000{0,1}` | `QVX:EBMI1` |
| Non-overlapped black level W,R,G,B | `VJI:W,R,G,B` | `QJI` |
| ↳ Interlocked | `VXX:EBII1` | `QVX:EBII1` |
| Black border level W,R,G,B | `VJO:W,R,G,B` | `QJO` |
| ↳ Interlocked | `VXX:EBII2` | `QVX:EBII2` |
| Black border width U/L/L/R | `VJU/VJB/VJL/VJR:NNNN` | `QJU/…` (same limits as Start) |
| Overlapped black level U/L/L/R (W,R,G,B) | `VXX:EBBS0..3=W,R,G,B` | `QVX:EBBS0..3` |
| ↳ Interlocked U/L/L/R | `VXX:EBII3..6` | `QVX:EBII3..6` |
| Black border area adjust U/L/L/R on/off *(later)* | `VXX:EBFI1..4` | `QVX:EBFI1..4` |
| ↳ Free-shape adjustment points (2/3/5/9/17) *(later)* | `VXX:EFPI1..4` | `QVX:EFPI1..4` |
| ↳ Execute (no query) *(later)* | `VXX:EFII1..4=+00001` | — |

Black border area adjust is **not in the first iteration** (decided 2026-10-12); the rows stay
here as the command reference for when it's picked up.

**Interlocked semantics:** ON → the W slider moves R/G/B together (single slider); OFF → four
independent channels. In the UI this toggles the same card between "1 slider" and "4 sliders".
The projector doesn't enforce it (§8), so the dialog does:
- Every write while Interlocked is ON sends `W,W,W,W`.
- Turning it ON writes the flag, then the tuple with R/G/B set to the current W.
- Turning it OFF writes only the flag; the four values stay as they are.
- Loaded with the flag ON but unequal channels (set elsewhere): show W, leave the projector
  alone until the user changes something.

**Open (§8 "W channel"):** Geometry Manager Pro shows only R/G/B for all three levels; what W
does on the image is not known yet. The UI above may change to an R/G/B model.

**Not available over the protocol:** free-shape point coordinates and the user blending curve
(*User* mode) — they can only be selected/executed, not edited. In the UI: *User* is just a mode
segment, no tooltip (dropped 2026-10-12).

---

## 2. UX / interface

This section is the spec; the mockup is only an early draft of the look (see Context). Slider
ranges come from the limits in §8. UI text uses commas, colons and parentheses as separators,
never `·` or `—`.

### Entry point
`projector_card.dart` — new `MenuItemButton` **Edge Blending** directly after *Geometry
Correction*, icon `Icons.gradient` (or `Icons.vertical_split_outlined`). An `onEdgeBlending`
callback is wired the same way as `onGeometryCorrection` (`projector_workspace.dart:940`).

### Dialog skeleton (mirrors Geometry + Color Correction)
```
┌ DialogTitleBar: Edge Blending - 192.168.0.107 ───────────────────────┐
│ [ Off | On | User ]  (SegmentedButton, EDBI0)                        │
│ TabBar:  Edge Blending | Black Level                                 │
├───────────────────────────────┬──────────────────────────────────────┤
│  CANVAS (flex 5)              │  CONTROLS (flex 4, scrollable)       │
│  ┌─────────────────────────┐  │  Markers ◉   Auto test pattern ◉     │
│  │▓▒░ ... raster ... ░▒▓   │  │  ┌ Upper ────────── [Switch] ┐       │
│  │  drag: start / width    │  │  │ Start  ──●──── [ 716 ]    │       │
│  └─────────────────────────┘  │  │ Width  ──●──── [ 280 ]    │       │
│  [↺ reset]                    │  └───────────────────────────┘       │
│                               │  (Lower / Left / Right — same)       │
└───────────────────────────────┴──────────────────────────────────────┘
```
- Mode `Off` → the right-hand controls of **both tabs** are dimmed and disabled (like
  `_buildOffBody` in geometry), but the canvas stays visible so the user still sees the
  current zones. A UX choice: the projector itself accepts writes while Off (§8).
- No legend and no status badges on or around the canvas.
- **Esc:** clears the canvas edge selection if there is one; otherwise closes the dialog
  (the default dialog behaviour). Handled by a key handler at the dialog root, so it works
  wherever focus is in the dialog; a field that handles Esc itself still gets it first.
- Size: `minWidth 560, maxWidth 960, maxHeight 0.9 × screen` — same as geometry.

### Edge Blending canvas (the main visual element)
- Raster rectangle in the model's **real aspect ratio** (16:10 for 3840×2400 / 1920×1200),
  scaled via `FittedBox` + `_renderScale` exactly like `_CornerCorrectionCanvas`.
- For each enabled edge: the **blend zone** between the Start line and Start+Width is filled
  with a gradient (`ui.Gradient.linear`), dark at the Start line fading to transparent at
  Start+Width, i.e. dark towards the raster edge. Start line in primary color, zone end line
  in tertiary (equivalent of GMP's red/green lines). The band between the raster edge and
  Start is filled solid dark (decided 2026-10-12).
- Disabled edge — dashed outline of the zone at its stored values (shows what enabling it will
  do), no fill.
- **Dragging:** handles at the midpoints of the lines. Dragging the Start line moves the whole
  zone (width preserved); dragging the outer line changes width. Cursors
  `SystemMouseCursors.resizeLeftRight / resizeUpDown`.
- Clicking a zone/handle selects that edge (highlights its card on the right via a shared
  `selectedEdge`); **arrow keys** ±1 unit, **Shift+arrows** ±10; hold → auto-repeat (the
  hold/repeat logic of `_CornerCorrectionCanvasState`). Arrows change the **last selected
  part** of the selected edge: Start or Width, whichever handle was grabbed last (Start after
  a click on the zone). The arrow pointing inward increases. On the Black Level tab they
  change the selected edge's black border width.
- Double-click a handle → reset that edge's start/width to 0.
- Value labels next to the handles while dragging (`TextPainter` in the painter).
- ↺ "Reset all edges" button in the panel corner (like Corner Correction).

### Edge Blending controls panel
- Toggle row: **Markers** (`VGM`) and **Auto test pattern** (`EATI1`) — labeled `Switch`es.
- 4 **section cards** (`SectionCard`, `common/section_card.dart`): a small side icon (a
  rectangle with the edge's side thick, primary when enabled), edge title and enable `Switch`;
  inside, two rows *Start* / *Width* = `LabeledSliderRow` (`common/labeled_slider_row.dart`),
  passing null callbacks while the edge is disabled (it keeps the stepper's State). The
  selected edge's card gets a primary border.
- VSS-style Upper/Left/Right/Lower "cross" — **not needed**: the canvas itself does that job
  (clicking an edge selects/enables it). Less duplication.

### Black Level tab
Left: same canvas in "black level" mode — shows the non-overlapped area (light), overlapped
zones (RGB swatches of current values), black border bands (hatched, width from `VJU/VJB/…`).
Black border widths are draggable via handles.

Right, top to bottom:
1. **Mode**: `SegmentedButton` *Soft edge + Black level* / *Black level only* (`EBMI1`).
2. **Non-overlapped black level** card: `Interlocked` checkbox; ON → single W slider (0–255);
   OFF → W/R/G/B sliders (`LabeledSliderRow`, `SliderLabelLayout.inline`, coloured labels).
3. **Overlapped black level**: compact GMP-style table, row = edge, columns Interlocked
   checkbox, W, R, G, B (steppers only, no sliders, to keep height down). Interlocked ON →
   only W is editable, R/G/B show W dimmed. Rows of disabled edges are dimmed.
4. **Black border** card: level (W,R,G,B + Interlocked, as in 2) + 4 widths (max from §8).

Interlocked behaviour for all three: §1. Black border area adjust is deferred (§1).

This tab loads **lazily** on first open (as in Color Correction): ~20 queries aren't spent
if the user never opens it.

---

## 3. Architecture / files

Follow the existing dialog pattern: **stateful dialog + direct `PanasonicProtocolService`
calls**, no new Riverpod provider (edge blending is a live projector setting, not part of the
project file / undo stack — same as Geometry/Color/Brightness).

New files (one responsibility per file per CLAUDE.md; the geometry dialog is already ~2100
lines — don't repeat that):

| File | Contents |
|---|---|
| `lib/features/workspace/presentation/widgets/edge_blending/edge_blending_dialog.dart` | `EdgeBlendingDialog` — loading, sending, skeleton, TabBar |
| `…/edge_blending/edge_blend_state.dart` | plain-Dart holder `EdgeBlendState` (4× `EdgeSettings{enabled,start,width}`, marker, autoPattern, mode), keyed by `BlendEdge` |
| `…/edge_blending/black_level_state.dart` | `BlackLevelState` (mode, `RgbwLevel{value: (w,r,g,b), interlocked}` per `LevelSlot`: non-overlapped, border and 4× overlapped; border widths per `BlendEdge`) |
| `lib/features/workspace/domain/blend_edge.dart` | enum `BlendEdge {upper,lower,left,right}` carrying command keys (`enableCmd:'GU'`, `startCmd:'EU'`, `widthKey:'EUWI0'`, …) — the whole command table in one place — plus `isHorizontal` and `opposite`. In `domain/` because the limits need it |
| `…/edge_blending/edge_blend_canvas.dart` | `EdgeBlendCanvas` (StatefulWidget: drag, focus, keys) + `_EdgeBlendPainter` |
| `…/edge_blending/edge_blend_panel.dart` | right-hand panel of the Edge Blending tab |
| `…/edge_blending/black_level_panel.dart` | right-hand panel of the Black Level tab, `RgbwLevelCard` |
| `lib/features/workspace/domain/edge_blend_limits.dart` | pure functions, unit-tested: `edgeBlendRasterFor(String model)` → `(h, v)` built on the existing `quadPixelTierFor` (`geometry_values.dart`) — Tier A 3840×2400, Tier B 5120×3200 (unverified), none 1920×1200 (also when `QID` fails) — so model detection stays in one place; plus the shared-raster max rules from §8 (Start/Width/Border max per edge from the current state). Read-back after ER402 covers anything not modeled |
| `lib/features/workspace/domain/edge_blend_values.dart` | pure, unit-tested wire helpers: `formatNt4(int)` (`10` → `0010`), `parseRgbw(String?)` / `formatRgbw(...)` (`WWW,RRR,GGG,BBB`, also after a `KEY=` prefix) |

Modified files:
- `projector_card.dart` — menu item + `onEdgeBlending` (menu at `:269`, next to
  `onGeometryCorrection`).
- `projector_workspace.dart` — `showDialog(EdgeBlendingDialog(node: node))` (`:1038`).
- `panasonic_protocol_service.dart` — **bug fix first:** `_isFailureResponse` uses
  `startsWith('ER')`, so the valid reply `ERWI0=+00384` (Right width) becomes a failure /
  null. Match the whole reply, `^ER(R[0-9A-Z]|\d+)$` (keeps `ERR1..5` / `ERRA` failures),
  with a unit test.
- `common/projector_settings_client.dart` — add `queryWithCode(cmd)` /
  `writeRawWithCode(cmd)` on `sendRawCommandPreservingErrorCodes` (already routed through
  `IsolateProtocolService`), returning the reply or the `ERxxx` code, null only on transport
  failure. The dialog needs it to tell ER402 (out of range → read back and sync, no failure
  notice) from a timeout (→ `notifyCommandFailure`).
- `.claude/skills/panasonic-ntcontrol/references/command_reference.md` — add the edge
  blending commands and reply formats (legacy short / RGBW tuple), and the `ER` prefix trap.

### Reuse
- `DialogTitleBar`, `DialogSplitLayout` (canvas flex 5 + scrollable controls flex 4),
  `SectionCard`, `LabeledSliderRow`, `SleekStepperInput`, `CustomTooltip`,
  `notifyCommandFailure` (`command_failure_notice.dart`).
- `ProjectorSettingsClient` (`common/projector_settings_client.dart`): `queryAll` (batches of
  8), `readInt`, `writeInt`, `writeBool`. `parseKeyedValue` / `parseKeyedInt` /
  `formatNtInt` (`geometry_values.dart`) already handle legacy replies (`QEU` → `10`: no `=`
  → whole reply).
- Arrow-key hold/repeat and pointer→canvas scaling from `_CornerCorrectionCanvasState`
  (private in `geometry_correction_dialog.dart`): move the hold/repeat into a small shared
  helper both canvases use instead of copying it.

### Data flow
1. `initState` → `queryAll([QVX:EDBI0, QID, QGU…QGR, QEU…QER, QVX:E?WI0×4, QGM, QVX:EATI1])`
   (16 commands, 2 batches).
2. On change: optimistic local `setState` → command sent on `onChangeEnd` / handle release /
   key-up (like Corner — never on every drag frame).
3. **Writes are serialized** through one queue per dialog: reset-all sends 8 commands, and
   concurrent Start/Width writes for one edge could hit ER402 in the wrong order. Order for
   a reset: widths and starts both go to 0, always valid.
4. **ER402** (out of range): read the value back (one `Q…` query) and sync the UI to it. The
   UI already clamps to §8, so this only covers what §8 doesn't model.
5. Transport failure → `notifyCommandFailure`.

### Groundwork for pair mode (§9), built in the first iteration
The first iteration ships single-projector only, but is shaped so §9 adds a second projector
without a rewrite:
- `EdgeBlendingDialog` takes `List<ProjectorNode> nodes` (length 1 for now; asserted ≤ 2),
  not a single `node`.
- Per-projector data lives in one `EdgeBlendSide` (node, `ProjectorSettingsClient`, raster,
  `EdgeBlendState`, `BlackLevelState`, load state, its own write queue); the dialog holds a
  list of them and an `active` index. Panels render `sides[active]`.
- The canvas paints a list of sides through a layout (`EdgeBlendLayout`: one raster, or two
  arranged per §9); the single case is a layout with one entry.
- Edge selection is `(sideIndex, BlendEdge)`, not just `BlendEdge`.

---

## 4. Flutter — choice of tools (research)

Project is on Flutter 3.47 / Dart 3.13. Everything needed is in the SDK — **no new
dependencies**:

| Task | Solution | Why |
|---|---|---|
| Zone canvas | `CustomPainter` + `RepaintBoundary`; gradient via `Paint()..shader = ui.Gradient.linear(...)` | single paint pass, not a widget tree; RepaintBoundary isolates drag repaints from the right panel |
| Drag handles | `GestureDetector(onPanStart/Update/End)` inside the logical coordinate space + `FittedBox` | already proven in the Corner canvas; correct conversion via `_renderScale` |
| Cursors | `MouseRegion(cursor: SystemMouseCursors.resizeLeftRight/UpDown)` | native desktop affordance that the line can be moved |
| Hover highlight | `MouseRegion.onHover` + zone hit-test in state | highlight the edge under the pointer (desktop expectation) |
| Keyboard | `Focus(onKeyEvent)` + `HardwareKeyboard.instance.isShiftPressed` for ×10 step | same as Corner; doesn't clash with global `Shortcuts` (dialog is its own route) |
| Frequent repaints during drag | local `setState` only inside the canvas State (like Corner); the right panel's steppers listen to a `ValueNotifier<EdgeBlendState>` via `ValueListenableBuilder`, parent `setState` only on pointer-up | avoids rebuilding the whole panel on every pointer-move |
| Modes / toggles | `SegmentedButton`, `Switch`, `Checkbox` (M3) | consistent with the rest of the app |
| Tabs | `DefaultTabController` + `TabBar/TabBarView` | same as Color Correction |
| Section cards | `SectionCard` (`common/section_card.dart`) | visual consistency |
| Accessibility | `Semantics(label: 'Upper blend start', value: '716', onIncrease/onDecrease)` on handles | CustomPaint handles are otherwise invisible to screen readers |
| Animation | `AnimatedOpacity`/`AnimatedSwitcher` (150 ms) for Off↔On and edge enable | soft transitions without distraction |

Rejected: third-party canvas packages — overkill; `InteractiveViewer` zoom — the raster
already fits the panel, zoom isn't needed.

---

## 5. Implementation stages

1. `[x]` **Protocol** (2026-10-12): `_isFailureResponse` matches the whole reply
   (`^ER(R[0-9A-Z]|\d+)$`, so `ERR1..5`/`ERRA` stay failures) + tests in
   `protocol_service_test.dart`; `queryWithCode` / `writeRawWithCode` in
   `ProjectorSettingsClient`; `blend_edge.dart`, `edge_blend_limits.dart`,
   `edge_blend_values.dart` with `test/unit/edge_blend_test.dart`; `command_reference.md`
   Edge Blending section.
2. `[x]` **State/model** (2026-10-12): `edge_blend_state.dart` (`EdgeBlendMode`,
   `EdgeSettings`, `EdgeBlendState` with `maxFor`, the load query list and its parser);
   `edge_blend_side.dart` (`EdgeBlendSide`, a `ChangeNotifier` per projector: load, writes
   through `SerialQueue` (`common/serial_queue.dart`), ER-code read-back, a commit equal to
   the projector's value sends nothing). `BlackLevelState` arrives with stage 6. Tests:
   `test/unit/edge_blend_side_test.dart`.
3. `[x]` **Dialog skeleton** (2026-10-12): `EdgeBlendingDialog(nodes: [...])`, mode
   SegmentedButton, TabBar, loading, "No reply" + Retry, Esc (clears the selection, else
   closes), Off dims the controls; menu item *Edge Blending* (`Icons.gradient`) after
   Geometry Correction. `PanasonicProtocolService.isErrorCode` made public for the side.
4. `[x]` **Edge Blending panel** (2026-10-12): `edge_blend_panel.dart`, Markers / Auto
   test pattern switches, four `SectionCard`s (side icon, enable switch, Start / Width via
   `LabeledSliderRow` inline with `inlineLabelWidth`), selected card highlighted
   (`SectionCard.highlighted`). Touching a slider selects that edge and part. Canvas and
   Black Level tab are still empty placeholders.
5. `[x]` **Edge Blending canvas** (2026-10-12): `edge_blend_canvas.dart`. Built differently
   from the Corner canvas: one `CustomPaint` + one `GestureDetector` with its own
   hit-testing (`_RasterBox` maps units ↔ pixels from the layout size), no `FittedBox` /
   `_renderScale`. Deviations from §2 / §4:
   - Both handles sit at their line's midpoint; when they overlap (small Width) the Width
     handle is on top and wins, so the first drag pulls Width out and Start is reachable
     after (2026-10-12, after a first look: handles spread to 40 % / 60 % read as noise).
   - The band from the raster edge to Start is solid dark, the gradient runs Start →
     Start + Width (the gap read as grey on the first look). A click anywhere in that
     whole band selects the edge.
   - Clicking a disabled edge's zone only selects it (no enabling from the canvas).
   - Mode Off: zones drawn, no handles, no drag / keys; Reset all disabled.
   - Previews rebuild the whole dialog through `EdgeBlendSide` notifications (no separate
     `ValueNotifier` for the panel): the tree is small and the steppers follow the drag.
   - Semantics: one label for the canvas; the panel's sliders are the accessible controls.
   - Dragging a slider logs `Failed to update ui::AXTree` on Windows: every `Slider` keeps
     an always-shown `OverlayPortal` for its value indicator (Flutter `slider.dart`), the
     upstream engine bug already tracked in `IMPROVEMENT_PLAN.md` for Geometry / Brightness.
     Console-only, not fixable from app code.
   Arrow hold/repeat moved to `common/key_hold_repeater.dart` (`KeyHoldRepeater`), the
   Corner canvas uses it too. `TabBarView` has `NeverScrollableScrollPhysics` so a handle
   drag never swipes tabs. Tests: `test/widgets/edge_blend_canvas_test.dart`.
6. `[x]` **Black Level tab** (2026-10-13): `black_level_state.dart` (`BlackLevelMode`,
   `LevelSlot` = non-overlapped / border / 4 overlapped with their commands, `RgbwLevel`,
   `BlackLevelState`, the 17 queries and their parser), `black_level_panel.dart`
   (`BlackLevelPanel`, `RgbwLevelCard`, the overlapped table). `EdgeBlendSide` loads it on
   the tab's first tap (`loadBlack`, own "No reply" + Retry) and writes through the same
   queue; Interlocked per §1. Deviations from §2 / §3:
   - `BlackLevelState` got its own file instead of sharing `edge_blend_state.dart`.
   - The border width is `EdgePart.border`, so `preview` / `commit` / `maxFor` and the
     canvas handle it like Start / Width. The canvas gets `black:` to switch to Black
     Level mode: overlapped zones filled in their level's colour, border bands in the
     border level's colour, hatched, one handle per edge (also on disabled edges: the
     projector accepts border widths there). Reset all resets the border widths on that
     tab. The non-overlapped area is the plain raster, no swatch (no legend, §2).
   - The selection keeps its last blend part when the Black Level tab picks an edge.
   - Overlapped table: the Interlocked column header is a link icon with a tooltip; the
     table scales down (`FittedBox`) rather than overflowing in a narrow dialog. Rows of
     disabled edges are dimmed but stay editable (the projector keeps those levels).
   - `EBMI1` value order (0 = Soft edge + Black level, 1 = Black level only) follows §1,
     not confirmed live — `tool/edge_blend_test.dart` Phase 2g asks (§8 "W channel").
   Tests: `edge_blend_side_test.dart` (parser, `RgbwLevel`, writes, Interlocked ON / OFF,
   border width), `edge_blend_canvas_test.dart` (border drag + ceiling, arrows).
7. `[x]` `dart format .`, `flutter analyze`, review with the `reviewer` agent
   (2026-10-13). Fixed from the review:
   - An ER read-back no longer overwrites a later queued write to the same field
     (per-field pending count in `EdgeBlendSide`); a write with no reply (or a failed
     read-back) restores the expected value, so committing the same value again resends.
   - A held arrow key stops when the selection changes, the mode goes Off or the canvas
     loses focus; its key-up is matched before the selection checks.
   - `LabeledSliderRow.limit`: the stepper's max follows the §8 limit, so its text can't
     run past it (closes the known stepper issue).
   - Hover outline cleared when the mode goes Off.
   Left as is: Interlocked ON queues the tuple even if the flag write fails (harmless),
   and `loadBlack` may briefly overlap one queued write (9 in flight, within tolerance).

**Unit tests** (pure functions only, per CLAUDE.md): `edgeBlendRasterFor` per tier and for an
empty model; the §8 max rules (each edge, opposite-edge sharing, border vs own width);
`formatNt4`, `parseRgbw` (bare tuple, `EBBS0=` prefix, garbage → null), `formatRgbw`;
`_isFailureResponse` no longer failing `ERWI0=+00384` but still failing `ER401` / `ER402`.

Later (not in this iteration): Black border area adjust (EBFI / EFPI / EFII; treat ER401 on
`EBFI` as "unavailable", see §8), apply to group/selection, OSC addresses `/pgrid/blend/...`,
saving blend presets in the project file, an Edge Blending entry in the Alignment banner
(`alignment_banner.dart`, next to Geometry).

---

## 6. Critical files
- `lib/features/workspace/presentation/widgets/geometry_correction_dialog.dart` — reference pattern (loading, canvas, keys)
- `lib/features/workspace/presentation/widgets/color_correction_dialog.dart` — TabBar, lazy loading
- `lib/features/workspace/presentation/widgets/common/` — `ProjectorSettingsClient`, `SectionCard`, `LabeledSliderRow`, `DialogSplitLayout`
- `lib/features/workspace/presentation/widgets/projector_card.dart:269` — context menu
- `lib/features/workspace/presentation/widgets/projector_workspace.dart:1038` — dialog opening
- `lib/core/services/panasonic_protocol_service.dart:246` — `_isFailureResponse` (the `ER` prefix bug), `sendRawCommandPreservingErrorCodes`

---

## 7. Verification

1. **Live protocol probe** `tool/edge_blend_test.dart` (like the other `tool/*_test.dart`
   scripts, IP at the top), run against RQ35K and RZ34K (done on RQ25K + RZ34K, §8):
   - read every query from §1 and confirm reply formats (especially `QJI` — the CSV shows a
     reply of `0`, not a tuple);
   - write start = max and max+1 → confirm limits (verify/fix the odd RZ34K values);
   - check start+width > max — error or clamping;
   - check that commands answer while mode is Off (not ER401, as happened with QPDI1).
   Record results in `plan/EDGE_BLENDING_PLAN.md` under a "Live test" section.
2. `flutter analyze` clean, `dart format .`, `flutter test`.
3. `flutter run -d windows` + the `flutter-windows-gui-check` skill: card menu → Edge
   Blending, screenshots of both tabs in dark/light theme, handle drag, arrows/Shift,
   Off/On/User.
4. On a real projector with markers ON — visually confirm that line positions on the canvas
   match the markers on screen.

---

## 8. Live test

### PT-RQ25KE (192.168.0.8, 2026-10-12)

`tool/edge_blend_test.dart`, Phase 1 + Phase 2. Initial state: mode Off, all edges disabled,
widths 240/240/384/384, black levels 0. All registers restored afterwards (read-back verified).

**Reply formats**
- Every query from §1 answers in the documented family. `QJI` / `QJO` reply a full
  `WWW,RRR,GGG,BBB` tuple (the sheet's bare `0` is wrong); `QVX:EBBSn` → `EBBSn=WWW,RRR,GGG,BBB`.
- Legacy replies are bare and unpadded: `QEU` → `0`, `10`, `2400` (not `0716`-style); writes
  still take 4 digits (`VEU:0010`).
- The Right width reply `ERWI0=+00384` starts with `ER` — error detection must match `ER\d+`
  exactly, not the `ER` prefix (this broke the first probe run).

**Start / Width limits**
- Per edge, with every other zone at 0: Start ≤ 2400 (Upper/Lower) / 3840 (Left/Right),
  Width ≤ the same. That is the full Quad-Pixel-Drive raster, **no −128 margin** on this model.
- Start + Width of one edge ≤ raster (`start=1200` with `width=2400` → ER402).
- **Opposite edges share the raster by width:** Upper width 1000 → Lower width ≤ 1400;
  Left width 1000 → Right width ≤ 2840. The opposite edge's start does not count (Upper
  start=200 + width=1000 still left Lower ≤ 1400).
- Black border width ≤ raster − own blend width (width 200 → border ≤ 2200 / 3640). Accepted with
  the edge disabled too.
- Out-of-range writes are **rejected with ER402, value unchanged** — no silent clamping.

**Black levels / Interlocked**
- RGBW tuples round-trip verbatim on `VJI`, `VJO`, `VXX:EBBSn`.
- Interlocked (`EBII1..6`) is **not enforced over the protocol**: with it ON, `050,010,020,030`
  is stored as-is, and turning it OFF changes nothing. The dialog has to keep W/R/G/B consistent
  itself when Interlocked is on.

**Mode Off**
- All queries and writes work while `EDBI0 = 0` (`VEU:0010` accepted and read back). No
  ER401 trap like `QPDI1`.

**Border area adjust (`EBFI1..4`)**
- `QVX:EBFI1..3` answered ER401 in the initial state (`EBFI4` answered `0`), regardless of mode.
  After enabling the edge with blend width 200 and a non-zero border width, all four answered
  `0`. `VXX:EBFI4=+00000` from the initial state → ER401. Exact precondition not isolated; the
  dialog should treat ER401 here as "unavailable" and disable the row instead of failing.

### PT-RZ34KE (192.168.0.8, 2026-10-12) — no Quad Pixel Drive

Same probe, Phase 1 + Phase 2. Initial state: mode Off, all edges disabled, widths
120/120/192/192 (half of the RQ25K defaults), black levels 0. All registers restored afterwards
(read-back verified).

- **Every rule from the RQ25K holds, on a 1920×1200 raster:** Start ≤ 1200 / 1920, Width ≤
  1200 / 1920, Start + Width of one edge ≤ raster, out-of-range → ER402 with value unchanged.
- The sheet's asymmetric 1023 / 1199 / 1023 / 1919 is wrong — all four edges reach the full
  raster, no −128.
- Shared raster: Upper width 1000 → Lower width ≤ 200; Left width 1000 → Right width ≤ 920.
  Opposite edge's start not counted.
- Black border width ≤ raster − own blend width (width 200 → 1000 / 1720).
- Reply formats, RGBW round-trip, Interlocked not enforced, writes while Off, `EBFI1..3` ER401
  in the initial state: identical to the RQ25K.

### Limits rule (both models)

With `H`, `V` = raster width/height, for edge `e` and its opposite `ē` (Upper↔Lower,
Left↔Right; `R` = `V` for Upper/Lower, `H` for Left/Right):

| Value | Max |
|---|---|
| Start(e) | `R − Width(e)` |
| Width(e) | `min(R − Start(e), R − Width(ē))` |
| Black border width(e) | `R − Width(e)` |

All values ≥ 0. Not probed: whether Black border width also counts against the opposite edge,
or Start(e) against Width(ē) when both are non-zero — the read-back after ER402 covers it.

With a non-zero Start the projector's rule lets the two zone-end lines **cross** (Upper
start 200 + width 1000 ends 1200 from the top, Lower width 1400 ends 1000 from the top),
while Geometry Manager Pro stops a width line at the opposite one — so that GMP rule looks
like its own software limit. **Pending:** `tool/edge_blend_test.dart` Phase 2f (added
2026-10-12, not run yet) measures own Start vs the opposite zone, crossing lines with both
Starts non-zero, and the cap with either edge enabled. Decide after it whether the app keeps
the projector's rule or adopts GMP's.

### W channel (pending, 2026-10-13)

The protocol carries every black level as `W,R,G,B` and stores W independently (§8 Black
levels), so the Black Level tab shows W as a fourth channel and Interlocked ON as a single W
slider that writes `W,W,W,W`. Geometry Manager Pro shows only **R, G, B** for Non-overlapped,
Black border and the four Overlapped levels; with Interlocked ticked all three fields stay
editable and move together. Two readings:

1. **W is only the OSD's "all channels" slider**, the image uses R/G/B. Then switch the tab
   to GMP's model: R/G/B only; Interlocked → any of the three moves all, written as
   `R,R,R,R` (W kept equal so the OSD agrees); free → R/G/B independent, W left as loaded.
2. **W is an offset on top of R/G/B.** Then keep W, relabel it (e.g. "All") with a tooltip.

**Pending:** `tool/edge_blend_test.dart` Phase 2g (`probeWChannel`, interactive — needs a
black input and someone at the screen) writes W-only, R-only, W+R and R=G=B levels and asks
what the image and the OSD show; optionally has you set levels in GMP and reads back what GMP
wrote to W (free R=10/20/30, then Interlocked R=40); and asks which `EBMI1` value is which
Black Level Mode. Decide the UI model after it.

### Cross-check with Geometry Correction

`geometry_values.dart` already classifies models by `quadPixelTierFor`, and the live results
line up with it:

| Tier (geometry) | Model tested | Corner inward H/V | Edge blend raster |
|---|---|---|---|
| A (QPD 3840×2400) | RQ25K | 960 / 600 | 3840 × 2400 |
| none (WUXGA) | RZ34K | 480 / 300 | 1920 × 1200 |
| B (5120×3200) | — not tested | 480 / 300 (unconfirmed) | 5120 × 3200 expected, unconfirmed |

- Corner inward = raster / 4 on both tested tiers, so both features address the same canvas;
  Corner outward (384 / 240) stays fixed on both, as `geometry_values.dart` already notes.
- The RQ25K default widths (240 / 384) are exactly double the RZ34K ones (120 / 192) — the same
  ×2 that QPD applies to Corner inward.
- **Quad Pixel Drive state doesn't change the limits** (RQ25K, live, Phase 2e): the raster is a
  property of the model tier, not of the `QPDI1` toggle — see below.

### PT-RQ25KE, Quad Pixel Drive on vs off (2026-10-12)

Initial state: geometry mode `GMMI0=+00003` (a mode the geometry dialog doesn't model —
Keystone=1, Curved=2, Corner=10), so `QVX:QPDI1` → ER401. The probe set `GMMI0` to 0, read
`QPDI1 = 1`, measured, toggled, measured, then restored `QPDI1 = 1` first and `GMMI0 = 3` after
(Tier A won't enter a geometry mode with QPD off). 20 Corner/Keystone registers compared before
vs after: unchanged.

| QPD | Upper start / width max | Left start / width max |
|---|---|---|
| ON (1) | 2400 / 2400 | 3840 / 3840 |
| OFF (0) | 2400 / 2400 | 3840 / 3840 |

- Toggling QPD does **not rescale stored values**: Upper width 500 and Left width 800 read back
  unchanged after ON → OFF.
- So the earlier RQ25K run (QPD ON, since geometry was active) holds for both states. The
  dialog derives the raster from `quadPixelTierFor` only and never reads `QPDI1` — which is
  also unreadable while any geometry mode is active.

### Implications for §3
- `edge_blend_limits.dart` derives the raster from `quadPixelTierFor` (no second model table);
  limit = full raster, not −128.
- The panel recomputes every value's limit from the table above on each change; ER402 →
  read-back and sync. The **slider range stays the full raster span**, the limit is a stop
  the value can't pass (2026-10-12): a range that followed the limit slid Width's thumb
  whenever Start moved, with Width's value unchanged.

---

## 9. `[x]` Pair mode: two projectors in one dialog

**Mockup:** artboard *Edge Blending · Pair mode* on the canvas linked in Context (Edge
Blending side by side, Edge Blending stacked, Black Level), drawn 2026-10-13. It is a
**reference for layout and look only**, not a spec to copy pixel for pixel: values, sizes and
the hand-drawn icons are illustrative. Where it differs from this section, this section wins.

### Why
Blending is always set up between neighbours: Left projector's Right edge and Right
projector's Left edge must get the same width, and the operator wants both projectors' markers
and zones in view while adjusting. Two dialogs side by side don't fit and drift apart. The
limit is **two projectors**: that is one overlap, which is what the dialog has room for. A
wall of 3+ projectors is set up pair by pair.

### Opening
- Same rule as Remote Preview (`onRemotePreview` in `projector_workspace.dart`): the clicked
  card is part of a selection → the selection, else just the clicked card.
- Selection of exactly 2 → pair mode. Selection of 3+ → the menu item stays enabled but
  opens single mode for the clicked card, with no note (dropped 2026-10-13). Disabling
  the item would leave no way to open it from a big selection.
- Menu label in a 2-selection: **Edge Blending (2 projectors)**.
- Title: `Edge Blending - PRJ-01, PRJ-02`.

### Arrangement
The two projectors meet along one edge pair, the **facing edges**:
- Side by side: A.Right ↔ B.Left. Stacked: A.Lower ↔ B.Upper.
- Initial guess from the cards on the workspace (`ProjectorNode.x/y`): the axis with the
  bigger centre distance wins; A is the left / upper card.
- A small control above the canvas fixes a wrong guess: `SegmentedButton` *Side by side /
  Stacked* + a *Swap* icon button. Not saved anywhere (presets are a later item).

### Canvas
- Both rasters drawn in one canvas, each in its real aspect ratio.
- **What the overlap is (2026-10-13).** Start and Width only shape each projector's own
  image, in its own pixels from its own edge: full brightness, then the ramp (Width)
  falling to black, then black up to the edge (Start). Neither moves the image; the real
  overlap comes from mounting / zoom / lens shift / geometry and is always set on the
  screen with the markers, never known in pixels. A correct blend needs equal facing
  widths and Start(A) + Width + Start(B) = the real overlap, so a change of Start(A)
  alone would un-align the ramps on the screen.
- The canvas therefore shows **what the settings describe**, not the screen: the rasters
  overlap by **Start(A) + Start(B) + max(Width(A), Width(B))** of the facing edges (a
  disabled facing edge adds nothing), `pairOverlap`. Different widths stay visible as
  ramps that don't match; whether the values match the screen is the markers' job, the
  canvas doesn't flag alignment errors. No separate Overlap parameter (considered and
  dropped 2026-10-13: an unmeasured number would only give false warnings).
- **Fixed scale, centred:** the scale fits two rasters with no overlap (2 × raster along
  the arrangement axis). A change of the overlap moves **both** rasters by half of it,
  towards or away from each other (`pairPositions`); nothing rescales mid-drag. The
  narrower facing Width moves nothing. Two 16:10 rasters side by side come out ~half the
  single-mode width; stacked uses the height and comes out larger.
- The **active** projector's raster and handles are drawn normally, the other one's at
  reduced opacity (drawn over the active raster, its handles under the active ones).
- **Projector pills** with the name sit **outside** the rasters, so they never cover lines
  or handles: above each raster side by side, left of each raster stacked. They are the
  active-projector switch: the active pill is filled (primary outline), the other one
  outlined; tooltip `PRJ-02, 192.168.0.108`. Clicking a zone or handle of the other
  projector also makes it active. Dragging works on either projector's handles.
- Start never mirrors through Link.
- Non-facing edges (e.g. A.Left) behave exactly as in single mode.

### Right panel
- **No projector switch in the panel** (the pills on the canvas pick the active one; a
  `SegmentedButton` here looked like a second copy of the Black Level mode control). The
  panel starts with a header row, the same on both tabs: active projector's name, its IP,
  and a muted hint *Switch on the canvas* on the right; a divider under it. The cards below
  show the active projector's values. Keeps the panel as narrow as today: no second column.
- **Shared** controls write to both projectors: mode (Off / On / User) stays at the top of
  the dialog; Markers and Test pattern sit under the header on the Edge Blending tab (still
  shared, though they sit under one projector's name; accepted 2026-10-13). Mixed state
  (one On, one Off) shows no segment selected / the switch off; picking a value writes it
  to both.
- Segmented buttons in the dialog show no check mark on the selected segment
  (`showSelectedIcon: false`), as elsewhere in the app.
- The facing edge's card shows a **Link** toggle (`link` / `link_off` icon), on by default:
  - Linked: enable, Width and the overlapped black level of the facing edge are mirrored
    to the other projector's facing edge (A.Right width 480 → B.Left width 480). Start
    stays per projector (it compensates each projector's own position) and is never
    mirrored.
  - The max of a linked value is the smaller of the two projectors' §8 maxima.
  - Turning Link on with different values copies the active projector's values to the
    other one.
  - Only possible when both rasters are equal (`edgeBlendRasterFor`). Mixed tiers (e.g.
    RQ35K + RZ34K) disable it with a tooltip: widths are in each projector's own raster
    units, and a fixed ratio would be a guess.
- No "Widths differ" warning line (dropped 2026-10-13): it shifted the cards as it came
  and went, and different widths already show as two ramps of different width.

### Black Level tab
- Same pair canvas as the Edge Blending tab (both rasters, inactive one dimmed, same
  pills), so nothing jumps when switching tabs and the shared zone stays visible.
- Same header row as the Edge Blending tab, then the Black Level mode `SegmentedButton`
  (per projector), then the level cards.
- Per projector through the active-projector pills: non-overlapped and border levels and
  border widths stay individual (each projector's black floor is matched by eye).
- The facing edge's overlapped level follows the Link toggle on the Edge Blending tab; its
  row in the Overlapped table shows a `link` icon (tooltip `Linked with PRJ-02 Left`)
  while linked, nothing when not.
- The Overlapped table's Interlocked column header changes from the `link` icon to
  `Icons.join_inner` (tooltip *Interlocked*), so it can't be confused with Link. This also
  applies to single mode (`black_level_panel.dart`).
- With every card expanded the panel is taller than a 1080p dialog allows; it scrolls.
- Loads lazily per projector, the first time that projector is active on this tab.

### Data flow
- Both projectors load in parallel at open (each its own `queryAll`; the 8-wide batch
  limit is per projector, so two projectors don't contend).
- Each projector keeps its own serialized write queue. A linked change enqueues the write
  on both; the canvas shows it at once on both (optimistic).
- ER402 on one side of a linked pair → read back that side; if the two now differ, Link
  stays on and the canvas shows the two widths.
- One projector offline: its side shows the error state, the other stays usable; shared
  and linked writes go only to the reachable one, with `notifyCommandFailure` for the
  other.

### Esc and keyboard
Same as single mode (§2); arrows act on the selected `(side, edge)` part. A linked width
moved by arrows mirrors on key-up together with the write.

### Stages
1. `[x]` **Pair domain** (2026-10-13): `domain/edge_blend_pair.dart` — `PairArrangement`
   (facing edges), `edgeBlendTargets` (the opening rule), `guessPairArrangement`,
   `canLinkRasters`, `linkedMax`, `pairOverlap` / `pairPositions` / `pairExtent` (canvas
   layout in raster lengths, each value as a fraction of its own span so mixed rasters
   line up). Tests:
   `test/unit/edge_blend_pair_test.dart`.
2. `[x]` **Opening + dialog plumbing** (2026-10-13): menu label in a 2-selection, pair
   title; sides ordered A/B by the guess; parallel load, each side's own
   loading / "No reply" with the pair controls still usable; shared mode / Markers / Auto
   test pattern (mixed → nothing selected / off, a pick writes every reachable side);
   panel header row; *Side by side / Stacked* + *Swap* above the canvas; Black Level
   lazy per projector.
3. `[x]` **Pair canvas** (2026-10-13): `EdgeBlendCanvas` takes a list of
   `BlendCanvasSide`s + `active` + `arrangement` + `blackTab`; callbacks carry the side
   index, `EdgeSelection` moved into the canvas file. Both rasters on the fixed-scale,
   centred layout (`pairOverlap`, `pairPositions`), the inactive one in a 45 % layer over the active
   one, its handles under the active ones; hit-testing tries the active projector first.
   Pills are widgets in a `Stack` over the canvas: side by side above A's left / B's
   right corner, stacked left of A's top / B's bottom. Picking the other projector's
   zone or handle makes it active. Deviations:
   - A drag measures against the raster box at drag start: a facing Start or the wider
     facing Width moves both rasters, and the moving box would feed back into the
     value. The value follows the pointer; the handle moves half as far.
   - A projector that hasn't loaded (or answered "No reply") is a labelled placeholder
     raster at the touching position, its load state / Retry in the panel, so the
     pills stay usable. On Black Level a projector whose tab values haven't loaded
     shows dashed zones, no handles.
   Tests: pair group in `edge_blend_canvas_test.dart` (active wins a shared handle, the
   other projector's handle, B's facing Start drag, the wider Width moves both rasters,
   the narrower doesn't, pill).
4. `[x]` **Link** (2026-10-13): `edge_blend_link.dart` (`EdgeBlendLink`, built per use
   from the sides, arrangement and toggle) routes every edit of the dialog, canvas and
   both panels, so the facing edge's enable, Width (preview, commit, arrow keys, reset)
   and overlapped level (tuple + Interlocked) mirror; Start and the border never do.
   Linked max = `linkedMax` of both §8 limits (panel slider + canvas clamp via a
   `maxFor` parameter). Link toggle (`link` / `link_off` `IconButton`) on the facing
   card, disabled with a tooltip on mixed rasters or while a projector isn't loaded;
   turning it on copies the active projector's facing edge (`copyFrom`), a Width over
   the other's own limit stops at it. Black Level: linked row shows a `link` icon,
   the Interlocked header is `Icons.join_inner` (single mode too); the link icon has
   its own 20 px column, empty when not linked, so the columns never shift.
   Deviations:
   - No "Widths differ" line (built, then dropped after the GUI check).
   - While linked, the Black Level tab also loads the other projector, so the level
     can mirror into it; a level whose partner hasn't loaded yet isn't mirrored.
   - Interlocked mirrors with the overlapped level (`copyLevel`): the two rows stay
     the same level, not just the same numbers.
   Tests: `test/unit/edge_blend_link_test.dart`, `test/widgets/black_level_panel_test.dart`,
   `test/widgets/edge_blending_dialog_test.dart` (Link on by default, the linked row's
   icon for either active projector).
5. `[x]` **Wrap-up** (2026-10-13): `dart format`, `flutter analyze` clean, Edge Blending
   tests green; GUI check on 2 simulated projectors done by the user. The simulator's
   WUXGA model for the mixed-tier case is skipped (not needed). Fixed from the review:
   - Link turned on before both projectors' Black Level values had loaded (e.g. on the
     Edge Blending tab) never copied the overlapped level. `copyFrom` now does enable +
     Width only; `copyLevelFrom` does the level, and when it can't yet, the dialog keeps
     `_levelCopyFrom` and runs it as soon as both have loaded (follows a Swap).
   Tests: link test for the deferred copy, dialog test turning Link off / on and then
   opening Black Level.

### Tests
- Pure: arrangement guess from two card positions (`domain/edge_blend_pair.dart`), facing
  edges per arrangement, linked max (min of both), Link availability by raster, the
  canvas layout (overlap = Start(A) + Start(B) + max(Width(A), Width(B)), centred, fixed
  scale per arrangement).
- Manual: `tool/projector_simulator.dart` answers every blending / black level command
  with the §8 limits and ER402 (`EdgeBlendSim`, added 2026-10-13), so pair mode can be
  tested on 2 simulated projectors (both Tier A: add a WUXGA model there for the mixed-tier
  case); on hardware check the RQ25K + RZ34K pair (Link disabled, mixed tier) and two
  equal projectors.
