# Monitoring Table — UI/UX Improvement Plan

Working doc for improvements to the Monitoring view (`monitoring_table.dart`).
Status legend: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not applicable

Scope: this is a **proposal**. Nothing here is implemented yet. Sections are
ordered roughly by value-for-effort; a suggested phasing is at the end.

---

## 0. Where the table is today

`MonitoringTable` (`lib/features/workspace/presentation/widgets/monitoring_table.dart`)

- `ConsumerStatefulWidget`, **13 hard-coded columns** with fixed pixel widths
  (`_columnLabels` / `_columnWidths`).
- Manual sticky header, three synced `ScrollController`s, `ListView.builder`
  with `itemExtent: 40` — virtualized, so row count scales fine.
- Sort: click a header → single-column asc/desc, with a sort cache to avoid
  re-sorting on no-op rebuilds.
- Alt-row striping via `index.isOdd`.
- When the viewport is wider than the column total, every column is scaled up
  proportionally to fill the width; otherwise it scrolls horizontally.

### Limitations

| Area | Gap |
|---|---|
| Column choice | User can't hide/show/reorder columns; all 13 always shown |
| Column width | Not user-adjustable |
| Row feedback | No hover highlight, no row selection, no keyboard nav |
| Cross-view link | Table ignores `selectionProvider` — selecting here doesn't select cards, and vice versa |
| Grouping | No "Group" column and no group sections, despite groups existing |
| Errors cell | Dumps the raw 12-char `ERRS2` bitmask (e.g. `100000000000`) — not human-readable |
| Thermals | Plain text; no warm/hot color cue |
| Filtering | No search / no "errors only" / "online only" |
| Freshness | No "last updated" indication; stale data looks identical to fresh |
| Export | No copy / CSV |

### Known bug to fix along the way

Numeric-looking columns **sort lexically**, because the values are stored as
display strings (`"25°C"`, `"999H"`, `"120V"`). So `"25°C" < "7°C"` and
`"1000H" < "999H"`. Fixing this properly means carrying numeric telemetry on
the model (see §11) so sorting and color scales both key off real numbers.

---

## 1. `[ ]` User-selectable telemetry columns — via the View menu

**Goal:** let the operator pick which telemetry fields the table shows, from
the top menu bar rather than an in-table popup.

### UX

- Add a **"Monitoring Table"** submenu under the existing **View** menu
  (`top_menu_bar.dart`, right after the Controls / Monitoring radio items;
  mirror it in `mac_menu_bar.dart` for the native macOS bar).
- Contents:
  - A checkbox `MenuItemButton` per field — Name, IP, Serial, Group, Power,
    Shutter, Input, Signal, Runtime, Intake, Exhaust, AC Voltage, Errors,
    Last Updated, … — using the same leading-`Icons.check` pattern the
    "Show Logs" item / `_viewRadioItem` already use.
  - A `Divider`, then **preset** items that set the whole set at once:
    `Essentials` (Name/IP/Power/Shutter/Input/Errors),
    `Thermal` (Name/IP/Intake/Exhaust/Runtime/AC),
    `Signal` (Name/IP/Input/Signal/Power/Shutter),
    `Show All`.
  - Toggling off the last remaining column is blocked (always ≥ 1 visible).
  - `Fit columns to window` toggle lives here too (§2).
- The menu controls **visibility** (and the fit toggle). **Column order is
  changed by dragging header cells** — see §2.

### Implementation

- Introduce a `MonitoringColumn` descriptor list (id, label, default width,
  min width, value extractor, sort key, cell builder). Replace the parallel
  `_columnLabels` / `_columnWidths` / big `switch` in `_sortNodes` /
  `_buildRow` with one loop over the **visible** descriptors, taken in the
  user's saved order (`monitoringColumnOrder`) and filtered by the visible
  id set. Removes the current index-fragility where three lists plus a
  `switch` must stay aligned.
- Persist in `AppSettings` (see §11): `monitoringColumns` (visible id set) +
  `monitoringColumnOrder` (ordered id list); add `setMonitoringColumn(id,
  visible)`, `setMonitoringColumnOrder(list)`, and preset helpers on the
  notifier, same JSON-file save pattern as the existing setters.
- `TopMenuBar` / `MacMenuBar` watch
  `appSettingsProvider.select((s) => s.monitoringColumns)` to render check
  state; `MonitoringTable.build` reads both selectors and
  `_buildHeader` / `_buildRow` / `_sortNodes` iterate the resolved
  visible-ordered list instead of `0..12`.

---

## 2. `[ ]` Header interactions — sort, auto-fit, reorder

All three gestures live on the header cell itself — no context menus, no thin
drag-handles to hunt for.

### UX

- **Single click** on a header cell → sort by that column. Clicking the
  already-sorted column **flips ascending / descending**. (Decided.)
- **Double click** on a header cell → **auto-fit that column's width only**
  to its widest currently-rendered value. A double-click does *not* also
  sort. (Decided.)
- **Drag a header cell left/right → reorder columns.** Drop between two other
  headers to move it there; the body rows follow the new order live.
  (Decided — header drag-and-drop, not menu up/down items.)
- Menu toggle **"Fit columns to window"** (default ON — decided), in the
  "Monitoring Table" submenu:
  - ON  → columns scale proportionally to fill the width (today's behavior);
          an auto-fit / manual width then acts as a weight.
  - OFF → widths are honored in pixels, horizontal scroll as needed.
- Optional, later: a 6 px drag zone on the header cell's right edge
  (`SystemMouseCursors.resizeColumn`) for manual width drag. Auto-fit covers
  the common case, so this isn't required for the first pass.

### Implementation

- Header cell gets `onTap` (sort) + `onDoubleTap` (auto-fit). Since a
  double-click must *not* sort, we keep the two handlers separate and accept
  Flutter's ~300 ms tap-vs-double-tap disambiguation — a sort click resolves
  after that delay. It's subtle for a header sort; if it turns out to annoy,
  fall back to a manual click-count timer that fires sort immediately and
  cancels it only if a second click lands within the window.
- Reorder: wrap each header cell as a `Draggable` + `DragTarget` (feedback =
  a faded copy of the header label). On accept, move the id within
  `monitoringColumnOrder` and persist. The body `ListView.builder` rebuilds
  from the same resolved order, so rows track automatically. Sort state keys
  off the column **id**, so it survives a reorder.
- Auto-fit: `TextPainter` over the visible column's values (plus the header
  label) at the current text style, take `max(width) + cell padding`, clamp
  to the column's min and a sane max, write into the width map + persist.
- Widths become `Map<String,double>` state, seeded from descriptor defaults,
  overridden from `AppSettings.monitoringColumnWidths`, saved after an
  auto-fit (or a manual drag-end if that lands).
- The existing `effectiveWidths` math in `build` keys off column ids instead
  of a fixed-length list; header/body scroll-sync is unchanged (it already
  handles any total width).

---

## 3. `[ ]` Row hover highlight

**Goal:** make it obvious which row the cursor is on across 13 columns.

### Implementation

- Wrap each row in `MouseRegion` (`onEnter`/`onExit`), keep a single
  `int? _hoveredRow` in `State`, `setState` on change.
- Row background resolves as: selected tint > hover tint > stripe > transparent.
  Hover = `colorScheme.surfaceContainerHighest` (or a ~6% `primary` overlay).
- Wrap in a short `AnimatedContainer` (120 ms) per the desktop-UI skill's
  hover-state guidance. Cheap — only the hovered/previous rows rebuild, and
  the list is virtualized to ~20 rows.
- Optional: also highlight the hovered **column** (header + cells) faintly.

---

## 4. `[ ]` Row selection wired to `selectionProvider`

**Goal:** the Monitoring view becomes interactive and stays fully in sync with
the Controls view — one shared selection, both directions. (Decided.)

### UX

- Click a row → select that projector (`selectionProvider`), Ctrl/Cmd-click
  toggles, Shift-click range-selects (by current sorted order).
- Selected row: persistent `primary`-tint background + a 3 px `primary` left
  accent bar.
- Selecting cards in the Controls view highlights their rows here, and
  selecting rows here selects those cards in Controls — same provider, no
  extra wiring.
- With a selection active, the monitoring view exposes the existing
  selected/group command actions (Power, Shutter, …) — reuse `control_bar` /
  the toolbar actions so an operator can triage straight from the table.
- `Esc` clears selection; `Ctrl/Cmd+A` selects all visible (respects filter).
- Canvas does **not** auto-scroll/pan to the selection from here — highlight
  + command actions only. (Decided; can revisit.)

### Implementation

- `ref.watch(selectionProvider)` in `build`; pass membership per row.
- Reuse `WorkspaceNotifier`'s existing selection methods
  (`selectNodeOnTap`, range logic) — don't fork selection logic.

---

## 5. `[ ]` Keyboard navigation

Per the desktop-UI skill (keyboard nav is mandatory):

- `↑`/`↓` move a focused-row cursor; `Home`/`End` jump; `PageUp`/`PageDown`.
- `Space` toggles selection of the focused row; `Shift+↑/↓` extends.
- `Enter` opens the Edit Projector dialog for the focused row.
- `Ctrl/Cmd+F` focuses the search field (§7).
- Wrap the body in `FocusableActionDetector` / `Shortcuts`+`Actions`; ensure
  the focused row auto-scrolls into view (`Scrollable.ensureVisible` or manual
  offset math against `itemExtent`).

---

## 6. `[ ]` Cell rendering upgrades

| Cell | Proposal |
|---|---|
| **Intake / Exhaust temp** | Parse to a number; color the text/`chip` on a green→amber→red scale with **hard-coded** thresholds — no Preferences UI (decided). Defaults: amber ≥ 35 °C intake / ≥ 45 °C exhaust, red ≥ 45 / ≥ 60 (tune against model specs before shipping). Optional 2 px severity bar under the value. |
| **Runtime** | Show `1,234 h` (grouped thousands). If a light-source max is known (needs a command, §10), add a thin wear bar + remaining %. |
| **AC Voltage** | Flag out-of-range (e.g. < 100 V or > 130 V on a 120 V nominal) amber. |
| **Errors** | Decode the `ERRS2` 12-char bitmask into labeled chips — Temperature / Fan / Air filter / Light source / Shutter / Cover / Other — colored by severity, with a tooltip listing the full breakdown. Needs the per-position bit meaning table from the model's RS-232C spec (§10). Until then, at least render `NO ERRORS` green vs any-nonzero red instead of the raw string. |
| **Connection** | Add a relative "updated 8 s ago" in the cell or as a subtle trailing label; turn the dot grey/hollow when the last poll is older than ~2× the poll interval (data is stale, not necessarily offline). Needs `lastPolledAt` on the model (§11). |
| **Power** | If the projector reports warming/cooling sub-states, show them distinctly (amber, animated) rather than collapsing to ON/STANDBY. Needs confirmation of the extended `QPW` values (§10). |
| **Truncated text** | Any ellipsized cell gets a hover `Tooltip` (reuse `custom_tooltip.dart`) with the full value. |
| **Value change** | On a poll that changes a cell's value, flash the cell background from `tertiary` and fade out over ~600 ms (`TweenAnimationBuilder`) so operators catch changes without staring. Especially: went offline, new error, shutter/power flip. |

---

## 7. `[ ]` Filtering & search

- **Search field** in the monitoring toolbar: substring match over
  name / IP / serial / group name. `Ctrl/Cmd+F` focuses it; `Esc` clears.
- **Filter chips**: `Online only`, `Has errors`, `Powered on`, `Shutter open`,
  plus one chip per group. Chips are OR within a facet, AND across facets.
- Row count / "showing X of Y" indicator.
- Filtering happens before sort; selection & keyboard nav operate on the
  filtered set. Not persisted (session-only) unless we decide otherwise.

---

## 8. `[ ]` Group awareness

- **"Group" column**: colored dot from `ProjectorGroup.color` + group name;
  "—" for ungrouped. Sortable.
- **Optional group sections**: when sorted by Group, render sticky
  sub-headers ("Stage Left — 6 projectors, 1 error") with collapse/expand.
  Bigger lift against the current flat `ListView.builder`; defer to a later
  phase.
- Group-level roll-up in the section header: worst status wins (error > warn >
  ok), count online / total.

---

## 9. `[ ]` Export & copy

- Right-click a row → `Copy row` (TSV) / `Copy IP` / `Copy serial`.
- Toolbar → `Export CSV…` writes the **visible** columns & filtered/sorted
  rows to a file the user picks. Reuse the existing file-dialog + config-dir
  plumbing.
- `Ctrl/Cmd+C` copies the current selection as TSV (paste into a sheet).

---

## 10. Panasonic MMCS feature comparison

What Panasonic **Multi Monitoring & Control Software** surfaces per projector,
vs. this app. "Cmd?" = we already have the NTCONTROL command in
`.claude/skills/panasonic-ntcontrol/references/command_reference.md`.

| MMCS monitors | We show it | Cmd? | Proposal |
|---|---|---|---|
| Model name | ✅ (`QID`) | yes | — |
| Serial number | ✅ (`QSN`) | yes | — |
| Power status | ✅ (`QPW`) | yes | Add warming/cooling sub-states if `QPW` returns `002/003` on these models — **need confirmation** |
| Shutter / AV mute | ✅ (`QSH`) | yes | — |
| Input terminal | ✅ (`QIN`) | yes | — |
| Signal present | ✅ (`QVX:NSGS1`) | yes | — |
| **Signal format** (resolution / Hz) | ❌ | no | Column showing `1920×1080 @ 60`; **need command** (likely another `QVX:` key) |
| Intake air temp | ✅ (`QTM:0`) | yes | Color scale — §6 |
| Exhaust / optics temp | ✅ (`QTM:1`) | yes | Color scale — §6 |
| **Internal / around-lamp temp** | ❌ | no | **Need command** |
| Light-source runtime | ✅ (`QVX:RTMS1`) | yes | Grouped thousands — §6 |
| **Light-source remaining %** | ❌ | no | Wear bar; **need command** |
| **Per-lamp / per-module status** (multi-light) | ❌ | no | **Need command**; only relevant on multi-light models |
| **Filter runtime / remaining** | ❌ | no | Column + remaining bar; **need command** |
| **Fan status** | ❌ | no | Part of error decode or its own cell; **need command / bit table** |
| Error / warning status | ⚠️ raw bitmask (`QVX:ERRS2`) | yes | Decode to labeled severity chips — §6; **need the per-bit meaning table** |
| **Self-test result** (`SELF`-style) | ❌ | no | On-demand "Run self-test" action per row; **need command** |
| **Cooling-down remaining time** | ❌ | no | Show in Power cell during cooldown; **need command** |
| AC input voltage | ✅ (`QVX:VMOI2`) | yes | Out-of-range flag — §6 |
| **Brightness / light output %** | ❌ | no | Column; **need command** (brightness dialog may already have it — check `brightness_control_dialog.dart`) |
| **Firmware / main version** | ❌ | no | Column (rarely changes; hidden by default); **need command** |
| IP address | ✅ | n/a | — |
| **MAC address** | ❌ | no | Low value; **need command** |
| Network connection status | ✅ (`connectionStatus`) | n/a | Add "last updated" + stale state — §6 |
| **Last-communication timestamp** | ❌ | n/a | `lastPolledAt` on model — §11 |
| Groups / tree organization | ⚠️ groups exist, not in table | n/a | Group column + sections — §8 |
| **Location / contact / notes** (user metadata) | ❌ | n/a | Free-text `note` / `location` field on `ProjectorNode`, editable in the Edit dialog, optional column |
| Error history with timestamps | ⚠️ `eventLogProvider` has app-side log | n/a | Add a per-row "History" popover filtered from `eventLogProvider` |
| Email notification on error | ❌ | n/a | Out of scope here (OSC broadcast already exists for show-control); note for backlog |

**Commands to request from the user** (skill rule: never guess a command
string). Ideally the RS-232C / NTCONTROL command list PDF for the target
models, or individually:

1. `ERRS2` bitmask — meaning of each of the 12 positions (temp / fan / filter /
   light source / shutter / cover / …) and the value scale (0/1 vs 0–2 severity).
2. `QPW` extended return values for warming / cooling, if any.
3. Filter runtime + filter remaining.
4. Light-source remaining % (and per-unit status on multi-light models).
5. Signal format / resolution / vertical frequency.
6. Brightness / light-output % (may already be in `brightness_control_dialog.dart`).
7. Firmware version.
8. Cooling-down remaining time.
9. Self-test trigger + result parsing.

Everything from category "yes" above can ship without any protocol work.

---

## 11. Data model / provider / settings changes

### `ProjectorNode` (`projector_node.dart`, Freezed — regen after)

- Add numeric telemetry so sort & color scales key off real numbers, keep the
  display strings or derive them in the cell:
  - `int? intakeTempC`, `int? exhaustTempC`, `int? acVolts`, `int? runtimeHours`
- `DateTime? lastPolledAt` — "updated Xs ago" + stale detection.
- `String errorBits` (raw `ERRS2` payload) kept separate from a decoded
  `List<ProjectorFault>` (or keep decoding in the cell).
- Optional user metadata: `String note`, `String location`.
- `ProjectorNode` doc comment currently says "21-field model" (per CLAUDE.md) —
  update the count and the CLAUDE.md line when fields change.

### `workspace_provider.dart`

- In the telemetry-apply block (~L484–579) set the new numeric fields
  alongside the existing display strings, and stamp `lastPolledAt`.
- No change to polling cadence / batching (that's the `features/fixes` work).

### `AppSettings` (`app_settings_provider.dart`) — same JSON-file pattern

```text
Set<String>         monitoringColumns        // visible column ids
List<String>        monitoringColumnOrder    // display order (all known ids)
Map<String,double>  monitoringColumnWidths   // id -> px width (from auto-fit / drag)
String              monitoringSortColumnId
bool                monitoringSortAscending
bool                monitoringFitToWidth     // default true
double              monitoringRowHeight      // or an enum: compact/standard/comfortable
```

Add matching `copyWith` / `toJson` / `fromJson` entries and `set…` methods
(per-column toggle, order, presets), mirroring the existing ones. Both
`monitoringColumns` and `monitoringColumnOrder` serialize as JSON lists.
Session-only (not persisted): quick-search text, filter chips,
hovered / focused row.

### New: `MonitoringColumn` descriptor + a small controller

- A `const` list of column descriptors (id, label, default/min width,
  `String Function(ProjectorNode, groups)` value, `Comparable Function(...)`
  sort key, `Widget Function(...)` cell).
- Resolve the render list = `monitoringColumnOrder` filtered to
  `monitoringColumns`, then intersected with the descriptor set — drop unknown
  ids gracefully, and **append any new built-in column** the user's saved
  order/visibility hasn't seen yet (so a future added column shows up rather
  than silently staying hidden).

---

## 12. Suggested phasing

### Phase 1 — quick wins, no protocol work

1. `MonitoringColumn` descriptor refactor (§1 / §11) — prerequisite for the
   rest of Phase 1.
2. **"Monitoring Table" submenu under View** — per-field show/hide + presets
   + "Fit columns to window" toggle (§1 / §2).
3. Header interactions (§2): **single-click sort** (flip asc/desc on repeat),
   **double-click auto-fit width**, **drag to reorder columns**.
4. Row hover highlight (§3).
5. Row selection wired to `selectionProvider`, two-way sync with Controls +
   selected-command actions + left accent bar (§4).
6. Fix numeric sort (add numeric fields, §11) — small but removes a real bug.
7. Errors cell: at least green `NO ERRORS` vs red any-fault; truncation
   tooltips everywhere (§6).
8. Group column (§8, plain sortable column only).

### Phase 2

9. Manual column drag-resize on the header edge (§2).
10. Search field + filter chips + "showing X of Y" (§7).
11. Thermal color scale + AC-voltage flag + value-change flash (§6).
12. `lastPolledAt` + stale indicator (§6).
13. Keyboard navigation (§5).
14. Copy row / Export CSV (§9).
15. Density toggle (compact/standard/comfortable row height).

### Phase 3 — needs command strings from the user

16. `ERRS2` bitmask → severity chips with breakdown.
17. Filter runtime, light-source remaining %, signal format, brightness %,
    firmware, cooling time, self-test — as columns / row actions.
18. Group sections with sticky sub-headers + roll-up (§8).
19. Per-row error-history popover from `eventLogProvider`.
20. User metadata (note / location) field + column.

---

## 13. Decisions

Resolved with the user — folded into the sections above:

1. **Single-click sort** — single click sorts; a repeat click on the same
   column flips ascending / descending. (§2)
2. **Double-click** — auto-fits that column's width **only**; it does not also
   sort. Accept Flutter's ~300 ms tap/double-tap disambiguation on the sort
   click. (§2)
3. **Column reordering** — yes, by **dragging header cells** (drag-and-drop),
   not menu up/down items. (§1, §2)
4. **Fit-to-width default** — keep the current proportional auto-scale as the
   default (ON). (§2)
5. **Selection** — Monitoring is interactive and shares one selection with the
   Controls view, both directions; it also surfaces the selected-command
   actions. No canvas auto-scroll from Monitoring for now. (§4)
6. **Thermal thresholds** — hard-coded defaults, no Preferences UI. (§6)
7. *(Point 7 was the "collapsible group sections vs. plain Group column"
   question.)* — Ship the **plain sortable Group column** now (§8); collapsible
   group sections stay deferred to Phase 3 and may be dropped entirely.
8. **View format** — table view only. No separate "wall view" / status-tile
   grid.
</content>
</invoke>
