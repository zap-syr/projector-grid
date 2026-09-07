# Monitoring Table — UI/UX Improvement Plan

Working doc for improvements to the Monitoring view (`monitoring_table.dart`).
Status legend: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not applicable

Scope: Sections are ordered roughly by value-for-effort; a suggested phasing is
at the end.

**Implementation status (2026-09-07):** Phase 1 landed in commit `c921579`
("feat: configurable monitoring table columns, sort, hover and selection") on
`features/monitoring`. Done: column-descriptor refactor, the View ▸ Monitoring
Table submenu, header single-click sort / double-click auto-fit / drag-reorder,
row hover highlight, the errors-cell green/red + truncation tooltips, the Group
column, and a numeric-aware sort fix. Row selection wired to `selectionProvider`
(§4) was implemented and then **removed** at the user's request — the Monitoring
table is view-only.

Since then: the left→right column-reorder no-op bug was fixed (commit `2556b8d`),
and **Phase 2 item 9** — manual header-edge column drag-resize (`_ColumnResizeHandle`)
— has been implemented (uncommitted at time of writing). Rest of Phase 2 and all
of Phase 3 not started.

---

## 0. Where the table is today

`MonitoringTable` (`lib/features/workspace/presentation/widgets/monitoring_table.dart`)

*Post-c921579 — this section originally described the pre-Phase-1 state; updated
to match what shipped.*

- `ConsumerStatefulWidget`. **14 columns defined as `_Column` descriptors**
  (`_allColumns`); the visible/ordered subset comes from
  `AppSettings.monitoringColumns` (empty ⇒ `_defaultVisibleIds`, all but Group).
- Per-column width = `monitoringColumnWidths[id]` (set by header double-click
  auto-fit) or the descriptor default.
- Manual sticky header, three synced `ScrollController`s, `ListView.builder`
  with `itemExtent: 40` — virtualized, so row count scales fine.
- Sort: single-click a header → asc, repeat → flip; keyed off column id, with a
  sort cache. Numeric columns use a `_leadingNum` key; IP uses a padded quad.
- Header cells are `Draggable`/`DragTarget` → drag to reorder columns.
- Each row is a `_MonitoringRow` `StatefulWidget` with a local hover highlight;
  alt-row striping via `index.isOdd`. No row selection.
- `monitoringFitToWidth` (default ON): when the viewport is wider than the
  column total, columns scale up proportionally; otherwise horizontal scroll.

### Limitations

| Area | Gap | Status |
|---|---|---|
| Column choice | User can't hide/show/reorder columns | `[x]` menu show/hide + presets + header drag-reorder (c921579) |
| Column width | Not user-adjustable | `[x]` double-click auto-fit, header-edge drag-resize, fit-to-window toggle |
| Row feedback | No hover highlight, no row selection, no keyboard nav | `[~]` hover highlight done; selection deliberately removed; keyboard nav still Phase 2 |
| Cross-view link | Table ignores `selectionProvider` | `[dropped]` Monitoring table is view-only by decision |
| Grouping | No "Group" column and no group sections | `[~]` sortable Group column added; sections still Phase 3 |
| Errors cell | Dumps the raw 12-char `ERRS2` bitmask — not human-readable | `[~]` green `NO ERRORS` / red raw string; full chip decode still Phase 3 |
| Thermals | Plain text; no warm/hot color cue | `[ ]` Phase 2 |
| Filtering | No search / no "errors only" / "online only" | `[ ]` Phase 2 |
| Freshness | No "last updated" indication; stale data looks identical to fresh | `[ ]` Phase 2 |
| Export | No copy / CSV | `[ ]` Phase 2 |

### Known bug to fix along the way

`[x]` **Fixed (c921579)** — but via parse-on-sort, not model fields. Numeric-
looking columns used to **sort lexically** (`"25°C" < "7°C"`, `"1000H" < "999H"`)
because values are stored as display strings. Now the affected columns use a
`_leadingNum` sort key (regex-extract the leading number) and IP uses a
zero-padded dotted-quad key. Carrying real numeric telemetry on the model (§11)
is still the "proper" fix and stays needed for the §6 color scales — deferred.

---

## 1. `[x]` User-selectable telemetry columns — via the View menu

**Done (c921579).** `_Column` descriptor list is the single source of truth;
`MonitoringTable` exposes `allColumnIds` / `labelFor` / `resolveVisible` /
`toggledColumn` / `presets` / `showAllColumns` for the menu. `top_menu_bar.dart`
and `mac_menu_bar.dart` both render a "Monitoring Table" submenu under View with
per-field checkboxes, the Essentials / Thermal / Signal presets, "Show all
columns", and the "Fit columns to window" toggle. Persisted via
`monitoringColumns` (ordered visible id list — order and visibility are one list,
not the separate `monitoringColumnOrder` this section first proposed).

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

## 2. `[x]` Header interactions — sort, auto-fit, reorder

**Done (c921579).** Header cell = `GestureDetector` (`onTap` sort with asc/desc
flip on repeat, `onDoubleTap` `_autoFitColumn` via `TextPainter` measure, clamped
60–600 px) wrapped in `Draggable`/`DragTarget` for drag-to-reorder (faded
`_HeaderDragFeedback` chip, drop-target tint). "Fit columns to window" toggle
(`monitoringFitToWidth`, default ON) does the proportional scale-to-viewport.
Widths persist in `monitoringColumnWidths`.

**Manual edge drag-resize — done (Phase 2, §12.9).** `_ColumnResizeHandle` is a
12 px opaque zone `Positioned` on each header cell's right edge
(`SystemMouseCursors.resizeColumn`). Its own `onHorizontalDrag*` handlers take the
pointer before the reorder `Draggable`. Drag is transient in
`_MonitoringTableState` (`_resizeColId` / `_resizeAccumDx`); the final base width
is written to `monitoringColumnWidths` once on drag end, not per pointer move.
When fit-to-window was scaling widths at drag start, `_resizeBaseFor` inverts the
proportional scale (`b = e·B/(V−e)`) so the edge tracks the cursor, falling back
to `base == on-screen width` once the columns no longer fit — the two branches
meet continuously at that boundary.

**Resize hairline — finalised look (mockup-approved).** The table keeps its
original flat appearance: **no line between column headers at rest**, and **no
vertical lines in the body** (zebra + row hover only). The single horizontal
`Divider` under the header row stays. The resize affordance is invisible until
the pointer is over the 12 px zone, where a **1 px `outlineVariant` hairline set
3 px inside the column edge** fades in (~120 ms); while dragging it is **2 px in
`primary`**. Earlier full-height grid-line / per-column-border versions were
tried and rejected.

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
- `[x]` A 12 px drag zone on the header cell's right edge
  (`SystemMouseCursors.resizeColumn`) for manual width drag — invisible at rest,
  hover shows a hairline inset 3 px from the edge. See the "Manual edge
  drag-resize" and "Resize hairline" notes above.

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

## 3. `[x]` Row hover highlight

**Done (c921579).** Each row is its own `_MonitoringRow` `StatefulWidget` so
hover repaints stay local (not a shared `_hoveredRow` on the table). `MouseRegion`
`onEnter`/`onExit` → local `_hovered` bool; background resolves hover
(`surfaceContainerHighest`) > stripe > transparent. No hover animation added; no
column hover.

**Goal:** make it obvious which row the cursor is on across the visible columns.

---

## 4. `[dropped]` Row selection wired to `selectionProvider`

**Implemented in c921579, then removed at the user's request.** The Monitoring
table is view-only: no row click / Ctrl / Shift selection, no `selectionProvider`
wiring, no `Esc` / `Ctrl+A`, no left accent bar, no selected-command actions. The
removal took out `_onRowTap`, `_selectAllVisible`, the `CallbackShortcuts` +
`FocusNode`, and the `selected`/accent params on `_MonitoringRow`. Hover
highlight (§3), sort, and column reorder/auto-fit stay.

**Original goal (not pursued):** the Monitoring view becomes interactive and
stays fully in sync with the Controls view — one shared selection, both
directions.

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

## 6. `[~]` Cell rendering upgrades

**Partly done (c921579):** the Errors "green `NO ERRORS` vs red any-fault" fallback
and the truncation `Tooltip` (via `_CellText`, shown only when actually
ellipsized) rows below are shipped. Everything else in this section is pending.

| Cell | Proposal |
|---|---|
| **Intake / Exhaust temp** | Parse to a number; color the text/`chip` on a green→amber→red scale with **hard-coded** thresholds — no Preferences UI (decided). Defaults: amber ≥ 35 °C intake / ≥ 45 °C exhaust, red ≥ 45 / ≥ 60 (tune against model specs before shipping). Optional 2 px severity bar under the value. |
| **Runtime** | Show `1,234 h` (grouped thousands). If a light-source max is known (needs a command, §10), add a thin wear bar + remaining %. |
| **AC Voltage** | Flag out-of-range (e.g. < 100 V or > 130 V on a 120 V nominal) amber. |
| **Errors** | `[x]` green `NO ERRORS` vs red raw string is shipped (`_errorsCell`, `-` passthrough). `[ ]` still to do: decode the `ERRS2` 12-char bitmask into labeled severity chips — Temperature / Fan / Air filter / Light source / Shutter / Cover / Other — with a breakdown tooltip. Needs the per-position bit meaning table from the model's RS-232C spec (§10). |
| **Connection** | Add a relative "updated 8 s ago" in the cell or as a subtle trailing label; turn the dot grey/hollow when the last poll is older than ~2× the poll interval (data is stale, not necessarily offline). Needs `lastPolledAt` on the model (§11). |
| **Power** | If the projector reports warming/cooling sub-states, show them distinctly (amber, animated) rather than collapsing to ON/STANDBY. Needs confirmation of the extended `QPW` values (§10). |
| **Truncated text** | `[x]` Done — `_CellText` measures with `TextPainter` and wraps in a `Tooltip` (full value) only when the text is actually ellipsized. |
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

## 8. `[~]` Group awareness

- `[x]` **"Group" column** (c921579): colored dot from `ProjectorGroup.color` +
  group name; "—" for ungrouped; sortable (ungrouped sorts last). Off by default
  in the column menu. Group map resolved once per build from
  `workspaceProvider.notifier.groups`.
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
[x] List<String>        monitoringColumns        // ordered visible column ids ("" => table default set/order)
[x] Map<String,double>  monitoringColumnWidths   // id -> px width (from auto-fit)
[x] String              monitoringSortColumnId    // default 'ip'
[x] bool                monitoringSortAscending   // default true
[x] bool                monitoringFitToWidth      // default true
[ ] double              monitoringRowHeight       // density toggle — Phase 2 (§12.15)
```

`[x]` **Done (c921579):** the five fields above, with `copyWith` / `toJson` /
`fromJson` entries and `setMonitoringColumns` / `setMonitoringColumnWidth` /
`setMonitoringSort` / `setMonitoringFitToWidth` methods. `monitoringColumns` is a
**single ordered visible list** — the separate `monitoringColumnOrder` /
`Set<String>` split this section first proposed was not used; an empty list means
"table default". No preset method on the notifier — the menu just calls
`setMonitoringColumns` with the preset's list. Session-only (not persisted):
hovered row, drag-over column.

### `[x]` `_Column` descriptor + resolution (c921579)

- `_Column` (id, label, `defaultWidth`, `iconPad`, `text`, `sortKey`, `cell`);
  `_allColumns` is the 14-entry `static final` list in canonical order,
  `_columnsById` the lookup, `_defaultVisibleIds` the pre-customisation subset
  (all except `group`). `_minColWidth = 60`.
- `_resolveColumns(saved)` = saved ids (or `_defaultVisibleIds` when empty),
  mapped through `_columnsById`, unknown ids dropped, falls back to defaults if
  nothing resolves. A newly-added built-in only appears automatically for users
  whose saved list is empty; otherwise it stays hidden until re-picked (the
  "append unseen built-ins" idea was not implemented).

---

## 12. Suggested phasing

### Phase 1 — quick wins, no protocol work — **DONE (c921579), except item 5**

1. `[x]` `_Column` descriptor refactor (§1 / §11).
2. `[x]` **"Monitoring Table" submenu under View** — per-field show/hide +
   presets + "Fit columns to window" toggle (§1 / §2).
3. `[x]` Header interactions (§2): single-click sort (flip asc/desc on repeat),
   double-click auto-fit width, drag to reorder columns.
4. `[x]` Row hover highlight (§3).
5. `[dropped]` Row selection wired to `selectionProvider` — implemented, then
   removed at the user's request; Monitoring table is view-only (§4).
6. `[x]` Numeric sort fixed — via parse-on-sort keys, not model fields (§11 /
   "Known bug"). Real numeric telemetry fields still deferred.
7. `[x]` Errors cell green `NO ERRORS` vs red; truncation tooltips everywhere
   (§6). (Full `ERRS2` chip decode still Phase 3.)
8. `[x]` Group column (§8, plain sortable column only).

### Phase 2

9. `[x]` Manual column drag-resize on the header edge (§2) — `_ColumnResizeHandle`,
   scale-aware, persists to `monitoringColumnWidths` on drag end.
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
5. **Selection** — *superseded.* Originally: Monitoring shares one selection with
   Controls, both directions, plus selected-command actions. Built in c921579,
   then the user asked to remove row selection entirely — the Monitoring table
   is now **view-only** (hover highlight, sort, column config only). (§4)
6. **Thermal thresholds** — hard-coded defaults, no Preferences UI. (§6)
7. *(Point 7 was the "collapsible group sections vs. plain Group column"
   question.)* — Ship the **plain sortable Group column** now (§8); collapsible
   group sections stay deferred to Phase 3 and may be dropped entirely.
8. **View format** — table view only. No separate "wall view" / status-tile
   grid.
</content>
</invoke>
