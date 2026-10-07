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
| F4 | Alignment mode (solo / identify) | **Accepted** → §3, `[~]` Alignment mode + test-pattern indicator done; Identify `[later]` | "Very useful" |
| F5 | Telemetry alerts | **Accepted** → §4 | |
| F5b | Extra alert rules (backup input, DIGITAL LINK, Multi Projector Sync) | `[later]` → §4b | Split out of F5: each adds a query to the poll cycle, which F5 leaves unchanged |
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

## 3. `[~]` F4 — Alignment Mode (Solo / Identify)

**Status (2026-09-29):** Alignment mode (§3.2) and the test-pattern indicator (§3.3) are
implemented; **Identify (§3.1) is `[later]`** — the flash-by-test-pattern method is not
settled, the owner decides after tests on a real projector. So the banner has no *Identify*
button and Identify has no shortcut yet (`N` went to Neighbours, see below).

Done:
- **Test-pattern indicator (§3.3)** — `QTS` is the 12th poll query; `ProjectorNode.testPattern`
  is polled and set optimistically on every `OTS:xx`; card thumbnail on the IP row (any
  shutter state, no tooltip); opt-in *Test Pattern* column (icon + name) in Monitoring. Pattern list and
  icons shared in `domain/test_patterns.dart`.
- **Alignment mode (§3.2)** — `alignment_provider.dart` (state, entry capture of shutter /
  pattern / fade, per-projector command loops, restore on exit, pending fade restores in app
  settings), `alignment_banner.dart`, card rings and dimming in `projector_card.dart`,
  shortcuts in `projector_workspace.dart`, toolbar button, *Tools → Alignment Mode*, Keyboard
  Shortcuts section. Pure rules in `domain/alignment.dart` (presets, roles, commands) and
  `domain/card_layout.dart` (`layoutOrder`, `neighbours`; card size constants now live here).
- **Tests** — `test/unit/alignment_test.dart`, `test/unit/card_layout_test.dart`,
  `test/providers/alignment_provider_test.dart` (entry/exit, navigation, fades, rapid
  presses, a hung projector), test-pattern polling in `workspace_provider_test.dart`.
- **`tool/projector_simulator.dart`** — loopback projectors + a matching `.pgrid`, used to
  test the mode without hardware (see `DEVELOPMENT.md`).
- Commits `9e1e13e`, `a0f70ca`, `f5df3ea`, `8b36ccc` (feature), `62adcbe` (simulator).

Deviations from the design below:
- **Scope** = the selection when 2+ cards are selected (e.g. a group via `Ctrl+G`), otherwise
  all projectors. The banner doesn't name the scope or group (owner, 2026-09-29).
  Offline / not-answering projectors are left out on entry.
- **`N` toggles Neighbours** (owner asked for a shortcut, 2026-09-29), so Identify needs a
  different key when it is designed. The banner row starts with the mode icon only (no
  "Alignment —" label) and shows no projector name (the ring on the card marks the focused
  one). Order: icon · ◀ `n/N` ▶ · Neighbours · Show All · Presets ▾ · Adjust ▾ · Exit.
  A grouped card's group chip always sits below the ring width (in and out of the mode), so
  it never covers a ring and doesn't jump. Neighbours / Show All are plain text buttons like
  Presets / Adjust; when on they become a solid dark pill with orange text (same font weight,
  so turning one on doesn't widen it). No shortcut hints in the banner or its tooltips.
- **Selection is pinned to the focused projector** while the mode is on (a click on empty
  canvas, `Ctrl+D`, `Ctrl+A` or a marquee snaps back), so the control bar always acts on it.
- **No Blend preset** (owner, 2026-09-29): it was identical to Color, so the presets are
  Geometry / Color / Custom.
- **Presets ▾** is a menu with *Preset / Focused / Others* submenus and a *Diagonal neighbours*
  check item, not a popover with dropdowns (dropdown routes inside a menu overlay close it).
- Commands go out through **one loop per projector**: each loop re-reads the target before
  every command, so rapid `<` / `>` presses only move the target (a projector passed through
  gets at most one command, never an open shutter), commands on one projector never
  interleave, and a projector that stopped answering (~9 s send timeout) doesn't hold up the
  others.
- `Ctrl+L` also lives in *Tools → Alignment Mode*; quitting the app while the mode is on runs
  Exit first (5 s cap) before closing.

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
  | **Color** | all solid colours: `OTS:01` white, `02` black, `22` red, `23` green, `24` blue, `28` cyan, `29` magenta, `30` yellow | White `01` | Same as focused | Colour/brightness matching and checking the blend seam |
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
  | **≥ 900 px** | Toggles as labelled pills (*Neighbours*, *Show All*); Exit as *Exit* |
  | **600–900 px** | Toggles become **icon buttons** with tooltips (filled when on); Exit as *Exit* |
  | **< 600 px** (min window) | Icon toggles; name truncated with ellipsis; Exit as an icon |
  Name, ◀ ▶, Presets ▾, Adjust ▾ and Exit are never hidden. Every icon-only control keeps a
  tooltip with its name only — no shortcut hints in the banner (owner, 2026-09-29).
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
  - With the **Color** preset (or *Same as focused*) every open projector shows the
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
  - Neighbour cards get a thinner highlight ring in the workspace.
- **Show All** (banner toggle, shortcut **`A`**) — a temporary overview of the whole wall:
  - On: opens the shutters of **every** projector in scope. The focused projector keeps the
    *Focused* pattern; all others show the *Others* pattern (with the Geometry preset the
    focused one still stands out; with Color everyone shows the same field).
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
- Shown whenever a test pattern is active (`OTS` ≠ `00`), **whatever the shutter** — the
  pattern stays set on the projector and is on screen as soon as the shutter opens (owner,
  2026-09-30; first shipped as open-shutter-only). Normal show cards look exactly as today.
- No tooltip on the thumbnail (owner, 2026-09-30).
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
- Banner widget above the canvas. Mode colour is an orange accent (`AppTheme.alignmentAccent`),
  opposite the blue selection colour. Focused card = 3 px orange ring with a 2 px gap and a
  glow (replaces the selection border), neighbours = 2 px ring in a paler peach tone
  (`AppTheme.alignmentNeighbour`), cards the mode keeps closed are dimmed by an opaque scrim —
  not opacity, which let the canvas grid show through (owner feedback 2026-09-29: the first, tertiary-colour rings
  merged with the selection border and neighbours were hard to see).
- **Device-name overlay (later):** not in the PT-RQ35K2/RZ34K2 command list. If a Wireshark
  capture of VSS's *Show Device Name* shows an NTCONTROL command (it may use the web UI
  instead), add it to the skill and switch Identify / Identify All to "all at once, name on
  image". Until then: the flash method above.

---

## 4. `[ ]` F5 — Telemetry Alerts

### Why
The app polls temperatures, runtime, light-source hours and `QVX:ERRS2` errors already, but
only shows them. Nobody watches a table all night.

Design approved 2026-10-01 from the mockup at
https://claude.ai/artifact/EaTfnLYHzBuejNci3MkTd5 (card badge, alert panel, status-bar list).

### Alert rules
Every rule has its own on/off switch. There is no global "armed" switch: during setup the
operator turns off the rules that would be noise (Signal lost above all) and turns them back
on for the show.

| Rule | Severity | Trips when | Source |
|---|---|---|---|
| Offline | critical | the first poll that gets no answer (the moment `connectionStatus` turns `offline`); no poll-count setting | `connectionStatus` |
| Projector error | critical | `errors` changes away from `NO ERRORS`; one alert per reported error | `QVX:ERRS2` |
| Signal lost | critical | powered on, a signal was seen since power-on, then it is gone; **no debounce**, every dropout counts | see spike below |
| Intake temperature | warning at *warm*, critical at *hot* | thresholds shared with the Monitoring table tint (`AlertSettings.intake`, default 40 / 45 °C) | `QTM:0` |
| Exhaust temperature | warning at *warm*, critical at *hot* | same, `AlertSettings.exhaust` (default 55 / 65 °C) | `QTM:1` |

Signal lost details:
- Armed only after the projector has shown a signal once since power-on, so powering up
  before the source is ready doesn't raise it. Disarmed in standby / cooling, and for ~10 s
  after the app itself switches the input.
- Latched: if the signal comes back, the alert stays (shown as "Back after 3 s") until
  acknowledged, so a short dropout can't flash by unseen.
- The shutter is not part of the condition.

Thresholds have hysteresis (clear only 2 °C below the threshold) so values hovering near the
limit don't flap.

### Alert lifecycle
- **Raised** → unacknowledged. **Acknowledge** → stays listed while the condition holds, shown
  quieter. **Cleared** when the condition clears (a latched Signal lost clears on acknowledge).
- At most one active alert per (projector, rule), per error item for Projector error, so the
  active list is bounded by the project size and never accumulates. History lives in the
  event log.
- Not persisted: after a restart the active list is rebuilt from the first poll; conditions
  that still hold come back as new and unacknowledged, with "since" counted from that poll.

### Spike before implementation: signal-loss detection via Remote Preview `[x]`
The regular poll (30 s minimum, 60 s default) misses short signal dropouts
between polls, and the "No signal" rule is meant to catch even short ones (no debounce). The
RemoView WebSocket (`remote_preview_service.dart`) pushes `SIGNAL` / `NOSIGNAL` text events the
moment the input changes, so it can detect every dropout without polling. Test on hardware:
- Does the socket keep delivering `SIGNAL` / `NOSIGNAL` if the app never answers frames with
  `receive` (hypothesis: frames are ack-paced, so skipping `receive` stops the ~1 fps JPEG
  stream and leaves only text events)? Measure traffic per projector either way.
- How many simultaneous RemoView sessions a projector accepts, and whether a background
  session blocks the projector's own web UI preview or the app's Remote Preview dialog.
- Behaviour on input switch, standby → on and reboot (`CLOSE` / `IMPOSSIBLE`): reconnect
  timing and whether events are lost in between.

- If the socket stays open, check how fast `onDone` / `onError` fires when the projector's
  network cable is pulled: that would also make the Offline alert near-instant instead of
  waiting for the next poll.

Outcome decides the source for the signal rule: RemoView events if the socket can stay open
cheaply on every projector, otherwise a dedicated signal-only NTCONTROL poll (2–5 s, powered-on
projectors only, only while the rule is enabled).

**Results** (PT-RQ35K at 192.168.0.8, HDMI 1 at 3840x2160/50p, 2026-10-05):
- Skipping `receive` changes nothing: frames keep coming at 1 fps. The projector's own
  `preview.cgi` sends only `start`, `alive`, `PONG`, `receive`, `preshow:1/0`; there is no
  message that stops frames, so a background socket always carries the JPEG stream:
  ~3 KB/s on a static dark source, ~15 KB/s on real content (~120 kbit/s per projector).
- **Two RemoView sessions per projector, shared by the whole network.** The third
  `WebSocket.connect` gets HTTP 500; with a phone holding one preview, this PC got only
  one. A slot frees the moment its socket closes. The projector's web page shows a black
  preview, no error, when refused. The app's dialog and its Web Access page share one
  socket (`remotePreviewProvider`), so they take one slot together. A background socket
  per projector would leave one slot for either one device on the projector's web UI or a
  second Projector Grid, not both.
- Input switch and standby ↔ on: the socket stays open, no `CLOSE`. In standby it goes
  silent (no frames, no `NOSIGNAL`); after `PON` the first events come ~10 s later.
- Real dropouts (HDMI cable pulled for ~1 s, ~1 s and ~5 s): the socket sends `SIGNAL` +
  `NOSIGNAL` within ~0.2 s of the pull; `SIGNAL` itself only means "changed", the state
  comes from `simple_status_hidden.cgi` (50–150 ms, occasionally a failed fetch mid-change).
  A pull of ~1 s still gives **~3.5–4 s without signal** (the projector needs ~3 s to
  re-lock), the 5 s pull 6.5 s.
- `QVX:NSGS1` polled every 1 s caught every dropout: `ER401` for ~1–2 s while the input
  re-syncs, then `NSGS1=NO SIGNAL`, then the signal name. ~10–20 ms per query on the LAN.
  `ER401` also appears in standby and right after an input switch.
- Network cable pulled for ~25 s: the socket closed with 1006 within a second (the poll's
  first timeout came 4 s later). It does not reconnect by itself.

**Decision input:** a background socket per projector would hold one of the two network-wide
preview slots and stream ~15 KB/s of JPEG it doesn't need. Recommended: the dedicated
NTCONTROL poll (~0.5 KB/s, one short connection per 2 s, skipped while the projector's
regular poll, power tracking or a user command is in flight so it never adds a 4th
connection), `QVX:NSGS1` every 2 s (shorter than the shortest real
dropout, ~3.5 s), counting both `NO SIGNAL` and `ER401` as no signal, with the arming rules
above covering standby and app-made input switches.

**Decided 2026-10-05:** the dedicated `QVX:NSGS1` poll. Plan below.

### Signal watch: implementation plan `[~]`
Must hold up with **150 projectors** in a project.

**Measured on hardware (2026-10-05, PT-RQ35K):**
- The projector closes the NTCONTROL connection itself ~1 ms after the reply; a second
  command on the same socket gets nothing. One connection per query stays.
- With the current `_sendSingleCommandEx` (destroys the socket right after the reply)
  ~5 of 20 connections still ended in TIME_WAIT on our side (we won the close race);
  waiting for the projector's FIN first left none. Windows: 16,384 ephemeral ports,
  TIME_WAIT ~120 s by default.

**Budget at 150 projectors, all on:**
| | Value |
|---|---|
| Signal queries | 75 / s (one every ~13 ms), ~1 KB each → ~75 KB/s (~0.6 Mbit/s) |
| Sockets in flight | 1–2 typical (10–20 ms per query), capped at 16 |
| Per projector | one connection per 2 s, busy ~1% of the time |
| Regular poll alongside (60 s) | 150 × 13 = 1,950 connections per cycle, ~33 / s average |
| Our TIME_WAIT | ~0 with the FIN wait; without it up to ~25% of ~108 / s × 120 s ≈ 3,200 ports |

**Pieces:**
1. **Protocol** (`panasonic_protocol_service.dart`):
   - `_sendSingleCommandEx`: after the reply, wait up to 200 ms for the projector to close
     (`onDone`) before `destroy()`, so TIME_WAIT lands on the projector, which closes
     first anyway. Applies to every command, which also helps the regular poll.
   - `querySignal(ip, port, login, password)`: `QVX:NSGS1` with short timeouts (connect
     1.5 s, reply 1.5 s instead of 4 + 5 s) so a dead projector can't hold a slot for 9 s.
2. **Pure logic** (`domain/signal_watch.dart`, unit-tested):
   - `parseSignalReading(raw)` → `present(name)` / `absent` (`NO SIGNAL`, `ER401`) /
     `unknown` (transport failure: no transition, the regular poll owns Offline).
   - `SignalWatchState` per projector: `armed` (signal seen since power-on), `holdUntil`
     (app input switch + 10 s), `lostAt`, `restoredAt`, `input` at the loss.
     `stepSignalWatch(state, reading, power, now)` → new state; disarms on anything but
     `on`, arms on the first `present`, ignores `absent` while unarmed or held.
3. **Scheduler** (`signalWatchProvider`, `keepAlive`, its own file):
   - Runs only while the Signal lost rule is on; watches projectors that are `connected` /
     `unprotected` and `PowerStatus.on`. Others are dropped from the schedule and their
     state reset.
   - **Staggered**: each projector gets a fixed phase in the 2 s period (by position in the
     list), so 150 projectors give one query every ~13 ms, never a burst of 150. One driver
     `Timer.periodic` (50 ms) starts the queries that are due.
   - **Never piles up**: a projector whose previous query is still in flight is skipped;
     at most 16 queries in flight overall (at 20 ms each that is ~800 / s of headroom).
     If the network is slow the period stretches instead of queuing.
   - **Never adds a 4th connection to a projector**: skips it while it is claimed
     (`_refreshingNodes`: its regular poll, `refreshNode`, pre-show probes), during power
     transition tracking, and while a command to it is in flight (new: `_dispatchToNodes`
     marks its targets busy). The regular poll's own `NSGS1` result is fed to the watch
     too, so a skipped tick loses nothing.
   - `IIS:` sent by the app (UI, OSC, schedule, Web) → `holdUntil = now + 10 s` for those
     projectors; `PON` → disarmed until a signal is seen.
4. **Alert** (`alertsProvider` / `domain/alerts.dart`):
   - `reconcileAlerts` gets the watch states. Signal lost is raised on `lostAt` with the
     input as the value qualifier (`HDMI 1`), latched: when the signal returns it gets
     `restoredAt` ("Back after 3 s", green) and stays until acknowledged; acknowledging a
     restored one clears it. A new loss while latched and unacknowledged updates
     `since`, not a second alert. `ActiveAlert.copyWith` learns `restoredAt`.
   - The alert engine rebuilds only on a watch *change* (loss / return / arm), not on
     every 2 s reading, the same dedupe as today.
5. **Monitoring table**: on a change only, the watch writes `node.signal` through a new
   `WorkspaceNotifier.applyPolledSignal`, so the Signal column shows `NO SIGNAL` within
   2 s instead of at the next poll. Readings that don't change don't touch workspace
   state (150 × 0.5 / s state writes would rebuild the UI constantly).

**Not a setting:** the 2 s period and the 16-query cap. The Signal lost switch turns the
whole watch off (no traffic at all).

**Tests:**
- Unit: `parseSignalReading`, `stepSignalWatch` (arming, hold after `IIS`, disarm on
  standby, `ER401`, `unknown`), alert latch / acknowledge / repeat loss.
- Provider, `FakeProtocolService` + `fake_async`: stagger (150 nodes → no more than
  ~1 query per 13 ms), in-flight skip, claimed-node skip, rule off → no queries,
  eligibility changes.
- Simulator: console command `sig <n> off|on|blip` (`blip` = ~3.5 s without signal) to
  test alerts without a cable; `projector_simulator.dart 150` as the load test (watch CPU,
  sockets, UI smoothness).
- Hardware: a 1-hour run on the PT-RQ35K with the watch on: no timeouts, web UI and
  Remote Preview still responsive, `TIME_WAIT` count on the PC flat.

**Docs when done:** CLAUDE.md providers table (`signalWatchProvider`), `panasonic-ntcontrol`
skill (the projector closes after one command; `ER401` while locking), this item's
Progress line.

F5 adds **no new queries to the poll cycle**: every rule above works from telemetry the app
already polls (plus the signal source the spike picks). Rules that need extra queries are a
separate item, §4b.

### UX
UI text uses commas, colons and parentheses as separators, never `·` or `—`.

**Card badge** (replaces today's orange ⚠ in the card's status row):
- `Icons.error` red for critical, `Icons.warning` orange for warning; the colour follows the
  highest-severity *unacknowledged* alert.
- Filled while anything is unacknowledged, outlined once everything is acknowledged.
- A number next to the icon from two alerts up.
- No tint on the status row: it merged with red / orange group colours.

**Alert panel** (from the card badge):
- Hover the badge for 250 ms → opens. It stays open while the pointer is on the badge or the
  panel (250 ms grace to cross the gap), so its buttons are reachable; a click elsewhere
  closes it. One panel, no read-only mode. **No pinning** (changed 2026-10-02): a click on
  the badge is a click on the card (it selects); a pinned panel looked the same as a hovered
  one and read as stuck.
- Built on `OverlayPortal`, not `Tooltip` — a `Tooltip` inside the card's `MenuAnchor`
  corrupts the Windows AXTree (see the comment in `projector_card.dart`). Not scaled with
  canvas zoom.
- Width 320. Header: projector name, IP, critical / warning counts, *Acknowledge all*
  (`done_all`) and *Event log* (`receipt_long`, opens the log filtered to this projector) as
  icon buttons. The header never scrolls.
- Each alert is a row on its own surface: severity chip (same icon as the badge), rule name
  small, **value large in the severity colour** (`58 °C`, `No signal`, `Cooling fan`;
  recovered dropouts green, `Back after 3 s`), an optional qualifier (e.g. the input, `HDMI 1`),
  duration with start time on the right, and an *Acknowledge* button in its own column.
  No threshold or limit text in rows.
- Order: critical first, newest first within each severity.
- List up to 436 px (≈ 8 rows), then scrolls; the edge with hidden rows fades and a
  "N more below" line shows under it. Never taller than the window minus 16 px; opens above
  the badge when there's no room below.
- Acknowledged alerts sit at the bottom as single quiet lines in a collapsible
  "Acknowledged (N)" block, folded when there are more than 3.

**Status bar:**
- The *Warning* counter becomes an **Alerts** button: an `error` and a `warning` icon with the
  number of unacknowledged alerts each (filled icon, bold number). When everything is
  acknowledged the icons turn outlined and show the active totals; with no alerts, a green
  check.
- It opens **Active alerts** (width 404, list up to 520 px):
  - Header: total, fold / unfold all, *Acknowledge all*, *Event log*. Fold / unfold all
    shows whenever there is anything to fold, in both groupings (changed 2026-10-06: it
    used to need two groups, so a single rule group had none), and reaches every level:
    groups, project-group sections and a rule's subsections. Same on the web.
  - Filter chips: All / critical / warning, with counts.
  - Grouping toggle **Projector / Alert**. Starts on Projector; the last choice is remembered
    in app settings. Alert grouping turns a mass failure (one media server feeding 24
    projectors) into one row, e.g. "Signal lost, 20 projectors, since 14:11".
  - Groups start folded when there are more than 4. Group headers are one line, the same
    folded and unfolded (approved 2026-10-02, mockup
    https://claude.ai/artifact/1sFY6SMU1z3SC868eeB6Dm v6): projector name and IP with
    the counts; or rule, "N projectors, since 14:11" and the count. No summary line under
    them. Each group has its own *Acknowledge* button.
  - **Project groups** toggle (`workspaces` icon next to Projector / Alert), shown in a
    project that has groups, in both groupings (changed 2026-10-06: hiding it on the
    Alert grouping moved the toolbar on every switch), last state saved in app settings:
    by projector it sorts the projector groups into foldable sections, one per project
    group in Manage Groups order (colour, projector count, alert counts, its own
    *Acknowledge*), then **Ungrouped**; by alert it splits each rule's rows into the
    same subsections inside the rule group ("Signal lost, 20 projectors" → Stage 12,
    Balcony 8), so a mass failure shows which part of the venue it hit.
  - Rows grouped by alert name the projector with its IP instead of the rule.
  - Same alert rows as the card panel; acknowledged ones collapsed at the bottom.
  - Empty states: "No active alerts", and "All acknowledged" when nothing is new.
- There is no "clear" button: acknowledging is the clear, and the list only holds conditions
  that are true right now.

**Monitoring table:** cells that trip a rule are tinted (temperatures already are).

**Preferences → Alerts** (new section between General and OSC; mockup
https://claude.ai/artifact/SgePKn3PrHM5xwGWsbro6R, approved 2026-10-01). Built from `SettingsGroup` / `SettingsRow`; every switch sits in one right-hand
column, and a rule that's off greys out its fields.
- **Rules:** Offline, Projector error, Signal lost (switch only, severity icon in front of
  the label); Intake and Exhaust temperature with two value fields each (warning, critical,
  marked with the alert icons) plus the switch. Editing them changes the Monitoring table
  tint too, so the thresholds move from `status_thresholds.dart` constants into app settings.
- No Extra rules group in this item; it arrives with §4b (the mockup shows the final dialog
  without it).
- **Notify:** Desktop notification (on) with "Notify for: Critical / All" (default Critical);
  Sound (off) with a play-sample button and "Play for: Critical / All"; OSC message (on).
  No Event log row: alerts are always logged.
- Not settings: hysteresis (2 °C) and the Signal lost arming.

**Value fields and dropdowns, whole dialog** (approved 2026-10-02, mockup v4 at the
Preferences link above; every field and dropdown in Preferences moves to this style, OSC and
Web Access included):
- Filled, no outline at rest: `surfaceContainerHighest` background, radius 8, height 32
  (same as the segmented buttons), unit inside the field, an optional severity icon in front.
  Numbers right-aligned; IP and PIN fields left-aligned.
- While editing: a 2 px primary border around the whole field and a slight primary tint.
  Error: 1 px error border and a faint error tint at rest, 2 px while editing; the message
  stays under the row label and in the footer.
- Focusing a field selects its whole value, so typing replaces it. In Flutter, select in a
  post-frame callback after the tap: a tap places the caret after focus arrives.
- **Enter** applies the value and drops focus. **Esc** drops focus without applying (the
  field returns to the value it had before editing) and must not close the dialog.
- Hints under row labels are smaller and lighter than the label (the label gets weight 500);
  placeholders (`Unchanged`, `Not set`) are italic, smaller and lighter than any value.
- **Dropdown:** the same filled surface, network icon, IP in bold, interface name muted;
  editing border and a turned chevron while open. Menu on its own raised surface, 36 px rows,
  a check on the current value, *Any interface* split off by a divider; opens below, flips
  above when there's no room; arrow keys, Enter, Esc closes only the menu. Built on
  `MenuAnchor` with a custom button, not `DropdownMenu` (a text field; plain text only).
- *Link* is read-only: quieter surface, no hover, copy button inside. *Sign out all* is
  36 px tall, like the footer buttons (32 read too thin in the app). The HTTP note loses
  its dash.

**Desktop notifications:**
- The system's own UI (Windows toast, macOS Notification Center banner); the app sets icon,
  title and text. On Windows a severity icon can sit next to the text; macOS banners only
  show the app icon. macOS asks for permission on first use.
- Title "<Rule> on <projector>", body with value and time, e.g. "Signal lost on PRJ-03
  Right" / "No signal on HDMI 1 since 14:02".
- Alerts raised within 2 s of each other are merged into one notification ("Signal lost on
  20 projectors", "PRJ-13, PRJ-14, PRJ-15 and 17 more, plus 12 other alerts").
- Clicking it brings the app to the front and opens Active alerts.
- The notification itself is silent.

**Sound:** played by the app, not by the notification, so it still plays when Windows Focus
or macOS Do Not Disturb hides notifications. Two short bundled sounds, one for critical and
one for warning; one sound per merged batch. Needs an audio package or a little native code
(Windows `PlaySound`, macOS `NSSound`); pick after a quick spike.

**OSC** (to the send target from the OSC section, one message per change, never repeated
while nothing changes):
| Address | Arguments | When |
|---|---|---|
| `/pgrid/alert/<rule>` | projector (s), ip (s), active 1/0 (i), severity (s), value (s) | an alert is raised (1) or its condition ends (0; for Signal lost the moment the signal is back) |
| `/pgrid/alert/acknowledged` | projector (s), rule (s) | an alert is acknowledged in the app or on the Web page |
| `/pgrid/status/critical` | count (i) | the number of unacknowledged critical alerts changes |
| `/pgrid/status/warning` | count (i) | the number of unacknowledged warning alerts changes |

Rule names in the address: `offline`, `error`, `signal-lost`, `intake-temp`,
`exhaust-temp` (§4b adds its own). Example:
`/pgrid/alert/signal-lost "PRJ-03 Right" "192.168.10.13" 1 "critical" "HDMI 1"`.

`/pgrid/status/warning` **changes meaning** (decided): today it counts projectors with
errors, from now on unacknowledged warning alerts, since errors become critical alerts.
`/pgrid/status` (request) answers with `critical` too. Update to match: the OSC reference
(`osc_reference_html.dart`), and `statusSummaryProvider`, whose `warnings` count (projectors
with errors) feeds both the status bar and `osc_provider.dart` today.

### Progress
Build order: engine → Preferences (fields, dropdown, Alerts section) → card badge and panel
→ status bar and Active alerts → OSC → Monitoring tints → notifications and sound.
- `[x]` Engine (2026-10-02): `AlertSettings` in app settings (thresholds moved there from
  `status_thresholds.dart`, which now holds the defaults and the 2 °C hysteresis),
  `domain/alerts.dart` (evaluate, reconcile, sort), `alertsProvider`, event log type
  `alert`. Offline needs `ProjectorNode.polled`, so a just-loaded project doesn't raise it
  before the first poll.
- `[x]` Projector error (2026-10-02): `decodeProjectorErrors`
  (`domain/projector_errors.dart`) pulls every `U/F/H###` code out of the `ERRS2` reply and
  names it from the PT-RQ35K manual's code table (exact codes before the ranges that hold
  them), e.g. "Fan error (F305)". Severity comes from the table: the manual's *warnings*
  (U081, U200–U280, F200–F228, H001) raise warning alerts, everything else critical. A code
  the table doesn't know, or a reply with no code in it, comes through raw as one critical
  alert. Confirmed on hardware 2026-10-02: `ERRS2` returns these codes. The table is also
  in the `panasonic-ntcontrol` skill (`command_reference.md` → Self-diagnosis codes).
- `[ ]` Later, with hardware: the projector's web UI shows each error code with its
  description. If that page parses reliably (the app already reads the web status page for
  signal), take the descriptions from there and keep the table as the fallback.
- `[x]` Preferences (2026-10-02): `SettingsValueField`, `SettingsDropdown` (one text line,
  so the IP is never cut for the interface name's sake), quieter `SettingsRow` hints, the
  Alerts section; Save rejects a warning threshold at or above critical. Checked in the app.
- `[x]` Card badge and alert panel (2026-10-02): `AlertBadge` on
  `OverlayPortal.overlayChildLayoutBuilder` (gets the badge's place during layout, so the
  panel follows the card through zoom and pan), `ProjectorAlertPanel`, shared `AlertRow` /
  `AlertScrollArea`. *Event log* opens the log searching for the projector's IP
  (`eventLogRequestProvider`); the log got an *Alerts* tab. Checked in the app.
- `[x]` Status bar Alerts button and Active alerts (2026-10-02): `StatusBarAlertsButton`,
  `ActiveAlertsPanel` (stays under its button and shrinks with the window), project-group
  sections (`sectionByProjectGroup`). Projector groups go by IP ascending (`ipSortKey`,
  shared with the Monitoring table), also inside sections; rule groups stay
  most-urgent-first. Checked in the app.
  2026-10-06: the project-groups toggle stays in the Alert grouping too and splits each
  rule's rows into project-group subsections (`subsectionByProjectGroup`).
- `[x]` OSC (2026-10-02): `alertsProvider.events` (raised / cleared / acknowledged, with
  name and IP) → `/pgrid/alert/<rule>` and `/pgrid/alert/acknowledged`, gated by the
  *OSC message* setting; `/pgrid/status/critical` and the new-meaning `/pgrid/status/warning`
  from `alertCountsProvider`, also sent on acknowledge; `statusSummaryProvider.warnings`
  removed; OSC reference updated. Outgoing messages use our own `encodeOscMessage`:
  package:osc writes strings as single-byte UTF-16 code units (`°` and Cyrillic names
  come out broken), and its decoder misreads arguments after a string of 4n bytes.
- `[x]` Monitoring table (2026-10-02, mockup https://claude.ai/artifact/B6LrAinsr6zWe5B7VzHskr
  v3): Intake / Exhaust tinted by their active alert (hysteresis, switched-off rule);
  Errors cell shows the codes as severity-coloured tags, critical first, up to 4 then +N
  (`MonitoringErrorsCell`), and a hover panel with each error's name and how long it has
  been active, no header; group rows count unacknowledged alerts by severity (auth errors
  only when there are none). Hover behaviour shared with the card badge (`HoverPanel`).
  Checked in the app; the Errors cell checked on 2026-10-06 with the simulator's
  `err` command (an overflow found at first was fixed).
- `[~]` Desktop notifications and sound (2026-10-02): packages chosen after the spike,
  `flutter_local_notifications` (Windows toast in an unpackaged exe via AUMID + GUID,
  silent mode, click callback; macOS asks permission on first use) and `audioplayers`.
  Two sounds synthesised by `tool/generate_alert_sounds.dart` into `assets/sounds/`.
  `alertNotificationsProvider` batches raised alerts for 2 s from the first
  (`alertNotice`, `noticeable` in `domain/alert_notifications.dart`); a click brings the
  window forward on Active alerts (`activeAlertsRequestProvider`). Preferences has the
  play-sample button. Severity icon in the Windows toast (`appLogoOverride`, the batch's
  top severity): `tool/generate_alert_icons.dart` → `assets/alert_icons/`, glyph ~75% of
  the image so it reads smaller at Windows' fixed logo size. macOS keeps the app icon (no
  API to replace it; an attachment thumbnail was declined). The toast header's app icon
  comes only from a Start menu shortcut carrying the AUMID (checked with a test
  shortcut), so the installer's shortcut sets `AppUserModelID` and the toast activator
  CLSID; dev and portable builds show the header without an icon. Checked on Windows;
  awaiting a check on macOS.
- `[~]` Signal lost (2026-10-05): built as in "Signal watch: implementation plan"
  (`sendQuickQuery` + the FIN wait, `domain/signal_watch.dart`, `signalWatchProvider`,
  latched alert with "Back after 3 s" in green, Signal cell red while lost, simulator
  `sig`). Changed from the plan while building:
  - An input switch by the app **disarms** the watch instead of a 10 s hold: it re-arms on
    the new input's first signal, so switching to an input with nothing connected never
    raises.
  - The alert value is `No signal on HDMI 1` (the input folded into the value; no
    separate qualifier field). OSC and notifications carry the same text.
  - A suspected loss is confirmed with `QVX:POWI1` first: `ER401` is also the answer of a
    projector gone to standby by itself; then `refreshNode` updates it.
  - Fixed after the first hardware check: `IIS:` updates the Input column at once
    (optimistic); a reading that crossed an app input switch is dropped (it raised a false
    loss); an app input switch no longer ends an open dropout, so a signal on the new
    input turns it into "Back after"; a changed signal triggers one `QIN` so an input
    switched on the projector itself shows within ~2 s.
  - Signal back (2026-10-05, owner's request): a new `AlertChange.recovered` transition
    when a latched Signal lost gets its signal back. A recovered alert is no longer a
    problem: card badge and status bar show it apart as a green check with a count (red
    only while the signal is really gone), panel headers and Monitoring group rows count
    it as "recovered", severity filters leave it out (All keeps it). A silent desktop
    notification "Signal back on PRJ-03 (ip)" / "Back after 3 s, lost at 14:02" (green
    check logo, `assets/alert_icons/recovered.png`), batched like raised ones, under the
    same Desktop notification switch and Notify for as the alert (no switch of its own:
    it didn't fit the dialog, and Signal lost is critical anyway). OSC sends `active 0` with
    `Back after 3 s` at the return, and nothing again when the acknowledge clears it.
    Event log: "Signal lost: Back after 3 s". No sound for the return.
  Unit and provider tests pass; on hardware 50 quick queries took 1.5 s with no TIME_WAIT
  left on the PC.
  Checked 2026-10-06 in the app with the simulator (`sig N blip` on all projectors, F011
  and H001 errors, simulator stopped mid-run): no false Offline, no duplicate alerts on
  return. **150-projector simulator run:** TIME_WAIT only on the simulator's side
  (~13,000 steady state, none on the app's side, as the FIN wait intends), CPU 0.5% idle
  and up to ~6% during a full poll, 600-700 MB of memory. Debug builds stuttered on zoom
  and card drags; `flutter run --profile` is smooth, DevTools shows the UI thread idle
  and only raster time (a few ms, rare ~12 ms frames) with active alerts. Closing the
  project stops all queries (no connections to the projectors, TIME_WAIT decays).
  Still to do: the 1-hour hardware run.

### Code
- `domain/alert_rule.dart` (plain Dart + JSON, saved in app settings — alerts are a machine
  preference, not per-project). The Active alerts grouping choice is saved there too.
- `presentation/providers/alerts_provider.dart` (`keepAlive`) — `ref.listen(workspaceProvider)`,
  evaluates rules per node on each telemetry change, keeps `Map<(nodeId, rule), ActiveAlert>`
  (with `acknowledged`, `since`, and for Signal lost `restoredAt`), emits transitions only
  (raised / cleared) to the event log, OSC and notifications. In memory only.
  Must not rebuild on every tick — compare previous vs next per node (the same dedupe idea as
  `statusSummaryProvider`).
- Evaluation and ordering as pure functions in `domain/` (testable without widgets).
- Temperatures are stored formatted (`_formatTemp`) — add numeric parsing in one place (or
  keep raw numeric fields on `ProjectorNode`: Freezed field + `build_runner`).
- Desktop notifications: evaluate `local_notifier` (Windows + macOS) vs a platform channel;
  pick after a quick spike. New Dart dependencies in this roadmap: this one, plus `shelf` /
  `shelf_router` for F7 (§5).

---

## 4b. `[later]` F5b — Extra Alert Rules (new poll queries)

### Why separate
Split out of F5 on 2026-10-01: these rules each add a query to every poll cycle, and F5 is
meant to ship without touching the poll cycle. Builds on F5's alert engine, panels and
Preferences section.

### Rules
Commands confirmed in the PT-RQ35K2/RZ34K2 list but **not polled today**. Each one is off by
default, and its query is added to the poll cycle only while the rule is enabled.
| Rule | Severity | Command | Trips when | OSC name |
|---|---|---|---|---|
| Running on backup input | warning | `QVX:BACI4` | `+00001`: the main signal failed and the projector switched to its backup input; the image may still look fine, so this is the one worth having | `backup-input` |
| DIGITAL LINK lost | critical | `QVX:DKSI1` | `+00000` (no link) on a projector whose input is `DL1` | `dl-lost` |
| Multi Projector Sync changed | warning | `QVX:MPSI2` | status changes away from the value seen when the rule was enabled | `mps-changed` |

Models that don't support a command answer `ERR1`/`ER401` → the rule is shown as
"not supported" for that projector instead of alerting.

### UX
- **Preferences → Alerts:** a third group, **Extra rules**, between Rules and Notify: one
  row per rule with its severity icon, the hint "Adds a query to each poll" and a switch
  (all off). Shown in the first Preferences mockup
  (https://claude.ai/artifact/SgePKn3PrHM5xwGWsbro6R, earlier version).
- **Alert rows:** backup input shows the backup input as the value and the failed one as the
  qualifier (`SDI 2`, `SDI 1 failed`); DIGITAL LINK shows `No link`, `DL1`.

### Code
- The poll cycle asks for the extra queries only while their rule is on; keep them inside
  the existing per-projector poll so the NTCONTROL connection limits still hold.

---

## 5. `[~]` F7 (reframed) — Local Web Monitor & HTTP API

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
- With *Allow control* off, only the Viewer PIN exists and the server has no write routes at all
  (`/api/unlock` / `/api/lock` answer 404). Switching it off drops every operator back to
  viewer; nobody is signed out.
- **Sessions:** a successful PIN returns a random session token in an `HttpOnly` cookie
  (browsers) or in the JSON reply (scripts). It expires after 12 h idle. Changing either PIN
  or pressing *Sign out all clients* in the settings tab invalidates every session.
- **Brute force:** 5 wrong PINs from one IP → that IP is locked out for 60 s, doubling on each
  repeat up to 1 h; each lockout is logged in the Event Log.
- **Scripts / Companion / QLab:** `POST /api/login {"pin": "…"}` → token, then
  `Authorization: Bearer <token>`.
- Plain HTTP on the show LAN: the PIN crosses the network unencrypted. Acceptable on a
  closed show network; the settings tab says so in one line. HTTPS with a self-signed
  certificate only makes phones show warnings, so it's out of scope.

### UX
- **Preferences → "Web Access" tab:** *Enable* switch, port (default 8080), **Viewer PIN**,
  *Allow control* switch → **Operator PIN**, *Sign out all clients*, connected clients list
  (IP, role, last seen), and the URL (`http://<this-machine-ip>:8080`) with a drop-down of
  this machine's IPv4 addresses (show PCs often have several NICs). A **QR code** for the
  selected URL is `[later]` — the owner decides later (it needs a new dependency).
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
| Errors | green check **NO ERRORS**; otherwise code tags in their severity colour, from `errorItems` (decoded by the app); cards and tiles show the alert badge (see *Alerts* below) |
| Intake temp | amber ≥ 40 °C, red ≥ 45 °C (`_intakeWarmC` / `_intakeHotC`) |
| Exhaust temp | amber ≥ 55 °C, red ≥ 65 °C (`_exhaustWarmC` / `_exhaustHotC`) |
| Signal | plain text, like the app's table (`NO SIGNAL` isn't tinted there) |
| Test pattern | mini swatch + name whenever a pattern is on, shutter open or closed (owner, 2026-09-30 — the app card will follow); web cards show the swatch beside the IP |
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

The app's `model` column shows `node.name` and is labelled "Model". The web keeps the
**Model** label to match the app (owner, 2026-09-29); the list above says "Name" only to
describe what the column shows.

| App feature | Web |
|---|---|
| Show / hide columns (View ▸ Monitoring Table), last column can't be hidden, re-shown column returns to its canonical slot (`toggledColumn`) | **Columns** popover: checklist, same rules |
| Presets *Essentials / Thermal / Signal / Show all* | Preset buttons in the popover + *Reset* |
| Click header to sort, again to reverse; default `ip` ascending | Same; arrow on the sorted header, `aria-sort` |
| Drag a header to reorder | Same: drag the header, the target header highlights, same landing rule (`_reorderColumn`). No drag list in the popover (owner, 2026-09-30) |
| Drag a header's right edge to resize; double-click it to auto-fit | Same; the edge shows a hairline on hover. Auto-fit measures the widest cell, like `onAutoFit` |
| Fit to width (`monitoringFitToWidth`), with the `_resizeBaseFor` maths so a resized column lands where dragged | Same switch and the same formula; floor 60 px (`_minColWidth`); sideways scroll only when floors push past the viewport |
| Density compact / standard / comfortable (row 32 / 40 / 52 px) | Same three options |
| Group-by (`monitoringGroupBy`); the Group column is hidden while grouping | Same switch (disabled when the project has no groups); group sections like the app's (count + worst-status pill), plus collapsible |

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

#### Map — the project's card layout (owner, 2026-09-30)
A third view beside Table and Cards that draws the projectors where they sit on the app's
Controls canvas, so the page reads like the wall.
- **Where:** tablets and desktop only. The switch is *Table / Cards / Map* where the table is
  offered and *Cards / Map* on upright tablets. Phones have no Map. Table / Cards defaults stay
  as they are, and Map is only ever picked by hand.
- **Data:** `x` / `y` from `/api/projectors` (already served), with the app's 120×100 card size.
  A card moved in the app moves on the page over SSE. The page never moves cards, because the
  layout is edited only in the app.
- **View:** fit to the area on open, then *− / + / Fit*. Touch pans and zooms with two
  fingers. The mouse zooms with Ctrl + wheel and scrolls with the wheel.
- **Tile:** a copy of the app's card.
  - The status bar has power, shutter, the warning triangle, the lock and the connection dot.
  - Below it are the name and the IP, with the test-pattern thumbnail.
  - A group tints the tile's background and adds its chip under the tile.

  Zoomed far out, a tile keeps only the dot and name.
- **Filters and search** dim the tiles that don't match rather than hiding them, so the wall
  keeps its shape.
- **Operator selection** (owner, 2026-09-30). Offline and auth-error tiles can't be selected,
  and a marquee skips the tiles the filter dims.
  - **Mouse:** the same as the app's canvas.
    - A click selects only that tile, and Ctrl / Cmd / Shift + click adds or removes it.
    - A drag draws a marquee that replaces the selection, or toggles the tiles it covers
      with Ctrl / Cmd / Shift.
    - A click on empty space clears the selection.
  - **Touch:** there are no modifier keys.
    - A tap adds or removes a tile.
    - One finger draws a marquee that adds to the selection. Two fingers pan and pinch-zoom
      (as in Figma on iPad).
    - A tap on empty space doesn't clear the selection, so a near miss can't lose it; the
      toolbar box clears it.
  - **Details:** the operator opens a tile's details with a right-click or a long press. The
    viewer taps (or clicks) the tile, and a viewer's one-finger or mouse drag pans the map.
  - Selection and the Control panel are shared with the other views.

#### Alerts (decided 2026-10-06, after F5 §4)
Mockup: https://claude.ai/artifact/N6goiSv7DuMTYT15rophYT (desktop Table and Cards,
tablet and phone both ways up with the touch layout, Map tiles). The page shows `alertsProvider`'s list as is:
no rule engine in the browser.
- **Where the panel opens** follows the Control panel's placement (`device.control`):
  | Screen | Entry | Panel |
  |---|---|---|
  | Desktop, tablet sideways | 52 px **rail** at the far right: bell (colour of the worst unacknowledged alert, count), one tick per alert in its severity colour (acknowledged faint, a returned signal green) | **drawer over the content**, 404 px (the app's panel width, not the 360 px first planned), so table and Control panel don't reflow |
  | Tablet upright, phone upright | bell in the header + an alert pill above the cards ("4 new alerts, 1 signal back") | bottom sheet |
  | Phone sideways | same | right-hand sheet |
- **The panel is the app's Active alerts** (`active_alerts_panel.dart`), for both roles:
  title with the total, fold / unfold all, *Acknowledge all*; chips All / critical /
  warning; grouping Projector / Alert and the project-groups toggle; group headers with
  their counts and *Acknowledge*; the same alert rows (severity chip, rule, value large in
  the severity colour, duration and start time, *Acknowledge*); acknowledged ones folded
  at the bottom; the app's empty states. No *Event log* button (the log is app-only).
  The project-groups toggle stays in both groupings, as in the app (§4).
- **Touch layout** (tablets and phones, approved 2026-10-06 with mockup v3): not a
  scaled-down desktop panel. Every target 44 px or more (row *Acknowledge* 52, group 48);
  severity and grouping as full-width labelled segments (All / Critical / Warning, By
  projector / By alert), the project-groups toggle labelled "Groups"; rows 68 px with a
  severity stripe and the value at 17 px bold; *Sound* and *Acknowledge all (N)* in a
  footer on the bottom edge (a viewer gets *Unlock* there). Phone sideways: the segments
  share one row with icons and counts only, sheet 470 px wide. Header filters 40 px, bell
  44 px, alert pill 56 px, larger card badges and tags; error tags open on tap. Tablet
  sideways: the drawer is 440 px with the touch layout.
- **Viewer:** everything but the *Acknowledge* buttons; a line "Viewers see alerts;
  acknowledging needs control" with *Unlock control*.
- **Elsewhere on the page:**
  - The header filter *Warnings* becomes **Alerts**: projectors with an active alert, with
    the counts of the app's status-bar button (filled icon + unacknowledged count,
    outlined + total once acknowledged, green check for returned signals).
  - Cards and Map tiles: the app's card badge replaces the orange triangle (`alertBadge`:
    colour of the worst unacknowledged alert, filled / outlined, a number from two up,
    green check while only a returned signal waits).
  - Errors cell and the card's error line: code tags in their severity colour, critical
    first, up to 4 then +N; hover (tap on touch) for each error's name and duration.
  - Intake, Exhaust and Signal tinted by their active alert (so hysteresis and a switched-
    off rule follow the app); group rows and card group headers count unacknowledged
    alerts.
- **New-alert cues:** the tab title gets the unacknowledged count ("(5) Main Hall") and the
  favicon a dot; a toast "Signal lost on PJ-08: No signal on SDI 2" with *Show*; the
  rail's new tick pulses. **Sound** (approved): a speaker button in the panel header, off
  by default, per browser; the app's two sounds, one per batch of alerts raised within 2 s,
  none for a returned signal. A browser plays sound only after a tap on the page, which
  the button press is.
- **No browser notifications:** they need HTTPS, which on a show LAN means a self-signed
  certificate and a warning page on every device, and even then a phone shows nothing
  while locked (push needs Apple's / Google's servers, i.e. internet). OSC
  `/pgrid/alert/*` already covers remote alerting.
- **Kept per browser** (`localStorage`): drawer open / closed, grouping, project groups,
  sound. Fold state is not kept.
- **Acknowledge from the page** works as in the app: OSC `/pgrid/alert/acknowledged`, a
  returned signal clears, and the Event Log line names the source
  ("Signal lost acknowledged (Web · 192.168.0.77 · operator)").

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
**Identify is left out on the web** until it exists in the app (§3.1 is `[later]`), and the
presets follow the app: Geometry / Color / Custom (no Blend, §3 deviations).
`alignmentProvider` stays the single source of truth; the web page shows its state via SSE and
sends actions to it. Entering from the phone shows the banner in the app too, and vice versa.
Only one alignment session exists at a time; a second client entering joins the same session.
- **Desktop:** the app's banner across the page, in one row: *◀ name n of N ▶ · Neighbours ·
  Show all · Preset [Geometry | Color | Custom] · Focused ▾ · Others ▾ ·
  Exit*.
  - The presets are the app's §3.2 table, including **Custom**.
  - *Focused ▾* / *Others ▾* open a swatch popover filtered by the preset: Geometry → cross
    hatches, Color → solid colours, **Custom → every test pattern**. *Others* also has
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
  - Neighbours / Show All toggles;
  - a **wall mini-map** built from the card layout — focused filled, neighbours outlined,
    offline dashed; tap a tile to focus it;
  - preset switch (Geometry / Color / **Custom**) and *Focused* / *Others* rows that
    open a bottom sheet with the filtered swatch grid;
  - the lens block for the focused projector.
- *Adjust ▾* (geometry / colour dialogs) stays app-only.
- Exit from the web restores shutters, patterns and shutter fades exactly like Exit in the app.

#### Remote Preview on the web (owner, 2026-09-30)
The app's Remote Preview (`REMOTE_PREVIEW_PLAN.md`) for **one projector at a time**. Multiview
may come later as a separate step.
- **Who:** operators and viewers can watch. The **Pre-show** toggle changes the projector, so
  only operators get it.
- **Transport:** the browser never opens the projector's socket itself, because it may sit on
  another network and a direct socket would skip the PIN and roles. The app relays instead.
  - `GET /api/preview/{id}` is an SSE stream with `frame` events (the JPEG, base64) and
    `status` events (no signal / preview unavailable / closed, pre-show, signal tag).
  - It sits behind the same auth as the rest of `/api/*`.
  - The app keeps **one** `RemotePreviewController` per projector, shared by every browser
    and the app's own preview window.
  - The socket opens when the first watcher arrives and closes a few seconds after the last
    one leaves.
- **Where** (owner, 2026-10-01): a *Preview* button in the details (card strip, Map popover,
  which right-click and long press also open) and a *Preview* column in the table (hideable
  and draggable like the rest). Not in the Control panel and not in Alignment mode.
- **◀ ▶** step to the neighbouring projector in the order of the view it was opened from
  (sort, filters, search; the Map in reading order), frozen when the window opens, wrapping
  at the ends ("3 / 24"). Selection isn't touched; ← → keys, a swipe on phones.
- **Window:** a dialog on desktop and a full-screen sheet on phones.
  - The 16:9 image sits in a frame coloured by the shutter, as in the app.
  - The same overlays as the app: *No signal*, *Preview not available*, the signal tag and
    `PRE-SHOW`.
  - *Retry*, and *Pre-show* (operators only, enabled only in Standby, as in the app).
  - Pre-show is sent through the app (`POST /api/preview/{id}/preshow`), which logs it as a
    web command; the app's dialog and the pages share one pre-show state.

#### Manual status refresh (operator) `[ ]` (owner, 2026-10-07)
A button on the page that polls the projectors' status now instead of waiting for the next
poll cycle, the web counterpart of the app's `F5` (`WorkspaceNotifier.refreshAll`).
- Operators only (it adds NTCONTROL traffic), so behind the same guard as other `POST`s;
  404 without *Allow control*.
- Server route calls `refreshAll` (or `refreshNode` for the selection, to be decided), no
  polling logic in the server; results arrive over the existing SSE node events.
- While a refresh runs, the button shows progress and ignores repeat presses, so a phone
  can't queue a burst.
- Logged in the Event Log with the web source, like other web commands.

- The app shows a small "Web access on · 3 clients (1 operator)" indicator in the status bar.
- Live updates via **Server-Sent Events** (simpler than WebSocket, auto-reconnect in browsers).

### API (same server)
| Method | Path | |
|---|---|---|
| POST | `/api/login` | `{ "pin": "…" }` → session token + role; no auth needed |
| POST | `/api/logout` | ends the session |
| POST | `/api/unlock` | `{ "pin": "…" }` (Operator PIN) → this session becomes operator; only while *Allow control* is on |
| POST | `/api/lock` | this session back to viewer |
| GET | `/api/session` | project name + whether this client is signed in; no auth needed (the login page shows the project name) |
| GET | `/api/config` | project name, role, status-colour thresholds, test-pattern list |
| GET | `/api/projectors` | all nodes + telemetry, in layout order (JSON) |
| GET | `/api/projectors/{id}` | one node |
| GET | `/api/groups` | groups (empty array → the page shows the flat list) |
| GET | `/api/alerts` | `{ "now", "alerts": [...] }`: the active alerts (projector id, name, IP, rule, item, severity, value, since, acknowledged, restoredAt) and the server's clock, so a phone with a wrong clock still shows right durations |
| POST | `/api/alerts/acknowledge` | exactly one of `{"ids": [...]}`, `{"projectorId"}`, `{"rule"}`, `{"all": true}` → `{ "acknowledged": n }`; operators only |
| GET | `/api/alignment` | alignment state: active, focused, roles, preset, toggles |
| GET | `/api/events` | SSE stream: node changes, `alerts` (the whole `/api/alerts` reply on every change), alignment state, command results |
| GET | `/api/preview/{id}` | SSE stream of one projector's Remote Preview: `status` and `frame` (base64 JPEG) events |
| POST | `/api/preview/{id}/retry` | reconnect a watched feed (any role) |
| POST | `/api/preview/{id}/preshow` | `{ "on": bool }` — operators only, Standby with the feed up |
| POST | `/api/actions` | `{ "targets": [ids] \| {"group": id} \| "all", "action": … }` — see below |
| POST | `/api/alignment/{op}` | `enter` (`{"targets": [ids]}` — the page's selection), `exit`, `next`, `prev`, `focus` (`{"id"}`), `neighbours`, `diagonals`, `showAll`, `preset` (`{"preset"}`), `focusedPattern` / `othersPattern` (`{"code"}`); replies with the new state |

Not in the first version (owner, 2026-09-29): `POST /api/cues/{id}/fire` is added together
with F3 (§2); `identify` is added when §3.1 exists in the app.

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
  Routes call the same notifiers the UI uses: a new public
  `WorkspaceNotifier.sendCommandToNodes(ids, cmd, {source})` over `_dispatchToNodes` (§10) for
  actions — `source` puts *"Web · IP · Operator"* into the Event Log — and
  `alignmentProvider` for alignment. No command logic lives in the server.
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
  rule as `_throttledSend` (drop a lens step while the previous one is still in flight), but
  per projector, so a laggy phone can't queue up a burst.
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

**Status (2026-09-29):** the suite is in place — 210 passing, 1 skipped (a known bug), up from
one smoke test (169 at the R6 commit; F4 added the rest). Committed in `8a33ebc` (tests, refactors, CI) and `5c57b1e` (`dart format lib`).
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
  no device-name OSD command.
- **F4 Identify method** — deferred (2026-09-29): the owner doesn't consider the test-pattern
  flash in §3.1 settled and decides after tests on a real projector.
- ~~Go / no-go on zeroing shutter fade in Alignment mode~~ — decided 2026-09-28: always zero
  it while in the mode, only where it isn't already 0, and restore on Exit (§3.2).
- Live-unit checks: `QVX:LNSI7`…`LNSIA` reply format and absolute write (F1); whether `STS`
  shows the projector name on the image (F4).
- Alert default thresholds per model family, if the defaults in §4 don't fit.
- Go / no-go on §6 (error handler + log file).
