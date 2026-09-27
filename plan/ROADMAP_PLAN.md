# Product Roadmap — Feature, Reliability & UI Plan

Status: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not doing · `[later]` deferred

Source: brainstorm of 2026-09-27 (features / reliability / UI) plus the owner's review notes on
each item. This file records **what was decided and why**, and holds the design for every
accepted item so each can be picked up independently. Edge Blending has its own plan
(`EDGE_BLENDING_PLAN.md`) and is not repeated here.

---

## 0. Decisions from the review

| # | Proposal | Decision | Reasoning (owner's notes) |
|---|---|---|---|
| F1 | Settings backup / restore / clone | **Accepted** → §1 | Strong value; the owner asked for UX + implementation design |
| F2 | Apply dialog settings to a group | `[dropped]` | Every projector is tuned individually; a rarely used feature |
| F3 | Cues / scenes | **Accepted** → §2 | Owner asked for UX + implementation design |
| F4 | Alignment mode (solo / identify) | **Accepted** → §3 | "Very useful" |
| F5 | Telemetry alerts | **Accepted** → §4 | |
| F6 | Network discovery | `[dropped]` | Already exists — the Add Projector dialog scans the network |
| F7 | Two-way OSC | **Reframed** → §5 | The owner prefers a local web server / API so monitoring can be viewed from any device (phone, laptop) |
| R1 | Per-projector command queue | `[later]` | Stress test: newer models have no session cap, only slower replies; Geometry/Color dialogs open rarely. Revisit only if field reports show `ERR3` on older models |
| R2 | Credentials in OS keychain | `[dropped]` | Not a concern for this deployment |
| R3 | Autosave / crash recovery | `[dropped]` | The project holds only card layout, cheap to redo |
| R4 | Global error handler + log file | **Clarified** → §6, awaiting a go/no-go | The owner didn't follow the original one-liner — explained in §6 |
| R5 | Show lock mode | `[later]` | During shows the app is mostly used for monitoring; accidental commands are unlikely |
| R6 | Pre-release test suite | **Accepted** → §7 | Owner asked for a concrete list |
| U1 | Fix light theme in dialogs | **Accepted** → §8 | |
| U2 | Shared dialog widgets | **Accepted** → §9 | |
| U3 | Group command result summary | **Accepted** → §10 | |
| U4 | Side panel instead of modal dialogs | `[dropped]` | Doesn't fit the current layout; dialogs are open → adjust → close, rarely revisited |
| U5 | Command palette (Ctrl+K) | **Accepted** → §11 | Owner asked for UX + code design |
| U6 | Monitoring table keyboard/filter/export | `[later]` | Already tracked in `MONITORING_UI_PLAN.md` §5/§7/§9 |

Suggested order (value ÷ effort, and what unblocks what):
**U1 → U2 → (Edge Blending) → F1 → F4 → U3 → F5 → F3 → U5 → F7/§5 → R6 in parallel throughout.**
U1 and U2 come first because Edge Blending and F1 both build on them.

---

## 1. `[ ]` F1 — Settings Backup, Restore & Clone

### Why
Swapping a failed projector mid-show means re-entering geometry, colour, brightness and
blending by hand. Neither VSS nor Geometry Manager Pro makes "save this unit's picture setup and
put it on the replacement" a one-click flow.

### UX
- **Card context menu → "Settings" submenu:**
  - *Back Up Settings…* → reads the unit and stores a named snapshot (default name
    `<projector name> · <date time>`).
  - *Restore Settings…* → opens the **Snapshots dialog** filtered to this projector.
  - *Copy Settings To…* → picks a snapshot of *another* projector and applies it here
    (the swap case).
- **Tools menu → "Back Up All Projectors"** — one snapshot per online projector, with a
  progress bar (`n / total`) and a result summary (see §10).
- **Snapshots dialog** (`DialogTitleBar` + list):
  - Left: list of snapshots — name, source projector, model, date; search box on top.
  - Right: details of the selected snapshot, grouped by **section chips**
    (Geometry · Color · Brightness · Edge Blending · Picture), each with a checkbox so the user
    can restore only part of it (e.g. "Geometry only").
  - **Diff view** (optional second step): before applying, read the live values and show only
    the registers that differ — `Current → Snapshot` — so the user sees what will change.
  - Footer: *Apply* (FilledButton) with a progress indicator; per-register failures listed
    after the run.
  - **Model guard:** if the target model differs from the snapshot's model, show a warning
    banner and disable sections known to be model-specific (Corner limits, Edge Blend limits).

### Storage
Snapshots live **next to the project** in `%APPDATA%\ProjectorGrid\snapshots\` (macOS:
`~/Library/Application Support/ProjectorGrid/snapshots/`), one JSON file per snapshot, so they
survive project edits and can be copied between machines. Using `app_config_dir.dart`, plain
JSON — no new dependencies (consistent with the persistence rules in CLAUDE.md).

```json
{
  "version": 1,
  "name": "PJ-03 · 2026-09-27 14:02",
  "createdAt": "2026-09-27T14:02:11Z",
  "source": { "ip": "192.168.0.114", "model": "PT-RQ35K", "serial": "SH1234567" },
  "sections": {
    "geometry":   { "GMMI0": "+00010", "GMFI1": "+00012", "...": "..." },
    "color":      { "CMAI0": "+00001", "QHR": "...", "...": "..." },
    "brightness": { "OPEI1": "+00000", "LOPI2": "+01000", "LOPI3": "+01000" },
    "edgeBlend":  { "EDBI0": "+00001", "GU": "0", "EU": "0000", "...": "..." }
  }
}
```
Values are stored **raw, exactly as the projector returned them**, so restore is
`write(key, raw)` with no per-field reformatting and no rounding drift.

### Code
- `lib/core/services/settings_registry.dart` — **one table** of every backed-up register:
  `SettingRegister(section, key, queryCmd, writeCmd(raw), order)`. Reuses the command families
  already known (VXX / legacy short / RGBW tuple). The Geometry, Color, Brightness and Edge
  Blending dialogs should read their register keys from here too, so the list can't drift.
- `lib/core/services/settings_snapshot_service.dart` — `capture(node)` / `apply(node,
  snapshot, sections)`: sequential reads with the batch-of-8 cap
  (`sendRawCommandsBatched`, introduced in Edge Blending step 1). Writes run **in `order`**
  — e.g. `GMMI0` (mode) before its parameters, `EDBI0` before edge values, `QPDI1` before
  geometry on Quad Pixel Drive models (the auto-enable rule from
  `QUAD_PIXEL_DRIVE_CORNER_LIMITS.md`).
- `lib/features/workspace/domain/settings_snapshot.dart` — plain Dart model with hand-written
  `toJson`/`fromJson` (like `CustomCommand`).
- `presentation/providers/snapshots_provider.dart` — list of snapshots on disk (`keepAlive`).
- `presentation/widgets/snapshots_dialog.dart` — the dialog.

### Open questions / risks
- **Lens memory and picture mode:** the command strings for reading/writing lens memory slots
  aren't in `command_reference.md`. Before adding a "Lens" section, the owner needs to supply them
  (per the `panasonic-ntcontrol` skill rule: don't guess commands).
- **Registers that can't be read in some states** (e.g. `QPDI1` → `ER401` while a geometry mode
  is active). The registry needs a per-register "read only when…" note; skip-and-report
  instead of failing the whole capture.
- Verify on a real unit that restoring *Corner* values after `GMMI0=+00010` lands exactly (same
  check as the Edge Blending live probe).

---

## 2. `[ ]` F3 — Cues (Scenes)

### Concept
A **cue** is a named, ordered list of actions applied to a target set of projectors. Firing
it is one click, one OSC message, one scheduled task, or one web-API call (§5).

Examples: *"Preshow"* (all: power on, shutter closed, input SDI1), *"Show"* (all: shutter
open, fade-in), *"Walk-in logo"* (group Stage: test pattern off, input HDMI2), *"Align"*
(all: crosshatch, OSD on).

### UX
- **New "Cues" strip** docked above the status bar in the Controls view: a horizontal row
  of cue buttons (FilledTonalButton, colour tag, optional shortcut badge `F1`–`F12`).
  One click fires; right-click → Edit / Duplicate / Delete; drag to reorder; `+` at the end
  opens the editor. Collapsible like the log panel (setting stored in `appSettingsProvider`).
- **Firing feedback:** the button shows a progress ring while running, then briefly turns
  green/amber with a result tooltip (`18/20 OK`) — the same summary as §10.
- **Cue Editor dialog** (`DialogTitleBar`, two columns):
  - Left: name, colour, target (*All* / *Group* / *Selected at fire time*), keyboard
    shortcut, OSC address (auto slug `/pgrid/cue/<slug>`, like custom commands).
  - Right: **action list** — each row = action picker (the same command catalogue as the
    control bar: Power, Shutter, Input, Test Pattern, Lens, Picture Mode, Custom Command) +
    parameter + optional **delay after** (e.g. wait 30 s for warm-up). Rows reorder by drag
    (`ReorderableListView`).
  - "Test" button fires the cue on the *selected* projectors only.
- **Scheduled Tasks integration:** the task editor's command picker gains a "Cue" category,
  so the existing scheduler (`ScheduledTask.command`) can fire cues without a second
  scheduler.
- **Keyboard:** `F1`–`F12` fire bound cues (added to the `Shortcuts` map in
  `main_workspace_screen.dart`; respect the IndexedStack focus note in CLAUDE.md).

### Code
- `domain/cue.dart` — Freezed: `Cue { id, name, colorValue, target, groupId?, shortcut?,
  List<CueAction> actions }`, `CueAction { command, label, delayAfterMs }`.
- `presentation/providers/cues_provider.dart` — list + `fire(cueId)`. `fire` resolves targets
  and calls `WorkspaceNotifier._dispatchToNodes` (made accessible via a public
  `dispatchCommand(targets, cmd)` returning per-node results — see §10). Actions run in
  sequence; each action fans out to all targets in parallel (the existing batch logic).
  Firing a second cue while one runs → cancel the first (a generation counter, the same
  pattern the poll loop uses).
- Cues are saved **in the project file** (they are show-specific): project JSON `version`
  → 3 with a `cues` array; loading a v2 file gives an empty list.
- OSC: `osc_service.dart` routes `/pgrid/cue/<slug>` to `cuesProvider.fire`. Document it in
  `osc_reference_html.dart`.
- Event log: one `LogEvent` per cue (type `command`, "Cue *Show* — 20/20 OK").

---

## 3. `[ ]` F4 — Alignment Mode (Solo / Identify)

### Why
When converging a multi-projector setup you constantly need "show me only this projector,
with a crosshatch" and "which physical projector is PJ-07?".

Two related features: **Identify** is a standalone one-shot action usable at any time;
**Alignment mode** is a persistent working mode that also uses Identify internally.

Shortcut check (existing, from `keyboard_shortcuts_dialog.dart`): `I` = Shutter Close,
`O` = Shutter Open, `F` / `Shift+F` = Focus on selected / all, arrows (+ `Shift`/`Ctrl`) =
**Lens Shift** (unchanged — they stay Lens Shift in Alignment mode too), `Delete`,
`Ctrl+A/D/G/Z/Y/N/O/S/Q/1/2`, `F5`. Free and used below: `N`, `Shift+N`, `Ctrl+L`, `<` / `>`
(the `,` / `.` keys — bound with and without `Shift`, so no modifier is needed; macOS `Cmd+,`
Preferences is unaffected), `A`, `Esc`.

### UX — 3.1 Identify (standalone)
Answers "which physical projector is this card?" (and the reverse). Works outside Alignment
mode — typical use is right after rigging, or when a card's name doesn't match what's on the wall.
- **Where:** card context menu *Identify*, toolbar button, shortcut **`N`** (*Name*). Acts on
  the **selection** — one card, or several at once.
- **What happens (on screen):** each targeted projector shows its **name** on the image for
  ~5 s (the projector's own device-name OSD, as VSS's *Show Device Name* does). Fallback until
  that command is known or on models without it: the shutter blinks closed/open twice.
- **What happens (in the app):** the targeted cards pulse with a highlight ring for the same 5 s,
  so screen and UI point at the same unit.
- **Identify All** (toolbar dropdown / **`Shift+N`**): every projector shows its name at the same
  time — one look at the wall maps the whole layout. Pressing again (or `Esc`) hides the names
  early.

### UX — 3.2 Alignment mode
- **Enter:** toolbar toggle, shortcut **`Ctrl+L`**. A thin coloured banner across the workspace:
  **one row** — *"Alignment — PJ-03 · ◀ ▶ · Neighbours · Show All · Identify · Presets ▾ · Adjust ▾ ········ Exit"*
  (see *Responsive banner* below for narrow windows).
- **Decision (2026-09-27): Variant A — the banner over the workspace.** Rejected Variant B
  (an "Alignment" tab in the control bar): lens shift / zoom / focus live in the control bar's
  General tab and are used constantly while aligning, so a separate tab would force constant
  tab switching or duplicating the lens block. With Variant A the control bar stays untouched.
  Mockups: artifact *Edge Blending Dialog Mockup* → boards "Alignment · Variant A" (chosen)
  and "Variant B" (reference only). Refined the same day: everything in **one row**, pattern
  dropdowns moved into a **Presets ▾** popover, **Adjust ▾** menu for the dialogs.
- The **focused** projector: shutter open + the **Focused** pattern.
- **Open non-focused projectors** (neighbours, or everyone under Show All): the **Others**
  pattern.
- **All other projectors in scope** (All / current group): shutter closed.
- **Patterns — Presets ▾ popover.** Pattern settings aren't changed often, so they don't sit
  permanently in the banner: a single **Presets ▾** button (always, at every width) opens a
  popover with three dropdowns — *Preset*, *Focused*, *Others*. The right "Others" pattern
  depends on the task, so the **Preset** dropdown picks the task, sets default patterns, and **filters** what the *Focused*
  and *Others* dropdowns offer (from `control_bar.dart` `_testPatternOptions`). *Others* always
  also has **Same as focused**.
  | Preset | Dropdowns offer | Default focused | Default others | Use |
  |---|---|---|---|---|
  | **Geometry** (default) | all cross hatches: `OTS:07`, `70`–`75` (white, red, green, blue, cyan, magenta, yellow) | Cross Hatch `07` | Cross Hatch Red `70` | Converging lines in the overlap — colours tell which line is whose |
  | **Blend** | all solid colours: `OTS:01` white, `02` black, `22` red, `23` green, `24` blue, `28` cyan, `29` magenta, `30` yellow | White `01` | Same as focused | Checking the blend seam — a flat field must look uniform |
  | **Color** | same solid colours as Blend | White `01` | Same as focused | Colour/brightness matching between neighbours |
  | **Custom** | every test pattern | keeps current | keeps current | Anything else (window, colour bars, focus, circle…) |
  Changing a dropdown keeps the preset (the lists are already filtered to the task). Preset and
  both patterns are remembered in app settings.
- **Adjust ▾ menu** (one button, not four): a `MenuAnchor` with *Geometry*, *Edge Blending*,
  *Brightness*, *Color Correction* — each opens that dialog for the **focused** projector
  (Edge Blending hidden until `EDGE_BLENDING_PLAN.md` is implemented). One button instead of
  four keeps the banner narrow; the same dialogs stay reachable from the card context menu.
- **Responsive banner.** The banner spans the workspace only (the control panel on the right
  takes ~320 px), so at the minimum window size (800×600, `main.dart`) it gets **~480 px**;
  the full layout needs ~1000 px. The banner is **always a single row** in the same order —
  *name, ◀ ▶, Neighbours, Show All, Identify, Presets ▾, Adjust ▾* in line, then a spacer,
  *Exit* at the far right. A `LayoutBuilder` only changes how compact the controls are:
  | Banner width | Layout |
  |---|---|
  | **≥ 900 px** | Toggles as labelled pills with shortcut hints (*Show All · A*, *Identify · N*); Exit as *Exit · Esc* |
  | **600–900 px** | Toggles become **icon buttons** with tooltips (filled when on); Exit as *Exit* |
  | **< 600 px** (min window) | Icon toggles; name truncated with ellipsis; Exit as an icon |
  Name, ◀ ▶, Presets ▾, Adjust ▾ and Exit are never hidden. Every icon-only control keeps a
  tooltip with its shortcut (`Show All · A`).
- **Navigation — previous / next only:** **`<`** / **`>`** (or the banner ◀ ▶) step to the
  previous / next projector in **layout order: left→right, top→bottom**; wraps around at the
  ends. No up/down navigation. Clicking a card focuses it directly.
  The arrow keys keep their normal Lens Shift function — acting on the focused projector, which
  is exactly what's needed while converging it.
- **Identify inside the mode:** the banner's *Identify* button (or `N`) shows the name on
  **every projector currently open in the mode** (focused + neighbours, or all under Show
  All) — not only the focused one. Why it's still needed although the focused projector
  already has its own pattern:
  - With the **Blend / Color** presets (or *Same as focused*) every open projector shows the
    same image, so the wall alone no longer tells which one is focused — Identify does.
  - Even with distinct patterns, it confirms **which neighbour is which** (e.g. that the
    projector overlapping on the right really is PJ-06), i.e. that the card layout matches
    the wall before trusting the neighbour detection.
  No "identify on switch" option — the focused pattern already marks the focused projector in
  the default preset, and an automatic 5 s name overlay on every `<`/`>` would get in the way.
- **Show neighbours** (banner toggle, default off, remembered in app settings):
  - Also opens the shutters of the focused projector's **neighbours**, so the overlap is
    visible while tuning geometry or the blend.
  - Neighbours are derived from **card geometry** on the workspace (the snap grid is only
    20 px while cards are 120×100, so "one grid step" can't be the rule). For the focused card
    A, per side (left / right / above / below) the neighbour is the **nearest** card B that:
    1. lies on that side with an edge-to-edge **gap ≤ 60 px** (3 snap steps; the auto-layout
       uses 20 px horizontal / 40 px vertical gaps, so a default grid always qualifies), and
    2. **overlaps A by ≥ 50 %** on the other axis — vertical overlap ≥ 50 px for left/right,
       horizontal overlap ≥ 60 px for above/below — so a card half a row lower still counts,
       but one clearly in another row doesn't.
    At most one neighbour per side. Optional **diagonals**: the nearest card with both gaps
    ≤ 60 px and no ≥ 50 % overlap on either axis (the corner-overlap case on 2×2+ walls).
  - The rule assumes the card layout mirrors the physical wall. For odd layouts,
    **`Ctrl+click`** on a card in Alignment mode toggles it as a neighbour manually (kept for
    the session, cleared on Exit).
  - Neighbours show the **Others** pattern (see Patterns above).
  - Neighbour cards get a secondary (dimmer) highlight ring in the workspace.
- **Show All** (banner toggle, shortcut **`A`**) — a temporary overview of the whole wall:
  - On: opens the shutters of **every** projector in scope. The focused projector keeps the
    *Focused* pattern; all others show the *Others* pattern (with the Geometry preset the
    focused one still stands out; with Blend/Color everyone shows the same field).
  - Off (toggle again, or `A`): returns to the **previous view** — solo (only the focused
    projector open) or, if *Show neighbours* was on, focused + neighbours.
  - `<` / `>` still work while Show All is on: they only move the focus (pattern swap between
    the old and new focused projector); shutters stay open until Show All is turned off.
  - Exiting Alignment mode from Show All restores the pre-mode state as usual.
- **Exit** (banner button, `Esc`, or `Ctrl+L` again) restores each projector's shutter and
  test pattern **to what it was before entering** (captured on entry), not just "all open".
- `keyboard_shortcuts_dialog.dart` gets an "Alignment" section listing `N`, `Shift+N`,
  `Ctrl+L`, `<` / `>`, `A` and `Esc`.

### UX — 3.3 Test-pattern indicator on cards (always, not only in the mode)
Today the card header (`projector_card.dart`) shows: power icon · shutter (eye) icon ·
conditional warning icon · spacer · conditional lock icon · connection dot. The header's
usable width is 104 px (120 − 2×8 padding); with every conditional icon visible it already
uses ~74 px, so a fourth status icon there would be cramped and hard to scan.

**Placement: card body, bottom-right, on the IP row** — not the header:
- The header stays "status" (power, shutter, errors, auth, connection); the body shows
  "what's being projected". The body row with the IP has free space on the right (an IP like
  `192.168.100.200` at `bodySmall` is ~85 px of the 104 px).
- A 16×10 px mini thumbnail drawn from the existing `assets/icons/test_patterns/*.svg`
  (same icons as the control bar) — white field, red crosshatch, colour bars are recognisable
  at that size; thin `outlineVariant` border so white/black fields don't vanish into the card.
- Shown only when a test pattern is active (`OTS` ≠ `00`) **and the shutter is open** (a
  pattern behind a closed shutter isn't on screen); normal show cards look exactly as today.
- Tooltip on the thumbnail: "Test pattern: Cross Hatch Red".
- Monitoring table: optional "Test pattern" column (text) via the existing column chooser.
- Alignment mode reuses it, so the card itself shows who has which pattern — no extra labels.

Data: `ProjectorNode.testPattern` (Freezed, `String?`, OTS code). Set optimistically from
every `OTS:xx` the app sends (`_applyOptimisticUpdate`, like shutter/power); if a test-pattern
**query** command exists (`QTS`? — confirm via the `panasonic-ntcontrol` skill / the owner,
don't guess), also add it to `pollProjectorTelemetry` so changes made on the projector or by
other software show up. Transient telemetry → covered by `_stripTransient`/`_mergeWithTelemetry`.

### Code
- `presentation/providers/identify_provider.dart` — `identify(Set<String> nodeIds)`,
  `identifyAll()`, `cancel()`; holds `Set<String> pulsing` for the card ring and a 5 s timer.
  Sends the device-name OSD on/off (or the shutter-blink fallback) through the group
  dispatch from §10.
- `presentation/providers/alignment_provider.dart` — state `{active, scope, focusedId,
  preset, focusedPattern, othersPattern (null = same as focused), showNeighbours,
  includeDiagonals, showAll, Set<String> manualNeighbours,
  Map<id, (shutter, pattern)> saved}`; `enter()`, `focus(id)`, `next()/prev()`,
  `toggleShowAll()`, `exit()`. Each projector's role is derived from state
  (`focused` / `neighbour` / `shown` / `closed`); on every change only projectors whose role
  changed get commands — not the whole wall. Show All off simply recomputes roles from
  `showNeighbours`, which gives the "return to the previous view" behaviour for free.
- `lib/features/workspace/domain/card_layout.dart` — pure functions, unit-tested (§7.1):
  - `layoutOrder(nodes)` — sort by `y` then `x` with a row tolerance of half a card height.
  - `neighbours(node, nodes, {maxGap = 60, minOverlap = 0.5, diagonals})` — the gap/overlap
    rule above, card size taken from the shared 120×100 constants (currently duplicated in
    `projector_workspace.dart` and `workspace_provider.dart` — move them to one place).
    Unit tests: default auto-grid, staggered rows, wide gaps, single row, 1 card.
- Keyboard: `<` / `>` (`comma` / `period`, with or without Shift), `A`, `N`, `Shift+N`,
  `Ctrl+L`, `Esc` registered next to the existing `I`/`O`/`F` bindings; `<`/`>`/`A`/`Esc` are
  active only while `alignmentProvider.active`. Arrow keys are untouched (Lens Shift).
- Commands reuse `OSH:0/1` and `OTS:xx`; the current test pattern is read once on entry for
  the restore (confirm the query string with the owner/skill before implementing).
- Banner widget in `projector_workspace.dart`'s Stack; focused card = primary ring, neighbours
  = dimmer secondary ring, Identify = pulsing ring.
- **Needs a command:** the device-name OSD command isn't in `command_reference.md`. VSS has
  *Show Device Name*, so it exists — the owner supplies it from the RS-232C/LAN command list
  or a Wireshark capture of VSS pressing that button. Until then Identify uses the
  shutter-blink fallback.

---

## 4. `[ ]` F5 — Telemetry Alerts

### Why
The app polls temperatures, runtime, light-source hours and `QVX:ERRS2` errors already, but
only shows them. Nobody watches a table all night.

### Alert rules (defaults, all editable)
| Rule | Default | Source |
|---|---|---|
| Went offline (after N consecutive failed polls) | N = 2 | `connectionStatus` |
| New projector error | any change in `errors` away from `NO ERRORS` | `QVX:ERRS2` |
| Intake temperature above | 40 °C | `QTM:0` |
| Exhaust temperature above | 60 °C | `QTM:1` |
| Light-source hours above | 20 000 h | `QVX:LRTS3` |
| No signal while powered on and shutter open | 10 s | `signal` + power + shutter |

Each rule has hysteresis (e.g. clear only when 2 °C below the threshold) so values hovering
near the limit don't flap.

### UX
- **Preferences → new "Alerts" tab:** rule list with enable switch + threshold stepper
  (`SleekStepperInput`), and delivery options:
  - Event log (always on).
  - **Desktop notification** (Windows toast / macOS Notification Center).
  - **OSC** `/pgrid/alert/<rule> "<projector name>" <value>` to the configured send target.
  - Sound (single short system sound, off by default).
- **Card:** a small alert badge (amber/red) replacing the generic warning icon when a rule is
  active; tooltip lists active alerts.
- **Status bar:** the existing *warnings* count becomes clickable → opens an **Active Alerts**
  popover (projector, rule, value, since) with *Acknowledge* (silences repeats until the
  condition clears and re-triggers).
- **Monitoring table:** cells that trip a rule are tinted.

### Code
- `domain/alert_rule.dart` (plain Dart + JSON, saved in app settings — alerts are a machine
  preference, not per-project).
- `presentation/providers/alerts_provider.dart` (`keepAlive`) — `ref.listen(workspaceProvider)`,
  evaluates rules per node on each telemetry change, keeps `Map<(nodeId, rule), ActiveAlert>`,
  emits transitions only (raised / cleared) to the event log, OSC and notifications.
  Must not rebuild on every tick — compare previous vs next per node (the same dedupe idea as
  `statusSummaryProvider`).
- Temperatures are stored formatted (`_formatTemp`) — add numeric parsing in one place (or
  keep raw numeric fields on `ProjectorNode`: Freezed field + `build_runner`).
- Desktop notifications: evaluate `local_notifier` (Windows + macOS) vs a platform channel;
  pick after a quick spike — this is the only new dependency in the plan.

---

## 5. `[ ]` F7 (reframed) — Local Web Monitor & HTTP API

### Why
Monitoring from any device on the show network — a phone at FOH, a laptop in the projection
booth — without installing anything.

### UX
- **Preferences → "Web Access" tab:** enable switch, port (default 8080), optional access PIN,
  *read-only* vs *control* mode, and the URL + **QR code** (`http://<this-machine-ip>:8080`)
  to open it on a phone.
- **Web page** (served by the app, mobile-first):
  - Summary header: online / offline / warnings counts, active alerts (§4).
  - Projector list grouped by group: name, power, shutter, input/signal, temps, errors —
    colour states like the app's cards.
  - Live updates via **Server-Sent Events** (simpler than WebSocket, auto-reconnect in
    browsers).
  - In *control* mode: per-projector and per-group buttons (power, shutter) and the Cues
    strip (§2). Every write asks for confirmation on the page.
- The app shows a small "Web access on · 2 clients" indicator in the status bar.

### API (same server)
| Method | Path | |
|---|---|---|
| GET | `/api/projectors` | all nodes + telemetry (JSON) |
| GET | `/api/projectors/{id}` | one node |
| GET | `/api/groups` | groups |
| GET | `/api/alerts` | active alerts |
| GET | `/api/events` | SSE stream: node changes, alerts, cue results |
| POST | `/api/projectors/{id}/command` | `{ "command": "OSH:1" }` — control mode only |
| POST | `/api/groups/{id}/command` | same, for a group |
| POST | `/api/cues/{id}/fire` | fire a cue |

Useful beyond the web page: Companion, QLab, custom scripts can poll or drive the app over HTTP.

### Code
- `lib/core/services/web_server_service.dart` — `dart:io` `HttpServer.bind(InternetAddress.anyIPv4, port)`
  with a small router; **no new dependency needed** (`shelf` is an option if routing grows).
  Transport-only, like `osc_service.dart`.
- `presentation/providers/web_server_provider.dart` (`keepAlive`) — lifecycle from settings,
  pushes SSE events from `ref.listen(workspaceProvider)` / alerts / cues.
- Web page: a single static HTML/JS/CSS file embedded as a Dart string (same approach as
  `lib/core/docs/osc_reference_html.dart`) — no build step.
- Security: bind on all interfaces only when enabled; PIN as a bearer token for `POST`;
  control mode off by default; firewall prompt on Windows on first bind — document it.
- Keep the small OSC addition from the original F7 as a follow-up:
  `/pgrid/query/<projector>` → reply with status to the sender.

---

## 6. `[ ]` R4 — Global Error Handler & Log File (explanation, awaiting go/no-go)

### What it means
Today, if an unexpected exception is thrown somewhere in Flutter code (a widget build error, a
failed `Future` nobody awaited, a parsing bug on an odd projector reply), it goes to the debug
console only. In a release build **nobody sees it**: the UI may freeze partially or a feature
may silently stop working, and there is no trace left afterwards. Also, the in-app Event Log
keeps only the last 500 entries in memory — once the app is closed, the history of the night
(what went offline, which commands failed) is gone.

### Proposal
1. **Catch everything** in `main.dart`: `FlutterError.onError` (framework errors),
   `PlatformDispatcher.instance.onError` (uncaught async errors), wrap `runApp` in
   `runZonedGuarded`. Each caught error → an `error` entry in the Event Log (visible in the
   app) and a line in the log file.
2. **Persistent log file:** `%APPDATA%\ProjectorGrid\logs\projector-grid-YYYY-MM-DD.log`, one
   line per `LogEvent` + caught errors with stack trace; keep the last 14 days.
   Help menu → *Open Logs Folder*.
3. Result: after a show you can open the day's log and see exactly when PJ-07 dropped off, which
   command failed, and whether the app hit an internal error.

Small (≈1 day), no new dependencies. Also listed as item 7 in `IMPROVEMENT_PLAN.md`.

---

## 7. `[ ]` R6 — Pre-release Test Suite

Today there is one smoke test (`test/widget_test.dart`). Priorities, cheapest and highest value
first. Use the `test-writer` agent; fakes instead of real sockets.

### 7.1 Unit tests — pure logic (no Flutter)
- **Protocol parsing/formatting** (`panasonic_protocol_service.dart`):
  `00` prefix stripping (incl. model names containing `00`), `_isFailureResponse` vs
  `_isTransportFailure` (`Timeout`, `Error: …`, `ERR3`, `ER401`), MD5 prefix for a known
  token/login/password.
- **Telemetry parsing** in `_pollSingleProjector`: `LRTS3=00:<hours>` (parse after last `:`),
  `ERRS2=` empty → `NO ERRORS`, voltage `VMOI2` lengths, temps via `_formatTemp`,
  `ER401` handling for runtime/signal, fallback to last-known value on transport failure.
  → Extract these into pure functions first (a small refactor) so they're testable.
- **Dialog formatters:** `_fmtInt` (`+00012`, `-00012`), `_fmtDeg`, `_fmtThrow`, `_parseValue`
  with and without `KEY=`; Edge Blending `f4` / RGBW tuple once added.
- **Corner Correction maths:** `_toCanvas`/`_toRaw` round-trip on standard and Quad Pixel Drive
  (Tier A) models, clamps at inward/outward limits (`QUAD_PIXEL_DRIVE_CORNER_LIMITS.md`).
- **Model tier matching:** `PT-RQ35K`, `PT-RQ35KL`, `PT-RQ35K2` → Tier A; `PT-RQ32K` → Tier B;
  unrelated → none.
- **`commandLabel`** mapping for every control-bar command.
- **OSC codec:** address matching, argument types, custom-command slugs (`tool/osc_codec_test.dart`
  has cases worth porting into `test/`).
- **Scheduler:** `_isDue` for once/daily/weekly, missed-run behaviour, and the known DST
  spring-forward case (`IMPROVEMENT_PLAN.md` item 10) as a regression test.

### 7.2 Provider tests (Riverpod `ProviderContainer` + fake protocol service)
Requires `PanasonicProtocolService` to be injectable (a provider, or constructor param) —
`IMPROVEMENT_PLAN.md` item 5; do this refactor first.
- `workspaceProvider`: add/delete/move nodes; **undo/redo keeps live telemetry**
  (`_stripTransient` / `_mergeWithTelemetry` — a documented invariant in CLAUDE.md).
- Optimistic updates: `PON` → `turningOn`, shutter commands flip state, reverted on failure.
- Polling: offline after failures, "Came online" / "Went offline" log events emitted once.
- `projectStateProvider`: save → load round-trip of the JSON (v2 today, v3 with cues later);
  dirty flag set/cleared correctly; recent-projects list capped.
- `statusSummaryProvider`: counts; doesn't emit when counts are unchanged.
- `eventLogProvider`: capped at 500.
- `customCommandsProvider`: slug generation uniqueness.

### 7.3 Widget tests
- Projector card context menu: every item present and wired (Geometry, Edge Blending, …).
- Geometry dialog with a fake service: loads mode, switching mode sends `VXX:GMMI0=…`,
  a failed write shows the failure notice.
- `SleekStepperInput`: typing + Enter commits, clamps to min/max, invalid text reverts,
  up/down step.
- Keyboard shortcuts after switching Controls ↔ Monitoring (the IndexedStack focus quirk):
  Ctrl+A still selects all.
- Window close with unsaved changes shows the confirm dialog (mock `windowManager`).

### 7.4 Release gate (CI)
`.github/` exists — add a workflow on Windows + macOS runners:
`dart run build_runner build` → `dart format --set-exit-if-changed .` → `flutter analyze` →
`flutter test --coverage`. Block merges to `main` on failure.

---

## 8. `[ ]` U1 — Light Theme Fix in Dialogs

Hard-coded dark-only colours make dialog labels and inputs nearly invisible in the light theme:
- `geometry_correction_dialog.dart` — labels use `Colors.white70` (`_sliderRow`,
  `_labeledSlider`, `_throwRatioField`).
- `sleek_stepper_input.dart` — fill `Colors.white.withValues(alpha: 0.06)`, borders/dividers
  `Colors.white.withValues(alpha: 0.1)`, focus `Colors.blueAccent`.

Fix: `colorScheme.onSurfaceVariant` for labels; `onSurface` at 6 % / `outlineVariant` for the
stepper fill/borders; `colorScheme.primary` at 50 % for focus. Grep the rest of `lib/` for
`Colors.white` / `Colors.black` used as text/border colours and fix the same way. Verify with
the `flutter-windows-gui-check` skill in both themes.

---

## 9. `[ ]` U2 — Shared Dialog Widgets

Geometry, Color, Brightness and the upcoming Edge Blending dialog each carry their own copies of
the same building blocks. Extract into `presentation/widgets/common/`:
- `LabeledSliderRow` — label + slider + `SleekStepperInput`, optional disabled state
  (keeping the `IgnorePointer` + `Opacity` trick so State isn't recreated), inline or
  label-above layout.
- `SectionCard` — the `_sectionCard` style from `color_correction_dialog.dart`.
- `ProjectorSettingsClient` — wraps `ip/port/login/password` + `sendRawCommand` +
  `notifyCommandFailure`; `readInt / readDouble / writeInt / writeDeg / writeRaw`; replaces
  the per-dialog `_parseValue/_parseInt/_sendInt/_notifyFailure` copies. Uses the settings
  registry from §1 for key names.
- `DialogSplitLayout` — canvas-left / controls-right split (`_buildSplitLayout`).

Migrate one dialog at a time, behaviour unchanged; Edge Blending is built on these from day one.

---

## 10. `[ ]` U3 — Group Command Result Summary

Today `_dispatchToNodes` logs one event per node and returns nothing; on a 30-projector
"Power On" the user can't tell at a glance whether everything worked.

- `_dispatchToNodes` returns `DispatchResult { int ok; List<ProjectorNode> failed; List<ProjectorNode> skippedOffline; }`.
- After a group/all/selection command, a **SnackBar** (floating, bottom-left above the status
  bar): *"Power On — 28/30 OK · 2 failed"* with a **Details** action → a small dialog listing
  failed and skipped projectors, each with a *Retry* button and *Retry all failed*.
- Single-projector commands keep today's behaviour (no snackbar noise).
- Reused by Cues (§2), the web API (§5) and scheduled tasks (logged summary line).

---

## 11. `[ ]` U5 — Command Palette (Ctrl+K)

### UX
- `Ctrl+K` (`Cmd+K` on macOS) opens a centered overlay: search field on top, results below,
  keyboard-first (`↑/↓`, `Enter`, `Esc`).
- Result kinds, each with an icon and a right-aligned hint:
  - **Projectors** — by name or IP → *Enter* selects the card and scrolls/zooms to it
    (reuse *Focus on Selected*); `Ctrl+Enter` opens its context menu actions as a
    sub-list (Geometry, Color, Edge Blending, Remote Preview…).
  - **Groups** → select the group.
  - **Actions** — "Power On selected", "Shutter Close all", "Open Preferences", "Toggle
    Monitoring", "Back Up All Projectors"… with their existing shortcut shown.
  - **Cues** (§2) → fire.
  - **Custom commands** → send to selection.
- Fuzzy matching (subsequence with scoring: prefix > word start > anywhere); empty query shows
  recent items.
- Actions that target "selected" show the current selection count; a destructive action
  (Power Off all) asks for confirmation.

### Code
- `presentation/widgets/command_palette.dart` — overlay via `showDialog` with a transparent
  barrier, `TextField` + `ListView`, `Focus`/`Shortcuts` for arrow keys.
- `presentation/providers/command_palette_provider.dart` — builds `List<PaletteEntry>
  { kind, title, subtitle, icon, shortcut, run }` from `workspaceProvider`, groups, cues,
  custom commands and a static action table; recent items kept in memory.
- Register the shortcut in `main_workspace_screen.dart` `Shortcuts`/`Actions` (and the macOS
  menu bar), respecting the IndexedStack focus note.
- Unit-test the fuzzy matcher (§7.1).

---

## 12. Open inputs needed from the owner
- Command strings for: lens memory load/save/read, current test pattern query, device-name
  OSD / identify (F1, F4).
- Alert default thresholds per model family, if the defaults in §4 don't fit.
- Go / no-go on §6 (error handler + log file).
