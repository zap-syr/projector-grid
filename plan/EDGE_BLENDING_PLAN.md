# Edge Blending — Implementation Plan

## Context

The user wants to control Edge Blending on Panasonic projectors (reference models: PT-RQ35K and
PT-RZ34K) directly from Projector Grid instead of opening VSS or Geometry Manager Pro.

- Command source: `d:\Flutter\support files\Panasonic - Edge Blending - Sheet1.csv`.
- UI references:
  - **Mockup** (interactive, Claude Design canvas): <https://claude.ai/artifact/BaMmVBj2LTZQFdsFijHDW6>,
    artboard *Edge Blending dialog*. The canvas's other artboards (*Alignment …*) belong to
    Alignment mode, not this plan.
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
| Black border area adjust U/L/L/R on/off | `VXX:EBFI1..4` | `QVX:EBFI1..4` |
| ↳ Free-shape adjustment points (2/3/5/9/17) | `VXX:EFPI1..4` | `QVX:EFPI1..4` |
| ↳ Execute (no query) | `VXX:EFII1..4=+00001` | — |

**Interlocked semantics:** ON → the W slider moves R/G/B together (single slider); OFF → four
independent channels. In the UI this toggles the same card between "1 slider" and "4 sliders".

**Not available over the protocol:** free-shape point coordinates and the user blending curve
(*User* mode) — they can only be selected/executed, not edited. In the UI: *User* is just a mode
segment (tooltip: "curve is defined on the projector"); free shape = point-count dropdown +
Execute button, no point editor.

---

## 2. UX / interface

Visual reference for this section: the *Edge Blending dialog* artboard in the
[mockup](https://claude.ai/artifact/BaMmVBj2LTZQFdsFijHDW6). Where the mockup and this text
disagree, settle it before stage 3 (§5). Slider ranges in the mockup are illustrative only — the
app implements the real limits from §8.

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
- Mode `Off` → controls dimmed (like `_buildOffBody` in geometry), but the canvas stays
  visible so the user still sees the current zones.
- Size: `minWidth 560, maxWidth 960, maxHeight 0.9 × screen` — same as geometry.

### Edge Blending canvas (the main visual element)
- Raster rectangle in the model's **real aspect ratio** (16:10 for 3840×2400 / 1920×1200),
  scaled via `FittedBox` + `_renderScale` exactly like `_CornerCorrectionCanvas`.
- For each enabled edge: the **blend zone** is filled with a gradient (transparent → dark,
  `ui.Gradient.linear`) from the Start line to Start+Width; Start line in primary color, zone
  end line in tertiary (equivalent of GMP's red/green lines).
- Disabled edge — dashed outline of the zone at its stored values (shows what enabling it will
  do), no fill.
- **Dragging:** handles at the midpoints of the lines. Dragging the Start line moves the whole
  zone (width preserved); dragging the outer line changes width. Cursors
  `SystemMouseCursors.resizeLeftRight / resizeUpDown`.
- Clicking a zone/handle selects that edge (highlights its card on the right via a shared
  `selectedEdge`); **arrow keys** ±1 unit, **Shift+arrows** ±10; hold → auto-repeat (reuse the
  hold/repeat logic from `_CornerCorrectionCanvasState`).
- Double-click a handle → reset that edge's start/width to 0.
- Value labels next to the handles while dragging (`TextPainter` in the painter).
- ↺ "Reset all edges" button in the panel corner (like Corner Correction).

### Edge Blending controls panel
- Toggle row: **Markers** (`VGM`) and **Auto test pattern** (`EATI1`) — labeled `Switch`es.
- 4 **section cards** (reuse the `_sectionCard` style from `color_correction_dialog.dart:519`):
  edge title + enable `Switch`; inside, two rows *Start* / *Width* = `Slider` +
  `SleekStepperInput` (the `_labeledSlider` pattern from geometry). When disabled —
  `IgnorePointer + Opacity 0.38` (same trick as `_sliderRow`, so State isn't recreated).
- VSS-style Upper/Left/Right/Lower "cross" — **not needed**: the canvas itself does that job
  (clicking an edge selects/enables it). Less duplication.

### Black Level tab
Left: same canvas in "black level" mode — shows the non-overlapped area (light), overlapped
zones (RGB swatches of current values), black border bands (hatched, width from `VJU/VJB/…`).
Black border widths are draggable via handles.

Right, top to bottom:
1. **Mode**: `SegmentedButton` *Soft edge + Black level* / *Black level only* (`EBMI1`).
2. **Non-overlapped black level** card: `Interlocked` checkbox; ON → single W slider (0–255);
   OFF → W/R/G/B sliders with colored channel dots (like the swatches in color cards).
3. **Overlapped black level** — compact GMP-style table (row = edge, columns R G B +
   Interlocked checkbox) to keep height down.
4. **Black border** card: level (W,R,G,B + Interlocked) + 4 widths.
5. **Black border area adjust** — 4 rows: `Switch` (EBFI) + `DropdownMenu` of points
   2/3/5/9/17 (EFPI) + **Execute** button (EFII).

This tab loads **lazily** on first open (as in Color Correction) — ~30 queries aren't spent
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
| `…/edge_blending/edge_blend_state.dart` | plain-Dart holders: `EdgeBlendState` (4× `EdgeSettings{enabled,start,width}`, marker, autoPattern, mode), `BlackLevelState` (`RgbwLevel{w,r,g,b,interlocked}`, border widths, area adjust) + enum `BlendEdge {upper,lower,left,right}` carrying command keys (`enableCmd:'GU'`, `startCmd:'EU'`, `widthKey:'EUWI0'`, …) — the whole command table in one place |
| `…/edge_blending/edge_blend_canvas.dart` | `EdgeBlendCanvas` (StatefulWidget: drag, focus, keys) + `_EdgeBlendPainter` |
| `…/edge_blending/edge_blend_panel.dart` | right-hand panel of the Edge Blending tab |
| `…/edge_blending/black_level_panel.dart` | right-hand panel of the Black Level tab, `RgbwLevelCard` |
| `lib/features/workspace/domain/edge_blend_limits.dart` | pure functions, unit-tested: `edgeBlendRasterFor(String model)` → `(h, v)` built on the existing `quadPixelTierFor` (`geometry_values.dart`) — Tier A 3840×2400, Tier B 5120×3200 (unverified), none 1920×1200 — so model detection stays in one place; plus the shared-raster max rules from §8 (Start/Width/Border max per edge from the current state). Read-back after ER402 covers anything not modeled |

Modified files:
- `projector_card.dart` — menu item + `onEdgeBlending`.
- `projector_workspace.dart` — `showDialog(EdgeBlendingDialog(node: node))`.
- `panasonic_protocol_service.dart` — extract the ≤8 batching (currently inline in
  `_loadCorner`, `geometry_correction_dialog.dart:214`) into a public
  `Future<List<String?>> sendRawCommandsBatched(ip, port, login, password, List<String> cmds, {int maxConcurrent = 8})`;
  switch geometry over to it.
- `.claude/skills/panasonic-ntcontrol/references/command_reference.md` — add the edge
  blending commands and reply formats (legacy short / RGBW tuple).

### Reuse
- `DialogTitleBar`, `SleekStepperInput`, `CustomTooltip`, `notifyCommandFailure`
  (`command_failure_notice.dart`).
- `_parseValue/_parseInt/_fmtInt` logic from geometry; for legacy replies (`QGU` → `1`)
  `_parseValue` already works (no `=` → whole reply). Add `_fmt4(int)` (`0716`) and
  `_fmtRgbw(RgbwLevel)` (`000,000,000,000`).
- Arrow-key hold/repeat and pointer→canvas scaling from `_CornerCorrectionCanvasState`.

### Data flow
1. `initState` → `sendRawCommandsBatched([QVX:EDBI0, QID, QGU…QGR, QEU…QER, QVX:E?WI0×4, QGM, QVX:EATI1])`
   (~16 commands, 2 batches).
2. On change: optimistic local `setState` → command sent on `onChangeEnd` / handle release /
   key-up (like Corner — never on every drag frame).
3. **Read-back after writing** Start/Width (one `Q…` query): the projector clamps values itself
   (e.g. start+width > max) — the UI syncs to the actual value; this also covers inaccurate
   per-model limits.
4. Write failure → `notifyCommandFailure`.

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
| Modes / toggles | `SegmentedButton`, `Switch`, `Checkbox`, `DropdownMenu` (M3) | consistent with the rest of the app |
| Tabs | `DefaultTabController` + `TabBar/TabBarView` | same as Color Correction |
| Section cards | `_sectionCard` style (surfaceContainerHighest + outlineVariant) | visual consistency |
| Accessibility | `Semantics(label: 'Upper blend start', value: '716', onIncrease/onDecrease)` on handles | CustomPaint handles are otherwise invisible to screen readers |
| Animation | `AnimatedOpacity`/`AnimatedSwitcher` (150 ms) for Off↔On and edge enable | soft transitions without distraction |

Rejected: third-party canvas packages — overkill; `InteractiveViewer` zoom — the raster
already fits the panel, zoom isn't needed.

---

## 5. Implementation stages

1. **Protocol:** `sendRawCommandsBatched` in the service, migrate `_loadCorner`;
   `edge_blend_limits.dart`; update `command_reference.md`.
2. **State/model:** `edge_blend_state.dart` (enum `BlendEdge` with command keys, holders,
   formatters).
3. **Dialog skeleton:** title, mode SegmentedButton, TabBar, loading, menu item + opening from
   the workspace.
4. **Edge Blending panel** (right-hand controls) — fully functional without the canvas.
5. **Edge Blending canvas:** painting → drag → keyboard → labels/hover → reset.
6. **Black Level tab:** lazy load, `RgbwLevelCard` with Interlocked, border widths, area
   adjust + Execute; black-level canvas mode.
7. `dart format .`, `flutter analyze`, review with the `reviewer` agent.

Later (not in this iteration): apply to group/selection, OSC addresses `/pgrid/blend/...`,
saving blend presets in the project file.

---

## 6. Critical files
- `lib/features/workspace/presentation/widgets/geometry_correction_dialog.dart` — reference pattern (loading, batching, canvas, keys)
- `lib/features/workspace/presentation/widgets/color_correction_dialog.dart` — TabBar, `_sectionCard`, lazy loading
- `lib/features/workspace/presentation/widgets/projector_card.dart:235` — context menu
- `lib/features/workspace/presentation/widgets/projector_workspace.dart:940` — dialog opening
- `lib/core/services/panasonic_protocol_service.dart:266` — `sendRawCommand`

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
- The panel recomputes every slider's max from the table above on each change; ER402 →
  read-back and sync.
