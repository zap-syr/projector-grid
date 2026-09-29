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
| R6 | Pre-release test suite | **Accepted** → §7, `[~]` suite in place | Owner asked for a concrete list |
| U1 | Fix light theme in dialogs | **Accepted** → §8, `[x]` done | |
| U2 | Shared dialog widgets | **Accepted** → §9, `[x]` done | |
| U3 | Group command result summary | **Accepted** → §10, `[x]` done | Summary goes to the Event Log, not a SnackBar |
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
    (Geometry · Color · Brightness · Edge Blending · Picture · Lens), each with a checkbox so the user
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
    "edgeBlend":  { "EDBI0": "+00001", "GU": "0", "EU": "0000", "...": "..." },
    "picture":    { "QPM": "USR", "QVR": "032", "QVB": "032", "QGA": "2.2", "...": "..." },
    "lens":       { "LNSI7": "+00120", "LNSI8": "-00310", "LNSI9": "+01733", "LNSIA": "+00870",
                    "NCGS5": "LENSMEMORY1", "...": "..." }
  }
}
```

**Lens section.** A snapshot can't carry lens-memory *contents*: NTCONTROL only loads, saves and
deletes slots (`VXX:LNMI1/2/3=+0000n`, memory 1–10 = `+00000`…`+00009`), with no query for a
slot's stored position or for the active slot. What *is* readable and writable is the absolute
lens position — `QVX:LNSI7` / `LNSI8` / `LNSI9` / `LNSIA` (shift H, shift V, focus, zoom) — so
the Lens section stores and restores those four values, plus the ten memory names
(`NCGS5`–`NCGS7`, `NCGS9`, `NCGSA`–`NCGSF`) for reference. Ranges depend on the lens, so
restore the Lens section only when `QVX:LNEI4` (lens ID) matches the snapshot's; otherwise
disable it with the model-guard banner. Swap workflow that keeps memories: restore the
position, then `VXX:LNMI2` saves it into the slot the user picks.

**Picture section.** Picture mode `VPM:xxx` / `QPM` (`DYN NAT STD CIN GRA DIC USR`) written
**first**, then the per-mode values: contrast `VCN`/`QVR`, brightness `VBR`/`QVB`, colour
`VCO`/`QVC`, tint `VTN`/`QVT`, sharpness `VSR`/`QVS`, colour temperature `OTE`/`QTE`, gamma
`VGA`/`QGA`, white balance `VOR`/`VOG`/`VOB`/`VHR`/`VHG`/`VHB`. Optional **Identity** section
(off by default): projector name `QVX:NCGS8` — useful when the replacement unit should take
the old unit's name.
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
- ~~Lens memory and picture mode commands~~ — **resolved 2026-09-28** from the PT-RQ35K2/RZ34K2
  command list (see Lens / Picture sections above and the skill's `command_reference.md`).
  Still to check on a live unit: the exact reply format of `QVX:LNSI7`…`LNSIA`, and whether
  writing an absolute position with `VXX:LNSI7=…` moves the lens there in one step.
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
    control bar: Power, Shutter, Input, Test Pattern, Lens Memory load `VXX:LNMI1=+0000n`,
    Picture Mode `VPM:xxx`, Freeze `OFZ:0/1`, Custom Command) +
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
- **What happens (on screen):** each targeted projector **flashes** for ~5 s so it stands out on
  the wall. The PT-RQ35K2/RZ34K2 command list has **no device-name OSD command** (VSS's *Show
  Device Name* isn't in it; `RIS`/`RVS` "ID" commands are IR-remote addressing, not a visual
  identify), so the name overlay stays a later upgrade if a Wireshark capture of VSS turns one
  up. Flash method, chosen so it doesn't depend on shutter fade settings:
  1. Read the current test pattern (`QTS`) and shutter (`QSH`).
  2. Open the shutter if closed (`OSH:0`), then alternate `OTS:01` white / `OTS:02` black
     every ~0.5 s for 5 s.
  3. Restore the previous pattern (`OTS:<saved>`) and shutter state.
  Why not blink the shutter: the projector applies its **shutter fade** (`QVX:SEFS1` fade-in /
  `SEFS2` fade-out, up to 10 s each) to every `OSH` command, so a shutter blink can take tens of
  seconds or be invisible. Test-pattern switching isn't faded. On a closed-shutter unit the
  first open still fades in — acceptable, it only delays the start.
  Worth trying on a live unit: `STS` (remote STATUS key) opens the status screen on the image —
  if it shows the projector name it's a cheap overlay alternative.
- **What happens (in the app):** the targeted cards pulse with a highlight ring for the same 5 s,
  so screen and UI point at the same unit.
- **Identify All** (toolbar dropdown / **`Shift+N`**): every projector flashes **one after
  another** in layout order (~2 s each), and the matching card pulses at the same moment — one
  pass maps the whole layout. (Flashing all at once only works with a name overlay, which isn't
  available.) Pressing again (or `Esc`) stops early and restores every unit.

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
- **Identify inside the mode:** the banner's *Identify* button (or `N`) flashes **every
  projector currently open in the mode** (focused + neighbours, or all under Show All) one
  after another in layout order, each with its card pulsing — not only the focused one — then
  puts the mode's patterns back. Why it's still needed although the focused projector
  already has its own pattern:
  - With the **Blend / Color** presets (or *Same as focused*) every open projector shows the
    same image, so the wall alone no longer tells which one is focused — Identify does.
  - Even with distinct patterns, it confirms **which neighbour is which** (e.g. that the
    projector overlapping on the right really is PJ-06), i.e. that the card layout matches
    the wall before trusting the neighbour detection.
  No "identify on switch" option — the focused pattern already marks the focused projector in
  the default preset, and an automatic flash on every `<`/`>` would get in the way.
- **Shutter fade is always 0 in the mode (decision 2026-09-28).** Projectors with a shutter
  fade set (`QVX:SEFS1` / `SEFS2`, up to 10 s) would make every `<`/`>` step and Show All
  toggle wait for the fade. It isn't an option in the UI; it just happens:
  - On entry, read `SEFS1`/`SEFS2` for each projector in scope. **Only where a value isn't
    `0.0`**, save it and write `VXX:SEFS1=0.0` / `VXX:SEFS2=0.0`. Projectors already at
    `0.0` aren't touched.
  - On Exit, write back the saved values, and only for the projectors that were changed.
  - This changes a projector setting temporarily, so the saved values also go to app settings.
    If the app quits or crashes mid-mode, they're restored on the next launch (projectors that
    are offline then keep the entry pending until they come back).
  - Event log: one line per projector changed, e.g. "Shutter fade 2.0/2.0 s → 0 for alignment",
    and one line when it's restored.
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
every `OTS:xx` the app sends (`_applyOptimisticUpdate`, like shutter/power), and polled with
**`QTS`** (confirmed in the PT-RQ35K2/RZ34K2 list; reply is the bare two-digit code, e.g. `07`
→ store as `OTS:07` so it matches the icon/label maps in `control_bar.dart`). Adding it to
`pollProjectorTelemetry` makes changes done on the projector or by other software show up; it's
the 12th query per cycle, so check the poll cycle time on a large project. Unknown codes
(e.g. `32`–`34`, `52`, `80`–`83` — valid but not in the app's map) show a generic thumbnail
with the raw code in the tooltip. Transient telemetry → covered by
`_stripTransient`/`_mergeWithTelemetry`.

### Code
- `presentation/providers/identify_provider.dart` — `identify(Set<String> nodeIds)`,
  `identifyAll()`, `cancel()`; holds `Set<String> pulsing` for the card ring and a 5 s timer.
  Runs the flash sequence (`QTS` + `QSH` → `OSH:0` → `OTS:01`/`OTS:02` alternating → restore)
  through the group dispatch from §10; `identifyAll()` runs it node by node in `layoutOrder`.
  Cancel always restores.
- `presentation/providers/alignment_provider.dart` — state `{active, scope, focusedId,
  preset, focusedPattern, othersPattern (null = same as focused), showNeighbours,
  includeDiagonals, showAll, Set<String> manualNeighbours,
  Map<id, (shutter, pattern, fadeIn?, fadeOut?)> saved}`; `enter()`, `focus(id)`, `next()/prev()`,
  `toggleShowAll()`, `exit()`. Each projector's role is derived from state
  (`focused` / `neighbour` / `shown` / `closed`); on every change only projectors whose role
  changed get commands — not the whole wall. Show All off simply recomputes roles from
  `showNeighbours`, which gives the "return to the previous view" behaviour for free.
  Must not depend on widget state (focus nodes, `BuildContext`): the web API (§5) drives the
  same methods, and the banner reacts to state changes from either side.
- `lib/features/workspace/domain/card_layout.dart` — pure functions, unit-tested (§7.1):
  - `layoutOrder(nodes)` — sort by `y` then `x` with a row tolerance of half a card height.
  - `neighbours(node, nodes, {maxGap = 60, minOverlap = 0.5, diagonals})` — the gap/overlap
    rule above, card size taken from the shared 120×100 constants (currently duplicated in
    `projector_workspace.dart` and `workspace_provider.dart` — move them to one place).
    Unit tests: default auto-grid, staggered rows, wide gaps, single row, 1 card.
- Keyboard: `<` / `>` (`comma` / `period`, with or without Shift), `A`, `N`, `Shift+N`,
  `Ctrl+L`, `Esc` registered next to the existing `I`/`O`/`F` bindings; `<`/`>`/`A`/`Esc` are
  active only while `alignmentProvider.active`. Arrow keys are untouched (Lens Shift).
- Commands reuse `OSH:0/1` and `OTS:xx`; on entry the current state is read per projector
  for the restore: `QSH` (shutter), `QTS` (test pattern) and `QVX:SEFS1`/`SEFS2` (shutter
  fade; saved only when not `0.0`). Pending fade restores live in `appSettingsProvider`
  (`Map<nodeId, (fadeIn, fadeOut)>`), cleared per projector once restored.
- Banner widget in `projector_workspace.dart`'s Stack; focused card = primary ring, neighbours
  = dimmer secondary ring, Identify = pulsing ring.
- **Device-name overlay (later):** not in the PT-RQ35K2/RZ34K2 command list. If a Wireshark
  capture of VSS's *Show Device Name* shows an NTCONTROL command (it may use the web UI
  instead), add it to the skill and switch Identify / Identify All to "all at once, name on
  image". Until then: the flash method above.

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

Optional rules whose commands are confirmed in the PT-RQ35K2/RZ34K2 list but **not polled
today** (each would add a query to the poll cycle, so off by default and polled only when
enabled):
| Rule | Command | Trips when |
|---|---|---|
| Running on backup input | `QVX:BACI4` | `+00001` — the main signal failed and the projector switched to its backup input; the image may still look fine, so this is the one worth having |
| DIGITAL LINK lost | `QVX:DKSI1` | `+00000` (no link) on a projector whose input is `DL1` |
| Multi Projector Sync link | `QVX:MPSI2` | status changes away from the value seen when the rule was enabled |

Models that don't support a command answer `ERR1`/`ER401` → the rule is shown as
"not supported" for that projector instead of alerting.

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
  pick after a quick spike. New Dart dependencies in this roadmap: this one, plus `shelf` /
  `shelf_router` for F7 (§5).

---

## 5. `[ ]` F7 (reframed) — Local Web Monitor & HTTP API

### Why
Monitoring from any device on the show network — a phone at FOH, a laptop in the projection
booth — without installing anything.

### Access model (decided 2026-09-28: PIN is mandatory)
Two roles, each with its own PIN:
| Role | PIN | Can do |
|---|---|---|
| **Viewer** | Viewer PIN (always required) | Read status, alerts, live updates. The server rejects every `POST` from a viewer session with `403`, so hiding buttons isn't the only guard. |
| **Operator** | Operator PIN (exists only while *Allow control* is on) | Everything a viewer can, plus **power, shutter, test pattern, lens shift / focus / zoom / home**, cues, and **Alignment mode** (§3). Confirmation rules below. |

- One PIN field on the login page. The server checks which PIN matches and gives the session
  that role; the user doesn't pick a role.
- A viewer can press **Unlock control** and enter the operator PIN to upgrade the same session;
  **Lock** drops it back to viewer.
- The two PINs must differ (the settings tab refuses equal values). 4–8 digits.
- With *Allow control* off, only the Viewer PIN exists and the server has no write routes at all.
- **Sessions:** a successful PIN returns a random session token in an `HttpOnly` cookie
  (browsers) or in the JSON reply (scripts). It expires after 12 h idle. Changing either PIN
  or pressing *Sign out all clients* in the settings tab invalidates every session.
- **Brute force:** 5 wrong PINs from one IP → that IP is locked out for 60 s, doubling on each
  repeat; each lockout is logged in the Event Log.
- **Scripts / Companion / QLab:** `POST /api/login {"pin": "…"}` → token, then
  `Authorization: Bearer <token>`.
- Plain HTTP on the show LAN: the PIN crosses the network unencrypted. Acceptable on a
  closed show network; the settings tab says so in one line. HTTPS with a self-signed
  certificate only makes phones show warnings, so it's out of scope.

### UX
- **Preferences → "Web Access" tab:** *Enable* switch, port (default 8080), **Viewer PIN**,
  *Allow control* switch → **Operator PIN**, *Sign out all clients*, connected clients list
  (IP, role, last seen), and the URL + **QR code** (`http://<this-machine-ip>:8080`) for phones.
- **Web page** (served by the app, responsive). Mockup: artifact *Projector Grid Web Monitor*
  (https://claude.ai/artifact/W5t59BABLdayaHUmaVkZu5). It has desktop and phone views, a
  Viewer/Operator switch and a With/No groups switch.
  - Login: PIN pad on phones, single field on desktop; shows the project name.
  - Top bar: project name, online / offline / warnings counts, live indicator, role chip
    (*Viewer* / *Operator*), *Unlock control* / *Lock*; operator also gets **Alignment**.

#### Layout with and without groups
- **With groups:** one section per group (name, count, *Select* for operators), projectors in
  layout order inside each; ungrouped projectors go in a final *Ungrouped* section.
- **No groups** (project without groups): a single **All projectors** section in layout order
  (left→right, top→bottom, same `layoutOrder` as §3), with *Select all*. Same columns, no
  group headers; everything else is identical, so it isn't a separate page mode — just the
  list rendered without sections when `/api/groups` is empty.

#### Status colours — same rules as the app
Taken from `projector_card.dart` / `monitoring_table.dart` so the web and the app read the same:
| Field | Rule |
|---|---|
| Connection dot | green online / unprotected, amber auth error (+ lock icon), red offline |
| Power | power icon + label: green **ON**, red **STANDBY**, amber **TURNING ON** / **COOLING** |
| Shutter | eye icon + label: green **OPEN**, red **CLOSED** |
| Errors | green check **NO ERRORS**; red error icon + the error text; card/phone shows the orange warning triangle like the app card header |
| Intake temp | amber ≥ 40 °C, red ≥ 45 °C (`_intakeWarmC` / `_intakeHotC`) |
| Exhaust temp | amber ≥ 55 °C, red ≥ 65 °C (`_exhaustWarmC` / `_exhaustHotC`) |
| Signal | plain text, like the app's table (`NO SIGNAL` isn't tinted there) |
| Test pattern | mini swatch + name when a pattern is on **and** the shutter is open (§3.3) |
| Group | group colour dot + name (`_groupCell`) |
The thresholds are served by the API (`/api/config`), not hard-coded in the page, so a later
change in the app (or the §4 alert thresholds) applies to both.

#### Desktop layout
Header (project, status filters *All / Online / Offline / Warnings* with counts — clicking one
filters the table, live indicator, *Alignment* for operators, role + *Unlock control* / *Lock*)
→ toolbar (selection, search by name / IP / serial, "N of M shown", **Columns**) → table.

#### Table — the app's Monitoring table, feature for feature
The web table is a port of `monitoring_table.dart`, not a simplified list. **Same columns, same
ids, labels, default widths and canonical order** (the `_allColumns` descriptors, served by
`/api/config` so the two can't drift):

- **All columns:** Connection, Name, Serial Number, Group, IP Address, Power, Shutter,
  Input, Signal, Test Pattern (new, from §3.3), Projector Runtime, Light Runtime,
  Intake Temp, Exhaust Temp, AC Voltage, Errors.
- **Default visible:** the app's `_defaultVisibleIds`, i.e. all of the above except Group and
  Test Pattern.

The app's `model` column shows `node.name` but is labelled "Model". The web labels it
**Name**. Worth renaming in the app too (label only, the id stays `model` so saved layouts
keep working).

| App feature | Web |
|---|---|
| Show / hide columns (View ▸ Monitoring Table), last column can't be hidden, re-shown column returns to its canonical slot (`toggledColumn`) | **Columns** popover: checklist, same rules |
| Presets *Essentials / Thermal / Signal / Show all* | Preset buttons in the popover + *Reset* |
| Click header to sort, again to reverse; default `ip` ascending | Same; arrow on the sorted header, `aria-sort` |
| Drag a header to reorder | Drag headers (drop marker left/right); also drag in the popover list |
| Drag a header's right edge to resize; double-click it to auto-fit | Same; the edge shows a hairline on hover. Auto-fit measures the widest cell, like `onAutoFit` |
| Fit to width (`monitoringFitToWidth`), with the `_resizeBaseFor` maths so a resized column lands where dragged | Same switch and the same formula; floor 60 px (`_minColWidth`); sideways scroll only when floors push past the viewport |
| Density compact / standard / comfortable (row 32 / 40 / 52 px) | Same three options |
| Group-by (`monitoringGroupBy`); the Group column is hidden while grouping | Same switch (disabled when the project has no groups); collapsible group sections with an online / warnings / offline summary |

- **Where the layout is saved:** per browser (`localStorage`), not in the app's settings, so a
  phone and a booth laptop can differ. The first visit starts from the app's current layout
  (`monitoringColumns`, widths, sort, density, fit, group-by from `/api/config`).
- **Pinned columns:** the selection column and the first visible column stay pinned when the
  table scrolls sideways.
- **Operator width:** in operator mode the control panel takes 340 px. With all 14 default
  columns the table then hits the 60 px floors, the same as the app in a narrow window;
  *Essentials* fits cleanly.
- **Phone:** cards show a fixed summary (power, shutter, signal, temps, errors). Tapping a card
  expands it to every field (IP, serial, runtimes, voltage, test pattern, group).

**Alerts on request:** a 52 px **rail** at the far right, for both roles:
- a bell with the active count, coloured by the worst severity;
- one tick per alert in its severity colour.

Clicking it opens a 360 px **drawer over the content**, not a new column, so the table and
control panel don't reflow. Each card shows projector, rule, detail, *since*, and
*Acknowledge* (operator only). The open/closed choice is kept per browser in `localStorage`.
Phone: bell in the top bar plus an "N active alerts" pill → alerts bottom sheet.

#### Control (operator)
- **Target = selection**, like the app's control bar. Offline projectors can't be selected.
  - **Select all:** tri-state checkbox in the toolbar (selects every visible row, so it
    respects the filter/search), `Ctrl+A`.
  - **Group:** tri-state checkbox on each group row.
  - **Select ▾ menu:** All projectors, All online, Only with warnings, Invert, one entry per
    group, Clear (`Esc`).
  - **Rows:** click toggles, **Shift-click** selects a range.
  - **Phone:** a *Select all* bar above the list, a checkbox per group header, tap cards;
    bottom bar *"N selected · Clear · Control"*.
- **Desktop:** right-hand **Control** panel (340 px). Header: just *Control* + "N selected".
  No name chips or empty-state text, because the selection is already visible in the table.
  With nothing selected the controls are shown disabled, like the app's control bar. Blocks
  top to bottom, in the control bar's order:
  - *Power* On / Standby
  - *Shutter* Open / Close
  - *Test pattern* — full-width *Off*, then a 4-column swatch grid (White, Black, Red, Green,
    Blue, Cross Hatch, CH Red / Green / Blue, Colour bars, Window, Circle), *More patterns*
    expands the rest of `_testPatternOptions`; the current pattern is highlighted when one
    projector is selected
  - *Lens* — **one column**: "moves N lenses" warning (when N > 1) → speed Slow / Normal /
    Fast → shift D-pad → *Home position* → Focus −/+ → Zoom −/+. Same `VXX:LNSI2…5` commands
    as the control bar; holding a button repeats with the control bar's throttle.
- **Phone:** *Control* opens a bottom sheet with the same blocks.
- **Confirmation:** power always; shutter and test pattern only when more than one projector
  is targeted; lens steps never (a dialog per nudge would make the lens unusable); Lens Home
  always. Destructive confirms (power off, shutter close) use a red button.
- After a command: a toast with the §10 result summary (*"Shutter Close — Stage 4/4 OK"*).
- Every web command is logged in the Event Log with its source, e.g. *"Web · 192.168.0.77 ·
  Operator"*.

#### Alignment mode on the web
It is **the app's** Alignment mode (§3), driven remotely — not a second implementation.
`alignmentProvider` stays the single source of truth; the web page shows its state via SSE and
sends actions to it. Entering from the phone shows the banner in the app too, and vice versa.
Only one alignment session exists at a time; a second client entering joins the same session.
- **Desktop:** the app's banner across the page, in one row: *◀ name n of N ▶ · Neighbours ·
  Show all · Identify · Preset [Geometry | Blend | Color | Custom] · Focused ▾ · Others ▾ ·
  Exit*.
  - The presets are the app's §3.2 table, including **Custom**.
  - *Focused ▾* / *Others ▾* open a swatch popover filtered by the preset: Geometry → cross
    hatches, Blend / Color → solid colours, **Custom → every test pattern**. *Others* also has
    *Same as focused*.
  - Picking a pattern keeps the preset; switching to Custom keeps the current patterns. Same
    rules as the app's *Presets ▾* popover. The web has room to put the pickers inline, so it
    doesn't need the popover.
  - The first table column shows a role marker instead of the checkbox (focused = filled,
    neighbour = ring, shown = light ring), with a legend in the toolbar.
  - Shutter-closed rows are dimmed; clicking a row focuses it; `,` / `.` step.
  - The control panel becomes *Lens · PJ-xx*, acting on the focused projector only.
- **Viewer during alignment:** the session is shared, so a viewer sees a read-only banner
  (*"Alignment in progress · PJ-03 focused · 3 of 7 · Geometry — controlled by an
  operator"*) and the role markers, but no controls. Row clicks do nothing.
- **Phone** (the main use case — walking the room with a phone):
  - big ◀ ▶ with the focused name and *n / total*;
  - Neighbours / Show All / Identify toggles;
  - a **wall mini-map** built from the card layout — focused filled, neighbours outlined,
    offline dashed; tap a tile to focus it;
  - preset switch (Geometry / Blend / Color / **Custom**) and *Focused* / *Others* rows that
    open a bottom sheet with the filtered swatch grid;
  - the lens block for the focused projector.
- *Adjust ▾* (geometry / colour dialogs) stays app-only.
- Exit from the web restores shutters, patterns and shutter fades exactly like Exit in the app.

- The app shows a small "Web access on · 3 clients (1 operator)" indicator in the status bar.
- Live updates via **Server-Sent Events** (simpler than WebSocket, auto-reconnect in browsers).

### API (same server)
| Method | Path | |
|---|---|---|
| POST | `/api/login` | `{ "pin": "…" }` → session token + role; no auth needed |
| POST | `/api/logout` | ends the session |
| GET | `/api/config` | project name, role, status-colour thresholds, test-pattern list |
| GET | `/api/projectors` | all nodes + telemetry, in layout order (JSON) |
| GET | `/api/projectors/{id}` | one node |
| GET | `/api/groups` | groups (empty array → the page shows the flat list) |
| GET | `/api/alerts` | active alerts |
| GET | `/api/alignment` | alignment state: active, focused, roles, preset, toggles |
| GET | `/api/events` | SSE stream: node changes, alerts, alignment state, command results |
| POST | `/api/actions` | `{ "targets": [ids] \| {"group": id} \| "all", "action": … }` — see below |
| POST | `/api/cues/{id}/fire` | fire a cue |
| POST | `/api/alignment/{op}` | `enter`, `exit`, `next`, `prev`, `focus/{id}`, `neighbours`, `showAll`, `identify`, `preset/{name}` |

All `POST`s except `/api/login` need an operator session.

**Typed actions instead of raw commands.** `/api/actions` takes a small fixed vocabulary,
which the server maps to NTCONTROL, so the web can't send arbitrary commands (e.g.
`VXX:RSTS1=…` — factory reset):
| `action` | Maps to |
|---|---|
| `{"power": "on" \| "off"}` | `PON` / `POF` |
| `{"shutter": "open" \| "close"}` | `OSH:0` / `OSH:1` |
| `{"testPattern": "07"}` | `OTS:07` — code must be in the app's pattern list |
| `{"lens": "shiftH" \| "shiftV" \| "focus" \| "zoom", "dir": "+" \| "-", "speed": "slow" \| "normal" \| "fast"}` | `VXX:LNSI2…5=+SSSSSD` (same encoding as the control bar) |
| `{"lens": "home"}` | `VXX:LNSI1=+00001` |
The reply is the §10 `DispatchResult` (ok / failed / skipped offline).

Useful beyond the web page: Companion, QLab, custom scripts can poll or drive the app over HTTP.

### Code
- **Web page: Svelte 5 + Vite + TypeScript** single-page app in `web_ui/`, built into
  `assets/web/` and bundled with the app (decided 2026-09-28). The stack, repo layout, dev
  commands, API-contract rules, CI and build order are in **`WEB_UI_PLAN.md`**.
- `lib/core/services/web_server_service.dart` — `shelf` + `shelf_router`, bound with
  `InternetAddress.anyIPv4`. Serves the built page from `rootBundle` (`assets/web/`), the
  `/api/*` routes and SSE. Transport-only, like `osc_service.dart`.
- `presentation/providers/web_server_provider.dart` (`keepAlive`) — lifecycle from settings,
  pushes SSE events from `ref.listen(workspaceProvider)` / alerts / cues / `alignmentProvider`.
  Routes call the same notifiers the UI uses: `WorkspaceNotifier.dispatchCommand` (§10) for
  actions, `alignmentProvider` for alignment. No command logic lives in the server.
- `lib/core/services/web_actions.dart` — pure mapping `WebAction → NTCONTROL string` (the
  table above), unit-tested (§7.1). The lens encoding is shared with `control_bar.dart` so the
  two can't drift.
- The Monitoring column catalogue (id, label, default width, canonical order, default set,
  presets) moves out of `_MonitoringTableState` statics into a plain-Dart
  `domain/monitoring_columns.dart`, which both the table and `/api/config` read. Cell rendering
  stays per side (Flutter widgets vs. the page's JS), keyed by column id.
- Status-colour thresholds move from `monitoring_table.dart` statics into one shared place
  (e.g. `core/theme/status_thresholds.dart`) that both the table and `/api/config` read.
- Lens hold-to-repeat: the page sends one action per repeat tick; the server applies the same
  per-projector throttle as `_throttledSend`, so a laggy phone can't queue up a burst.
- Security: bind on all interfaces only when enabled; sessions and PIN checks as in *Access
  model* above; *Allow control* off by default; PINs stored as salted hashes in app settings
  (not plain text); firewall prompt on Windows on first bind — document it.
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

## 7. `[~]` R6 — Pre-release Test Suite

**Status (2026-09-29):** the suite is in place — 169 passing, 1 skipped (a known bug), up from
one smoke test. Committed in `8a33ebc` (tests, refactors, CI) and `5c57b1e` (`dart format lib`).
Open items are listed in §7.5.

Layout: `test/unit/` (pure logic), `test/providers/` (Riverpod), `test/widgets/`, shared fakes
in `test/helpers/`:
- `fake_protocol_service.dart` — scriptable `PanasonicProtocolService`, never opens a socket.
- `fake_projector_server.dart` — loopback NTCONTROL server, used only by the protocol tests.
- `test_config_dir.dart` — points `appConfigFilePath` at a temp dir via
  `debugAppConfigDirOverride`. **Every test that builds a provider or the app must call
  `useTempConfigDir()`** — the old smoke test read and could overwrite the real user's
  `app_settings.json`.
- `provider_harness.dart` / `app_harness.dart` — container / full-app setup with the fake
  service and a mocked `window_manager` channel.

Refactors done first (behaviour unchanged):
- `protocolServiceProvider` (`presentation/providers/protocol_service_provider.dart`);
  `workspaceProvider` and the Geometry dialog read the service from it.
- Pure functions extracted: `domain/telemetry_parsing.dart`, `domain/geometry_values.dart`
  (formatters, `parseKeyed*`, `quadPixelTierFor`, corner canvas maths and limits),
  `domain/schedule_due.dart` (`isTaskDue`).
- `OscService.processMessage` (`@visibleForTesting`) routes a message without a socket.

### 7.1 `[x]` Unit tests — pure logic
- `[x]` Protocol: `00` stripping (incl. model names containing `00`), MD5 prefix (known
  answer), failure vs transport-failure classification, `pollProjectorTelemetry`
  online/unprotected/unauthorized/offline — against the loopback fake projector.
- `[x]` Telemetry parsing: runtime, light runtime, errors, voltage, temperature, signal, power,
  input labels, fallback to the last known value.
- `[x]` Geometry formatters and `parseKeyedValue` with and without `KEY=`.
- `[ ]` Edge Blending `f4` / RGBW tuple formatters — once Edge Blending exists.
- `[x]` Corner Correction maths: round-trip on standard and Tier A, canvas bounds land exactly
  on the protocol limits.
- `[x]` Model tiers: `PT-RQ35K`/`KL`/`K2` → A, `PT-RQ32K` → B, unrelated → none.
- `[x]` `commandLabel` for every control-bar command. **Found and fixed:** partial lens
  calibration (`VXX:LNSI0=+000xx`) logged the raw command.
- `[x]` OSC: address routing, rate limit, custom slugs, codec round-trip, outbound status
  change detection.
- `[x]` Scheduler: once/daily/weekly, missed run, same-minute guard. DST spring-forward
  regression test is written but **skipped** until `IMPROVEMENT_PLAN.md` item 10 is fixed.

### 7.2 `[x]` Provider tests
- `[x]` `workspaceProvider`: add/delete/move, groups, undo/redo, **undo keeps live telemetry**.
- `[x]` Optimistic updates: shutter flips, failures leave state untouched, `PON`/`POF`
  transition then settle on what `QVX:POWI1` reports (a `PON` that didn't take reverts).
- `[x]` Polling: telemetry parsing, per-field fallback, "Went offline" / "Authentication
  failed" / hardware error logged once, no overlapping poll cycles.
- `[x]` "Came online". **Found and fixed:** a projector coming back via the normal poll cycle
  was never logged (`_checkAndSetNodeStatus` flipped it to connected before polling). Now
  logged on return and after an edit; the first check of a newly added projector stays quiet.
- `[x]` `projectStateProvider`: v2 open/save round-trip, telemetry never persisted, dirty flag,
  recent list (newest first, deduped, capped at 10, missing files dropped), corrupt file,
  500-node cap.
- `[ ]` Project file v3 round-trip — once cues (§2) land.
- `[x]` `statusSummaryProvider`, `eventLogProvider` (500 cap), `customCommandsProvider`
  (slug clashes, persistence, malformed entry dropped).

### 7.3 `[x]` Widget tests
- `[x]` Card context menu: every item present and wired. `[ ]` Add Edge Blending once it exists.
- `[x]` Geometry dialog: loads mode, mode switch sends `VXX:GMMI0=…`, QPD auto-enable only
  from Off, failed write shows the notice.
- `[x]` `SleekStepperInput`: Enter/blur commit, clamp, step snapping, invalid text reverts,
  buttons and hold-to-repeat.
- `[x]` Ctrl+A after Controls ↔ Monitoring (verified to fail if `_requestViewFocus` is removed).
- `[x]` Window close: clean closes, dirty asks, Cancel keeps, Discard closes.

### 7.4 `[~]` Release gate (CI)
- `[x]` `.github/workflows/ci.yml` on Windows + macOS: `build_runner` →
  `dart format --set-exit-if-changed lib test` → `flutter analyze lib test` →
  `flutter test --coverage`. Scoped to `lib/` and `test/` because `tool/` scripts aren't held
  to the lint/format rules (see CLAUDE.md).
- `[ ]` Block merges to `main`: enable branch protection with the CI check required — a
  GitHub repo setting, not a file.

### 7.5 Open items
- `[ ]` Fix the DST spring-forward bug (`IMPROVEMENT_PLAN.md` item 10), then unskip its test.
- `[ ]` Branch protection on `main` (§7.4).
- `[ ]` Edge Blending and project v3 tests as those features land.
- `[ ]` Custom-command ids are `microsecondsSinceEpoch`; Windows' clock is coarse enough that
  two adds in the same tick share an id. Unreachable at human click speed — fix only if
  commands are ever created programmatically.

Note: on the dev laptop `flutter_tester.exe` sometimes dies with the same Dart VM profiler
access violation as the debug app (`debug_crash_investigation.md`). A run then shows a batch of
"did not complete" tests with no error text. Rerun, or use `flutter test --concurrency=1`.

---

## 8. `[x]` U1 — Light Theme Fix in Dialogs

Hard-coded dark-only colours make dialog labels and inputs nearly invisible in the light theme:
- `geometry_correction_dialog.dart` — labels use `Colors.white70` (`_sliderRow`,
  `_labeledSlider`, `_throwRatioField`).
- `sleek_stepper_input.dart` — fill `Colors.white.withValues(alpha: 0.06)`, borders/dividers
  `Colors.white.withValues(alpha: 0.1)`, focus `Colors.blueAccent`.

Fix: `colorScheme.onSurfaceVariant` for labels; `onSurface` at 6 % / `outlineVariant` for the
stepper fill/borders; `colorScheme.primary` at 50 % for focus. Grep the rest of `lib/` for
`Colors.white` / `Colors.black` used as text/border colours and fix the same way. Verify with
the `flutter-windows-gui-check` skill in both themes.

**Done:** also fixed the Add Projector scan spinner (`onPrimary`) and the Kelvin slider
overlay (`onSurface` 12 %). Remaining `Colors.white/black` uses are intentional: shadows,
contrast text on group colours, the Remote Preview's always-black viewport, corner-handle
rings and the Kelvin thumb drawn over the gradient.

---

## 9. `[x]` U2 — Shared Dialog Widgets

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

**Done:** all four in `presentation/widgets/common/`; Geometry, Color and Brightness migrated.
`LabeledSliderRow` has `above`/`inline` layouts and a `snap` flag (the Corner sliders are
continuous). `ProjectorSettingsClient` also has `queryAll` (batches of 8) and `writeBool`;
it uses raw key strings for now — switch to the §1 registry when F1 lands. Color and
Brightness now take the service from `protocolServiceProvider` instead of `new`-ing one.
Brightness keeps its own `_PercentSlider` (no stepper, % readout).

---

## 10. `[x]` U3 — Group Command Result Summary

Today `_dispatchToNodes` logs one event per node and returns nothing; on a 30-projector
"Power On" the user can't tell at a glance whether everything worked.

- `_dispatchToNodes` (and `sendCommandToSelected/Group/All`) return
  `DispatchResult { command; int ok; List<ProjectorNode> failed; List<ProjectorNode> skipped; }`
  (`domain/dispatch_result.dart`); `skipped` = not connected (offline or unauthorized).
- After a group/all/selection command, one **summary entry in the Event Log** (via
  `eventLogProvider`, no SnackBar): *"Power On — 28/30 OK · 2 failed · 1 skipped. Failed: A, B.
  Skipped: C"* (`dispatchSummary`). Severity is `info` when all succeeded, `warning` when
  anything failed or was skipped, so it stands out in the log panel.
- The per-node entries stay; the summary line is appended after the last node has replied.
- Single-projector commands keep today's behaviour (no summary line) — decided by the
  target count (> 1), so a one-projector group also stays quiet.
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
- ~~Command strings for lens memory, current test pattern query, device-name OSD~~ —
  resolved 2026-09-28 from the PT-RQ35K2/RZ34K2 command list: lens memory `VXX:LNMI1/2/3`
  (no read-back — F1 backs up the absolute lens position instead), test pattern query `QTS`,
  no device-name OSD command (F4 Identify uses the test-pattern flash).
- ~~Go / no-go on zeroing shutter fade in Alignment mode~~ — decided 2026-09-28: always zero
  it while in the mode, only where it isn't already 0, and restore on Exit (§3.2).
- Live-unit checks: `QVX:LNSI7`…`LNSIA` reply format and absolute write (F1); whether `STS`
  shows the projector name on the image (F4).
- Alert default thresholds per model family, if the defaults in §4 don't fit.
- Go / no-go on §6 (error handler + log file).
