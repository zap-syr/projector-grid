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
— landed in `dfd8b88` / `ef9522b`.

**Phase 2 item 11 — partial (2026-09-08, commits `2d75be4` + `b0ab12a`):**

- `[x]` **Thermal colour scale** (§6). Intake/Exhaust cell *text* turns amber
  (`_warnText` `#FFB26A00`, a readable amber — the pale `Colors.amber` fails
  contrast as text) past a warm threshold, red past a hot one. Normal and
  unreadable (`-`, `Timeout`) stay the default colour; no severity bar. Hard-
  coded consts in `monitoring_table.dart`: intake amber ≥ 40 °C / red ≥ 45 °C
  (matches the 0–45 °C operating spec — fault ~45, shutdown ~50); exhaust amber
  ≥ 55 °C / red ≥ 65 °C — **Panasonic publishes no numeric limit for `QTM:1`**
  (only the qualitative TEMP indicator), so this is a deliberately high anti-
  false-alarm heuristic, tune once there is field data. Parse-on-render via
  `_leadingNum`, no new model fields.
- `[x]` **Status label colours** (not in the original plan). Power / Shutter /
  Connection labels now carry their icon's colour — green on / open / online,
  red standby / closed / offline, amber auth-error.
- `[x]` **Light Runtime column** (§10 light-source runtime + §6 grouped
  thousands). New `QVX:LRTS3=00` telemetry query (`String lightRuntime` on
  `ProjectorNode`); reply is `LRTS3=00:<hours>`, same unit as `RTMS1`. The old
  "Runtime" column is renamed **"Projector Runtime"** and the new **"Light
  Runtime"** column follows it; both now render with thousands separators
  (`1,644H`).
- `[ ]` **AC-voltage out-of-range flag** — deferred at the user's request
  (needs an auto-band or per-node nominal; see the working notes).
- `[ ]` **Value-change flash** — deferred at the user's request.

**Phase 2 item 15 — done (2026-09-08, commits `7af1eba` + `37da5d1`):** row
density presets (`MonitoringDensity` enum), a non-collapsing **Merge into
groups** toggle (`_GroupHeaderRow`), and the View ▸ Monitoring Table submenu
reorganised into sub-submenus (Columns / Presets / Row density) plus the
Fit-to-window and Merge toggles.

Remaining Phase 2 (items 10, 12–14, and the AC-flag / flash half of 11) and all
of Phase 3 not started.

---

## 0. Where the table is today

`MonitoringTable` (`lib/features/workspace/presentation/widgets/monitoring_table.dart`)

*Post-c921579 — this section originally described the pre-Phase-1 state; updated
to match what shipped.*

- `ConsumerStatefulWidget`. **15 columns defined as `_Column` descriptors**
  (`_allColumns` — Light Runtime added in `2d75be4`); the visible/ordered subset
  comes from `AppSettings.monitoringColumns` (empty ⇒ `_defaultVisibleIds`, all
  but Group).
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
| Grouping | No "Group" column and no group sections | `[x]` sortable Group column + non-collapsing "Merge into groups" toggle; only collapsible sections remain (Phase 3) |
| Errors cell | Dumps the raw 12-char `ERRS2` bitmask — not human-readable | `[~]` green `NO ERRORS` / red raw string; full chip decode still Phase 3 |
| Thermals | Plain text; no warm/hot color cue | `[x]` amber/red text tint past hard-coded thresholds (`b0ab12a`) |
| Filtering | No search / no "errors only" / "online only" | `[ ]` Phase 2 |
| Freshness | No "last updated" indication; stale data looks identical to fresh | `[ ]` Phase 2 |
| Export | No copy / CSV | `[ ]` Phase 2 |
| Density | Fixed 40 px rows | `[x]` compact / standard / comfortable presets (`7af1eba`) |

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
pointer before the reorder `Draggable`; its `onDoubleTap` runs the column's
auto-fit (this is where auto-fit lives now — see §2 Implementation). Drag is
transient in `_MonitoringTableState` (`_resizeColId` / `_resizeAccumDx`); the
final base width is written to `monitoringColumnWidths` once on drag end, not per
pointer move.
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
  already-sorted column **flips ascending / descending**. Fires with no delay —
  the header label has no double-tap handler. (Decided.)
- **Double click on the column's right edge** (the resize zone, not the label)
  → **auto-fit that column's width only** to its widest currently-rendered
  value. Desktop "double-click the separator to fit" idiom; keeps sort and
  auto-fit on physically separate targets so neither gesture waits on the
  other. (Decided.)
- **Drag a header cell left/right → reorder columns.** Drop between two other
  headers to move it there; the body rows follow the new order live.
  (Decided — header drag-and-drop, not menu up/down items.)
- Menu toggle **"Fit columns to window"** (default ON — decided), in the
  "Monitoring Table" submenu:
  - ON  → columns scale proportionally to fill the width (today's behavior);
          an auto-fit / manual width then acts as a weight.
  - OFF → widths are honored in pixels, horizontal scroll as needed.
- `[x]` A 12 px drag zone on the header cell's right edge
  (`SystemMouseCursors.resizeColumn`) — drag to resize, **double-click to
  auto-fit**. Invisible at rest; hover shows a hairline inset 3 px from the
  edge. See the "Manual edge drag-resize" and "Resize hairline" notes above.

### Implementation

- `[x]` The header label's `GestureDetector` has **only** `onTap` (→
  `_onHeaderTap`, plain sort). No `onDoubleTap` anywhere on the label — putting
  both on one detector made every single click wait out Flutter's ~300 ms
  tap/double-tap disambiguation, which was noticeable on the sort. Auto-fit
  moved to `_ColumnResizeHandle.onDoubleTap` on the right-edge zone: the two
  gestures now sit on separate widgets, so the sort click resolves instantly and
  there is no revert/flash. (An earlier manual-detect-and-revert version was
  tried and rejected.)
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
ellipsized) rows below are shipped. The thermal colour scale and grouped-thousands
runtime shipped in `2d75be4` + `b0ab12a`. Everything else in this section is pending.

| Cell | Proposal |
|---|---|
| **Intake / Exhaust temp** | `[x]` Shipped (`b0ab12a`). `_tempTint` parses the leading number (`_leadingNum`) and tints the cell *text* amber (`_warnText`) / red past **hard-coded** thresholds in `monitoring_table.dart` — no Preferences UI (decided). Intake amber ≥ 40 °C / red ≥ 45 °C; exhaust amber ≥ 55 °C / red ≥ 65 °C (Panasonic gives no numeric `QTM:1` limit — heuristic, tune with field data). Normal / `-` uncoloured. No severity bar (dropped — keeps the flat look). |
| **Runtime** | `[x]` Grouped thousands shipped (`2d75be4` — `int.tryParse` + `_groupThousands`, non-numeric passthrough). "Runtime" split into **Projector Runtime** (`RTMS1`) and **Light Runtime** (`LRTS3=00`) columns. `[ ]` Wear bar + remaining % still needs a light-source-max command (§10). |
| **AC Voltage** | `[ ]` Deferred. Flag out-of-range amber — but a fixed `< 100 / > 130` window is wrong for the 200–240 V gear this app mostly talks to; needs an auto-band (≈100–120 vs ≈200–240) or a per-node nominal. Not started at the user's request. |
| **Errors** | `[x]` green `NO ERRORS` vs red raw string is shipped (`_errorsCell`, `-` passthrough). `[ ]` still to do: decode the `ERRS2` 12-char bitmask into labeled severity chips — Temperature / Fan / Air filter / Light source / Shutter / Cover / Other — with a breakdown tooltip. Needs the per-position bit meaning table from the model's RS-232C spec (§10). |
| **Connection** | Add a relative "updated 8 s ago" in the cell or as a subtle trailing label; turn the dot grey/hollow when the last poll is older than ~2× the poll interval (data is stale, not necessarily offline). Needs `lastPolledAt` on the model (§11). |
| **Power** | If the projector reports warming/cooling sub-states, show them distinctly (amber, animated) rather than collapsing to ON/STANDBY. Needs confirmation of the extended `QPW` values (§10). |
| **Truncated text** | `[x]` Done — `_CellText` measures with `TextPainter` and wraps in a `Tooltip` (full value) only when the text is actually ellipsized. |
| **Value change** | `[ ]` Deferred at the user's request. On a poll that changes a cell's value, flash the cell background from `tertiary` and fade out over ~600 ms (`TweenAnimationBuilder`) so operators catch changes without staring. Especially: went offline, new error, shutter/power flip. |
| **Power / Shutter / Connection label** | `[x]` Shipped (`b0ab12a`, not in the original plan). The label text now carries its icon colour — green on / open / online, red standby / closed / offline, amber (`_warnText`) auth-error. |

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
- `[x]` **"Merge into groups"** (`7af1eba`): a plain View-menu checkbox
  (`monitoringGroupBy`, off by default). Rows are clustered under a
  **non-collapsing** `_GroupHeaderRow` (colour swatch / hollow dot for
  Ungrouped, name, `N projectors`, worst-status `_StatusPill`). Clusters
  ordered by group name; ungrouped and orphaned-groupId nodes trail last. The
  sort still applies inside each cluster; zebra parity resets per cluster. The
  standalone Group column auto-hides while merged. Implemented as a flattened
  `List<_Entry>` (`_HeaderEntry` / `_NodeEntry`) so the header is one row tall
  and the body keeps a single `itemExtent` — no `ListView` rework. **No
  collapse/expand** (decided — §13.7).
- Group-header roll-up: worst status wins (error > auth error > offline);
  healthy groups get no pill. Online/total counts not shown (kept minimal).

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
| Intake air temp | ✅ (`QTM:0`) | yes | `[x]` Colour scale shipped — §6 |
| Exhaust / optics temp | ✅ (`QTM:1`) | yes | `[x]` Colour scale shipped — §6 |
| **Internal / around-lamp temp** | ❌ | no | **Need command** |
| Projector runtime | ✅ (`QVX:RTMS1`) | yes | `[x]` "Projector Runtime" column, grouped thousands — §6 |
| Light-source runtime | ✅ (`QVX:LRTS3=00`) | yes | `[x]` "Light Runtime" column shipped (`2d75be4`) — reply `LRTS3=00:<hours>`, same unit as `RTMS1` |
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

- `[x]` `String lightRuntime` added (`2d75be4`) — display string from
  `QVX:LRTS3=00`, parsed/formatted in the provider like `runtime`.
- Add numeric telemetry so sort & color scales key off real numbers, keep the
  display strings or derive them in the cell:
  - `int? intakeTempC`, `int? exhaustTempC`, `int? acVolts`, `int? runtimeHours`
  - *Not done* — the thermal scale (§6) currently parses the display string
    on render (`_leadingNum`), consistent with how sort already works.
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
[x] MonitoringDensity   monitoringDensity         // compact|standard|comfortable, default standard (§12.15)
[x] bool                monitoringGroupBy         // "Merge into groups", default false (§8)
```

`[x]` **Density + group merge (`7af1eba`):** `monitoringDensity` is an enum
(compact / standard / comfortable) rather than the raw `double
monitoringRowHeight` this section first proposed — one preset drives row
height, header height and horizontal padding together (compact also shrinks the
body font). `standard` keeps the pre-density metrics so nothing shifts for
users who never open the setting. `setMonitoringDensity` / `setMonitoringGroupBy`
on the notifier; both persisted.

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
10. Search field + filter chips + "showing X of Y" (§7). — *deferred; user
    still weighing whether it's worth it.*
11. `[~]` Thermal color scale + AC-voltage flag + value-change flash (§6).
    `[x]` Thermal colour scale (intake 40/45 °C, exhaust 55/65 °C) + status
    label colours + Light Runtime column (`2d75be4` + `b0ab12a`).
    `[ ]` AC-voltage flag and value-change flash — deferred at the user's
    request.
12. `lastPolledAt` + stale indicator (§6).
13. Keyboard navigation (§5).
14. Copy row / Export CSV (§9).
15. `[x]` Density toggle + group merge + menu reorg (`7af1eba` + `37da5d1`):
    - **Density** — `MonitoringDensity` enum (compact/standard/comfortable)
      driving row + header height, padding and (compact) font, via a **Row
      density** sub-submenu.
    - **Merge into groups** — non-collapsing group clusters + `_GroupHeaderRow`
      (§8), a View-menu checkbox.
    - **Submenu reorg** — View ▸ Monitoring Table is now all sub-submenus /
      toggles: **Columns** ▸ (checkboxes — divider — Show all columns),
      **Presets** ▸, divider, **Row density** ▸, divider, Fit columns to window,
      Merge into groups.

### Phase 3 — needs command strings from the user

16. `ERRS2` bitmask → severity chips with breakdown.
17. Filter runtime, light-source remaining %, signal format, brightness %,
    firmware, cooling time, self-test — as columns / row actions.
18. `[~]` Group sections (§8). The non-collapsing **Merge into groups** variant
    shipped in Phase 2 item 15; only *collapsible* sticky sections remain here,
    and per §13.7 may be dropped.
19. Per-row error-history popover from `eventLogProvider`.
20. User metadata (note / location) field + column.

---

## 13. Decisions

Resolved with the user — folded into the sections above:

1. **Single-click sort** — single click sorts; a repeat click on the same
   column flips ascending / descending. (§2)
2. **Double-click auto-fit** — lives on the column's **right-edge resize zone**,
   not the header label. Auto-fits width only; sort is untouched. Because the
   two gestures sit on separate widgets, single-click sort fires with **no
   delay**. (§2)
3. **Column reordering** — yes, by **dragging header cells** (drag-and-drop),
   not menu up/down items. (§1, §2)
4. **Fit-to-width default** — keep the current proportional auto-scale as the
   default (ON). (§2)
5. **Selection** — *superseded.* Originally: Monitoring shares one selection with
   Controls, both directions, plus selected-command actions. Built in c921579,
   then the user asked to remove row selection entirely — the Monitoring table
   is now **view-only** (hover highlight, sort, column config only). (§4)
6. **Thermal thresholds** — hard-coded consts, no Preferences UI. Shipped
   values: intake amber ≥ 40 °C / red ≥ 45 °C (from the 0–45 °C operating
   spec); exhaust amber ≥ 55 °C / red ≥ 65 °C (no published `QTM:1` limit —
   heuristic, tune later). Tint is text-colour only; no severity bar. (§6)
7. *(Point 7 was the "collapsible group sections vs. plain Group column"
   question.)* — Shipped the **plain sortable Group column**, then a
   **non-collapsing "Merge into groups"** toggle (§8, Phase 2 item 15) at the
   user's request: rows just cluster under a group header, nothing hides.
   *Collapsible* sections stay deferred and may be dropped entirely.
8. **View format** — table view only. No separate "wall view" / status-tile
   grid.
9. **Light Runtime** — separate column from Projector Runtime, added on the
   user's request. `QVX:LRTS3=00` → `LRTS3=00:<hours>` (same unit as `RTMS1`),
   shown grouped. (§6 / §10)
10. **AC-voltage flag & value-change flash** — deferred; the user is not yet
    convinced of their value. (§6)
11. **Row density** — a 3-way enum (`MonitoringDensity`: compact / standard /
    comfortable), not a free `double` row height. `standard` == the old
    metrics. Persisted. (§11 / §12.15)
12. **Monitoring Table submenu** — everything moved into sub-submenus /
    toggles; final order Columns ▸ · Presets ▸ · — · Row density ▸ · — · Fit
    columns to window · Merge into groups. (§12.15)
