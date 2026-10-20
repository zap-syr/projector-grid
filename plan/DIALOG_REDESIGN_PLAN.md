# Dialog Redesign Plan

Status: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not doing · `[later]` deferred

Design approved by the owner on 2026-10-13. Mockups (light and dark for every board,
Geometry Correction, Edge Blending, Remote Preview, Custom Command, Keyboard Shortcuts,
About, the main toolbar, the tooltip, the control bar, the Monitoring view, the
projector card, the event log, the status bar and the alerts panels dark only; the tooltip also in light):
https://claude.ai/artifact/AL2c8Kh9aoXrrv2eUmVdcJ (canvas *Projector Grid dialogs redesign*).
Roadmap item: `ROADMAP_PLAN.md` §13 (U7).

The mockups are examples for the redesign and are not updated after a part is built: for
a part marked done, the app is the reference, and its note lists where it differs from the
boards (owner, 2026-10-17).

The redesign covers twelve dialogs in depth (Add Projectors, Edit Projector, Groups,
Scheduled Tasks, Brightness Control, Color Correction, Geometry Correction, Edge Blending,
Remote Preview, Custom Command, Keyboard Shortcuts, About), the main toolbar, the
tooltip, the control bar, the Monitoring view, the projector card on the Controls
canvas, the event log panel, the status bar and the alerts panels (§7f, §7g, §7h, §7i,
§7j, §7k, §7l, §7m), and one
change that reaches **every** dialog: the shared title bar gets an icon tile, so all dialogs
take the new look, not just the redesigned ones.

General rules carried over from the review:
- Projectors are identified by **IP address**, or model + IP (`RZ34K (192.168.0.15)`), never by
  model name alone: models repeat, so a list of names identifies nothing.
- A dialog opened for one projector shows that projector **in the title bar** (§1.1), not in
  a card in the body: the user already knows which projector they opened it for, and the
  height goes to the controls (owner, 2026-10-14).
- Mockup text is English and so is the UI text below. UI text separates with commas, colons
  and parentheses, never `·` or dashes (`ROADMAP_PLAN.md`); ranges read `0 to 255`. One
  exception: the copyright year range keeps its en dash, `© 2025–2026` (owner, 2026-10-14).
- Codes of NTCONTROL commands (`PON`, `OSH:1`, …) are not shown to the user anywhere in these
  dialogs.

---

## 1. `[x]` Shared foundation (all dialogs)

Done 2026-10-15. What landed, for the later steps to build on:
- `DialogTitleBar(icon:, title:, projectorId:, subtitle:, badges:)`; `projectorLabel(model, ip)`
  in the same file. Brightness, Color and Geometry already pass `projectorId`; Edge Blending
  and Remote Preview keep their old titles until §7a / §7b.
- Theme (`app_theme.dart`): `AppStatusColors.of(context)` (success, warning, onWarning,
  mutedMinus, mutedPlus, tooltip surface, keyCap, containers), `AppTheme.mono(style)` /
  `AppTheme.monoStyle`, dialog radius 20 in `DialogThemeData`, `TooltipThemeData` in the
  `CustomTooltip` look.
- `common/`: `confirm_dialog.dart` (`ConfirmDialog`, `confirmDestructive`), `status_pill.dart`
  (`StatusPill`, `GroupPill`, `ConnectionStatusBadge`), `segmented_tabs.dart`, `mode_tile.dart`
  (`ModeTileRow`, `ModeTile`), `dashed_border.dart`, `scroll_fade.dart`, `skeleton.dart`
  (`Skeleton`, `SkeletonPulse`), `slider_tracks.dart` (`AppSliderTrackShape`: centre zero,
  hatched limit), `step_buttons.dart` (`StepButton.minus/plus`), `debouncer.dart`,
  `key_caps.dart` (`KeyCap`, `KeyCaps`), `ip_chips.dart`; `domain/ip_ranges.dart`
  (`collapseIpRanges`, `IpRun.label(short:)`).
- Added after wave A: `common/dialog_parts.dart` — `DialogSurfaces` (body, card, editor,
  field, soft), `DialogCard` (highlighted, muted, borderColor), `DialogIconTile` (primary),
  `LabeledField` + `FieldHelp` + `dialogFieldDecoration`, `DialogFooter` (message, Cancel +
  action, or custom `actions`), `SentRightAwayNote(loading:)`, `DialogScrollBody`. Every
  redesigned dialog builds its cards, fields and footer from these.
- Icon tiles (owner, 2026-10-16, board *Icon tiles of sections and cards*, option 2): the
  title bar tile is filled (`primaryContainer`); a section or card tile inside a dialog is a
  neutral tile with a **primary icon** (`DialogIconTile`), Brightness included (its
  `primary: true` variant was dropped with the visual rules below); grey icon only when
  locked (`muted: true`).
- **Visual rules** (owner, 2026-10-16, boards *Visual rules: type, placeholders, icons,
  buttons*): one set of rules for every dialog, in the skill
  `.claude/skills/projector-grid-visual-rules/SKILL.md`. Every redesign step below follows
  it, and where this plan quotes an older size or colour the skill wins. What landed:
  UI font **Inter** (bundled, OFL; Plus Jakarta Sans, tried first, stays bundled as the
  alternative), `AppText` roles in `app_theme.dart` instead
  of `fontSize` in widgets, four text colours, the placeholder in the font of its value,
  three icon colour levels, icon sizes 14 / 16 / 18 / 20, tile radius 30 %, one filled
  button at a time, every card on `DialogSurfaces.card`. The wave A dialogs (Groups, Add
  and Edit Projector, Brightness, Custom Command, Keyboard Shortcuts, About) and the
  shared pieces were brought in line.
- **Hint text** (owner, 2026-10-16, skill §4): placeholders name the action or show the
  format, never both; no `e.g.`, no example lists, no ellipsis; no placeholder that
  repeats the label. Only the wave A dialogs were changed. **The other dialogs keep their
  hint text until their own redesign step**, which applies the rule then: Event Log
  (`Search…` → `Search log`), Scheduled Tasks (`Select a command...` → `Select command`,
  `Select a group...` → `Select group`, the command picker search below), Preferences.
- `CustomTooltip(message:, detail:, shortcut:, warning:, placement:)` with the arrow
  (§7g done); `TooltipBubble` is public for other overlays.
- Not in the foundation (they belong to one step only): `GroupColorPalette` (§3),
  `ProjectorInfoCard` (§2.6), `TargetChip` (§4).

### 1.1 Title bar with an icon
`DialogTitleBar` (`presentation/widgets/dialog_title_bar.dart`) is used by every dialog, so
changing it changes them all.

- New required parameter `icon` (`IconData`): stock `Icons.*` only. Where the mockup drew
  its own glyph (projector, trapezoid, two overlapping frames) the closest Material icon in
  the table below is used instead (owner, 2026-10-15). Layout, left to right: **icon tile** 30×30,
  radius 9, `primaryContainer` fill, icon 18 px in `onPrimaryContainer`; gap 12; title
  (`AppText.dialogTitle`, 16, weight 600, since the visual rules of 2026-10-16); close
  button 40×40, circular, `onSurfaceVariant`.
- Background stays `surfaceContainerHigh`, divider below stays. Padding `10, 8, 10, 20`
  (top, right, bottom, left).
- Still no other controls in the bar (the rule in the widget's doc comment stands).
- Dialog shape: radius **20** for every dialog (today `12` is set per dialog, e.g.
  `manage_groups_dialog.dart`). Set it once in `DialogThemeData.shape` in `app_theme.dart` and
  drop the per-dialog `shape:` overrides.

Icon per dialog (Material Symbols / `Icons.*`; final pick may change during implementation,
keep one icon per dialog family):

| Dialog | File | Icon |
|---|---|---|
| Add Projectors | `add_projector_dialog.dart` | `videocam` |
| Edit Projector | `edit_projector_dialog.dart` | `edit` |
| Manage Groups, New Group | `manage_groups_dialog.dart` | `layers` |
| Scheduled Tasks | `scheduled_tasks_dialog.dart` | `schedule` |
| Custom Command | `custom_command_dialog.dart` | `code` |
| Geometry Correction | `geometry_correction_dialog.dart` | `crop_free` |
| Color Correction | `color_correction_dialog.dart` | `palette` |
| Brightness Control | `brightness_control_dialog.dart` | `brightness_6` |
| Edge Blending | `edge_blending/edge_blending_dialog.dart` | `gradient` |
| Remote Preview | `remote_preview_dialog.dart` | `monitor` |
| Preferences | `preferences_dialog.dart` | `settings` |
| Keyboard Shortcuts | `keyboard_shortcuts_dialog.dart` | `keyboard` |
| About | `about_dialog.dart` | `info` |

**Projector in the title bar** (owner, 2026-10-14). Per-projector dialogs drop the IP from the
title (`Geometry Correction - 192.168.0.11` today, in `brightness_control_dialog.dart`,
`color_correction_dialog.dart`, `geometry_correction_dialog.dart`) and pass an optional
projector id instead. The status must stay **live** while the dialog is open (a projector can
go offline meanwhile), so the bar does not take a `ProjectorNode` snapshot: a small
`Consumer` inside it watches `workspaceProvider.select(...)` for that node's model, IP,
group and connection status only, so a polling tick doesn't rebuild the bar. The bar then
shows:
- under the title, model + IP in monospace 12 px, `onSurfaceVariant`: `RZ34K (192.168.0.41)`;
- right of the title, before ✕: the **group pill** (dot + name, only when the projector is in
  a group) and the **status badge** (Online / Offline / Wrong login, as in §2.5).

Both are read-only information, so the "no other controls" rule above stands. The bar keeps
its height (title + subtitle fit the 40 px close button). Brightness Control, Color
Correction, Geometry Correction, Edge Blending and Remote Preview use it (§5, §6, §7, §7a,
§7b; the variants for two or more projectors in §7a.1 and §7b.1).

### 1.2 Confirmation dialogs
Six confirmation `AlertDialog`s exist today: Delete Command (`control_bar.dart`), Delete
Group (`manage_groups_dialog.dart`), Delete Projectors / Delete Projector
(`projector_workspace.dart`), Delete Task (`scheduled_tasks_dialog.dart`) and Unsaved Changes
(`top_menu_bar.dart`). (Brightness Control and Remote Preview use `AlertDialog` only as their
container with a `DialogTitleBar`: both are redesigned, Brightness Control in §5, Remote
Preview in §7b.) The six move to one
shared `ConfirmDialog` (`presentation/widgets/common/confirm_dialog.dart`), the layout of the
approved *Groups: delete confirm* board:

- Width 440. Top row: round icon 40 px (destructive: `errorContainer` / `error`), title 18 px
  weight 600 (`Delete “Left wall”?`), one short subtitle line under it.
- Optional **"What changes"** box: its own surface and border, a small header, one row per
  consequence (16 px icon, bold key fact, plain rest of the sentence).
- Actions right-aligned at the bottom: *Cancel* (text) and the confirm button
  (destructive variant: filled `error`). Unsaved Changes keeps its three choices
  (neutral variant, primary icon).
- No title bar and no ✕ on confirmations: they are short and answered with the buttons / Esc.

### 1.3 Shared pieces
Under `presentation/widgets/common/`, reused across the dialogs below:
- `SegmentedTabs` — the pill tab strip (Address / IP range / Discover; Color Matching /
  Color Temperature and Edge Blending / Black Level with a state pill per tab).
- `ProjectorInfoCard` — model, IP, group chip, status badge. Edit Projector only, where it
  shows the address being edited; other per-projector dialogs use the title bar (§1.1).
- `GroupColorPalette` — §3.2.
- `IpChips` + pure `collapseIpRanges(List<String>)` in `domain/` — consecutive addresses as
  one chip (`192.168.0.10 to .49`), used by the IP range skip list and the New Group "joins"
  box.
- `StatusPill`, `TargetChip` (group dot + name, or stacked dots + "N groups").
- `ModeTile` / `ModeTileRow` — icon + label (+ optional muted line) tiles, one height per
  dialog: Brightness (60), Color Temperature (44), Geometry (46), Edge Blending (54).
- Drawing helpers with no package: `DashedBorder` (a `CustomPainter` over `PathMetric`;
  dashed New task card, empty favourite slot, mouse-action pills, offline compact tiles, the
  Edge Blending "No reply" placeholder), `ScrollFade` (`ShaderMask` driven by the scroll
  position), `Skeleton` blocks, and slider track shapes for the centre zero fill and the
  hatched part above a limit.

### 1.4 Adaptive layout (all dialogs)
Every dialog adapts to the app window, down to the smallest window the app allows (800×600,
`main.dart`); there is no separate "compact mode" (owner, 2026-10-15). Sizes in this plan
(560×594, 960×800, …) are the **maximum**, not a fixed size:
- `ConstrainedBox(maxWidth, maxHeight)` instead of a fixed `SizedBox`; with the `Dialog`
  insets the smallest window leaves about 720×550 for a dialog.
- The body scrolls when it doesn't fit (scrollbar, fade at the bottom); the title bar and
  the footer stay in place.
- Where a row can't shrink, a `LayoutBuilder` adapts it: mode tiles take shorter labels
  (full name in the tooltip), two-column grids drop to one column, a canvas card shrinks.
- Canvases (Geometry Correction §7.5, Edge Blending §7a) scale to the space they get. Drag,
  hit testing and arrow keys work in canvas coordinates through that scale, and handles keep
  their size on screen so they stay easy to grab. Test dragging at a scale below 1.
- GUI check of every dialog at 800×600 as well as at a large window.

### 1.5 Colours and type in the theme
- M3 `ColorScheme` has no success / warning roles, yet this plan uses green, amber and the
  muted red / green of the − / + buttons everywhere. They go into one
  `ThemeExtension` (`AppStatusColors`: success, warning, onWarning, mutedMinus,
  mutedPlus, …) with light and dark values in `app_theme.dart`. The hex values quoted in
  this plan (tooltip §7g, Monitoring palette §7i, card §7j) are the targets for the theme
  and its extension, not literals in widgets.
- One monospace text style for IPs, ports, commands and OSC addresses. Today widgets use
  `fontFamily: 'monospace'`, which on Windows falls back to Courier New: use
  `AppTheme.mono` with `FontFeature.tabularFigures()`. The font is **IBM Plex Mono**,
  bundled under `assets/fonts/` (Regular, Medium, SemiBold; OFL, registered with
  `LicenseRegistry`), chosen by the owner on 2026-10-15 from the *Monospace font for
  fields* boards; placeholders in mono fields use it too.
- No new packages anywhere in this plan: everything is stock Flutter plus `flutter_svg`,
  `crypto` and `package_info_plus`, which the app already has.

---

## 2. `[x]` Add Projectors

Done 2026-10-16 (wave A, fixes after the owner's check). Differs from the text below:
- Discover scans only on the **Scan** button (in the results header), not on open; a login
  edited after a scan resets the login status of the found projectors.
- IP range: the login card comes first, the range preview fills the rest of the height (its
  placeholder too). One field height for all tabs (`dialogFieldHeight`, 40); the port field
  has no "Default 1024" help.
- Login and password fields have a ✕ clear button inside (the eye comes after it); on
  Discover the login is a compact one-row card with fixed field widths.

Boards: *Add Projectors: Address / IP range, 12 addresses / IP range, 50 addresses / Discover*.
Dialog 720×640.

### 2.1 Tabs
Three tabs in a segmented strip under the title bar: **Address**, **IP range**, **Discover**
(today: two `TabBar` tabs, *Manual Add* with a Single / IP Range segmented button inside, and
*Auto Discovery*). Footer on every tab: optional message on the left, *Cancel*, primary
*Add …* button whose label carries the count (`Add projector`, `Add 10 projectors`).

### 2.2 Projector login (all tabs) — replaces the Protected mode switch
The mockup's *Protected mode* switch is **dropped**: the projector reports whether it is
protected when the app connects (`NTCONTROL 1 <token>` vs `NTCONTROL 0`), so the user never
has to turn anything on. The fields are always visible and optional:
- Card **Projector login**: lock icon, "Sent only if the projector is in protected mode",
  an **Optional** pill and a **Last used** marker (history icon).
- Login and Password side by side; Password has a show / hide button.
- **Prefilled with the last used login and password** (owner, 2026-10-13). New app setting,
  written after a successful add. Plain JSON in the config dir is fine (R2, keychain, was
  dropped).
- Discover uses a compact one-row variant: lock tile, "Projector login" / "Last used,
  optional", two narrow fields with the label inside (`Login`, `Password`).

### 2.3 Address tab
- IP address (monospace, focused on open) with an inline check under it: "Not in project
  yet" (green) or "Already in project" (error, button disabled).
- Port, default 1024, with "Default 1024" under it.

### 2.4 IP range tab
- **From** (full IP) → **To** (only the last octet editable, the first three shown as a
  greyed prefix) → **Port**.
- Preview card: "N addresses", range text (`.10 to .21`), legend *new* / *in project*.
  - Up to ~16 addresses: a strip of labelled cells (`.10`, `.11`, …), duplicates struck
    through.
  - More: a dense unlabelled strip plus an axis (`.10 … .59`).
  - Footer row of the card: "Skipped, already in project:" and chips, consecutive ones
    collapsed (`.31 to .33`).
- The add button counts only new addresses.

### 2.5 Discover tab
- Network interface dropdown (name + the interface's IP), Port, *Scan again* (tonal).
- Login row (§2.2 compact).
- Results card: "N projectors found on 192.168.0.0/24", "Scan complete" / a progress bar
  while scanning; table *checkbox · Projector · IP address · Status*. Status badges: **Online**
  (green), **No login** (non-protected projector, blue, open lock), **Wrong login** (amber,
  closed lock), **In project** (grey, row disabled and unchecked).
- Footer message "5 of 5 new selected".
- The scan already reports `online` / `unprotected` / `auth_error` per address
  (`PanasonicProtocolService.scanNetwork`), so the badges need no protocol change. The tab
  creates its own `PanasonicProtocolService()` today; it moves to `protocolServiceProvider`
  so widget tests can use `FakeProtocolService`.

### 2.6 Edit Projector
Boards: *Edit Projector*, *Edit Projector: wrong login*. Approved 2026-10-13. Same look as
Add Projectors, simpler: no tabs. Today (`edit_projector_dialog.dart`) it is three bare
outlined fields (IP, Login, Password), 400 px wide, password in plain text.

- Dialog **560×520** (560 with the wrong-login row), title bar icon `edit`.
- **Projector card** on top: projector icon tile, model name, current `IP : port` under it
  in monospace; on the right the group chip (if any) and the connection status badge
  (Online / Wrong login / No login / Offline, same badges as Discover §2.5).
- **IP address** + **Port** (110 px, "Default 1024").
  - Unchanged: "Current address" under the field.
  - Changed and free: green "Changed from 192.168.0.41, not used by another projector".
  - Taken or invalid: error under the field, *Save* disabled.
- **Projector login** card, the same as Add Projectors (§2.2) minus *Last used*: lock tile,
  "Sent only if the projector is in protected mode", *Optional*, Login + Password with a
  show / hide button (password hidden by default).
- **Wrong login** state (`ConnectionStatus.unauthorized`): status badge amber "Wrong login",
  the login card gets an amber border, focus starts in Login, and an amber row at the bottom
  of the card: "The projector rejected this login. Check the login and password."
- Footer: *Cancel* / *Save*.
- **Behaviour changes:** the port becomes editable (`ProjectorNode.port` exists; the
  `onSave` callback gains it), and the password is masked.

---

## 3. `[x]` Groups

Done 2026-10-16 (wave A, fixes after the owner's check). Differs from the text below: the
inline editor has no Delete; each group row has a red delete button (tooltip
"Delete <name>"). Deleting a group pauses the scheduled tasks that target it
(`taskHasTarget`, `detachMissingGroups`). The OSC address shown per group stays as it is
for now (owner: to revisit later).

Boards: *Groups: inline editor / delete confirm / new group / new group from context menu /
new group from context menu, 60 projectors*.

### 3.1 Manage Groups
- Width **560** (today wider), height 640. Same width as the compact New Group dialog, so the
  palette tiles come out square in both.
- Header row: "4 groups, 16 of 20 projectors assigned" and a filled **New group** button
  (was tonal; filled since the visual rules, 2026-10-16: it is the dialog's main action).
- One card with a row per group: 32 px colour swatch, name, "6 projectors", the **OSC
  address** as a small read-only monospace chip, edit button.
- **Edit inline**: the edit button expands the row in place (chevron to collapse); the
  separate *Edit Group* dialog goes. The editor has **Name** only (counter `9 / 24`) and the
  palette. **The OSC address field is not in the editor** (owner: it isn't something to copy
  here). Bottom row: *Delete group* (error text button with icon) left, *Cancel* / *Save*
  right.
- Known, accepted: a long group name gives a long OSC chip; the name then ellipsizes.

### 3.2 Colour palette
- **16 hues × 3 tones = 48 colours** (was 8 × 3): red, orange, amber, yellow, lime, green,
  emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink; rows light (Tailwind
  400), base (500), dark (700).
- The existing 24 colours are all in the new set, so saved projects keep their colours.
- Full width of the editor, 16 columns, tiles about square (≈25×26 px at width 560), gap 5,
  radius 7. Selected tile: 2 px ring plus a check in `contrastOn(colour)`.
- **Used by another group**: a small white dot on the tile, legend "Used by another group"
  right of the *Color* label. It is a hint, the colour stays selectable.
- New group: the **first unused colour** is preselected (pure function in `domain/`).

### 3.3 New group inside Manage Groups
- *New group* opens a form card **at the top**, above the list (primary border + ring),
  and disables the *New group* button while open.
- Form: colour preview square left of the **New group name** field, palette, hint "Assign
  projectors via the grid", *Cancel* / *Create group*.
- **Animated**: the card grows in with `AnimatedSize` / `SizeTransition` (~200–250 ms,
  ease-out) plus a fade, the group rows slide down with it; Cancel / Create collapses it the
  same way, and a created group's row gets a brief highlight. Keep the form above the
  scrolling list so it can't scroll away.

### 3.4 New group from the card context menu
"New Group…" keeps its own compact dialog (no group list), now in the new look:
- 560×420 (440 with the long variant below): title bar *New Group*, Name with colour preview,
  palette, a **joins** box, footer *Cancel* / *Create group*. The dialog opens ready, no
  animation.
- Joins box: projector icon, "**3 selected projectors** will join this group", and under it
  the projectors by **IP**:
  - few and not consecutive: a comma list (`192.168.0.15, 192.168.0.16, 192.168.0.17`);
  - many: `collapseIpRanges` chips, at most 2–3, then `+N more` with the full list in a
    tooltip (`192.168.0.10 to .49`, `192.168.1.20 to .35`, `+4 more` for 60 projectors). The
    box is always two lines high.
- After Create the selected projectors are assigned (as today, `projector_workspace.dart`).

### 3.5 Delete confirm
`ConfirmDialog` (§1.2): "Delete “Left wall”?", "The group is removed from this project.",
**What changes**:
- "**4 projectors** stay in the project, ungrouped"
- "**Shutter close, 22:30** is paused" — one row per scheduled task that targets only
  this group; tasks that keep other groups just lose this one (§4.5)
- "`/group/left-wall` no longer answers"

Rows that don't apply are left out.

Today `deleteGroup` leaves the tasks that target the group alone (they keep running and
match no projector; the current confirm only warns). Groups (step 2) lands before the
`targetGroupIds` change (§4.5, step 15), so step 2 already pauses those tasks with today's
single field: `targetGroupId` cleared, switch off, target chip "No target". Step 15 then
generalises it to "remove the id, pause only when no group is left".

---

## 4. `[x]` Scheduled Tasks

Done 2026-10-19 (agent, then fixes after the owner's check). Differs from the text below
and the decisions under it:
- **No Active switch in the editor** (owner): it repeated the card's. A task is switched
  on and off on its list card only; the editor header keeps the status pill.
- **New task is filled**, as Manage Groups' *New group*, and disabled while the editor's
  own filled button (*Create task*, *Save changes* with edits, *Schedule again* with a
  valid date) can be pressed. The empty state has no button of its own.
- **Picker tiles for Power and Shutter** read as on the control bar: its icon in the
  status colour and one word (*On*, *Standby*, *Open*, *Close*); the full name stays
  everywhere else.
- Section numbers on a neutral tile, the editor footer is its own compact one inside
  the card (*Delete* steps down to an icon when narrow), *Duplicate* opens an unsaved
  new task.

Boards: *Scheduled Tasks: weekly task / new task, validation / command picker / many tasks,
10 groups / completed tasks*. Dialog 980×660.

Decided with the owner 2026-10-19, before implementation:
- **Active switch**: the card's switch applies at once (no Save), as today; the editor
  header's switch is part of the edit and applies with *Save changes*.
- **List order**: active tasks by next run, paused ones after them, then the collapsed
  *Completed* section.
- **On open nothing is selected.** With tasks, the editor shows a summary: clock icon,
  "3 active, 1 paused", "Next run Tue 13 Oct, 08:00" (left out while none is active), and
  "Select a task to edit it." With no tasks: clock icon, **No scheduled tasks**, "Send a
  command to all projectors or to groups at a set time: once, daily or weekly." and a
  *New task* button; the list shows "No tasks yet".
- **Narrow window** (§1.4, down to 800): the list narrows to 280 px and the day presets
  wrap under the day toggles when the row doesn't fit.
- **Commands**: only the mockup's set (Power, Shutter, Input, Custom); more categories
  later.
- **Command string** (*Enter a command string…*) stays in the task only, not added to
  Custom Commands.
- **Overdue one-time tasks never run** (owner, replaces today's late run; §4.8 stays
  deferred for the rest): a one-time task fires only within a 2-minute grace of its time.
  Later than that it goes to *Completed* with a grey "Not run, Thu 8 Oct, 18:00" line (no
  green check), derived from the date, no new field or state file. It offers *Schedule
  again*, *Duplicate* and *Delete* like a completed one.

### 4.1 One master-detail dialog
Today the list and the editor are two dialogs (`ScheduledTasksDialog` opens
`_ScheduledTaskEditorDialog`). They become **one**: list on the left (330 px), editor on the
right. Selecting a card loads it into the editor; *New task* adds a dashed **New** card at
the top of the list and an empty editor.
- Unsaved edits when another card is selected, *New task* is pressed or the dialog is
  closed: a `ConfirmDialog` "Discard changes to "<task>"?" with *Keep editing* /
  *Discard* (owner, 2026-10-15).

### 4.2 Task list
- Header: "14 tasks, 12 active" and a tonal *New task* (disabled while a new task is open).
- Card: time (22 px, tabular), active switch; command + **target chip**; schedule line
  (weekday dots for weekly, "Every day", "Once, Sun 18 Oct") and "Next: Tue 13 Oct" /
  "Paused". Paused cards are dimmed. Selected card: primary border + ring.
- **Target chip**: All projectors; one group → dot + name; **two or more groups → up to five
  stacked dots + "N groups"**, the names in a tooltip. Same width whether 2 or 30 groups.
- The list **scrolls**: scrollbar, fade at the bottom (and top when scrolled).
- Sections under the active tasks, each a collapsible header row with its count and
  *Clear* when expanded (owner, 2026-10-13):
  - **Completed N** — one-time tasks that ran: muted card, no switch, green line
    "✓ Ran Sat 10 Oct, 18:00".
  - `[later]` **Missed N**, with §4.8 — one row per missed run: muted card, no switch, amber
    line "⚠ Missed Tue 13 Oct, 08:00". For a recurring task the task itself stays in the
    active list; the Missed row is only the record of that run. Selecting the row opens the
    task.
- Footnote at the bottom: "Runs only while the app is open".

### 4.3 Editor
- Header: "<command>, <target>" (`Power on, Main stage`, `Power on, 10 groups`), next-run
  pill, *Active* label + switch.
- Numbered sections **1 Command**, **2 Target**, **3 When**. Body scrolls when it doesn't fit
  (fine per the owner), header and footer stay.
- Footer: *Delete* (error) left; *Revert* / *Save changes* right. New task: *Discard* /
  *Create task*, validation inline (red step number, field error) plus a footer message.

### 4.4 Command picker
The dropdown is replaced:
- **Closed field**: category icon tile + command name, chevron. No code.
- Click opens a **panel** under the field, full editor width. It expands inside the editor
  (`AnimatedSize`, the editor body scrolls), not as an overlay, so focus and placement
  inside the dialog need no extra handling:
  - search field on top ("Search commands", per the hint text rule in §1), focused on
    open;
  - **category rail** on the left with counts: All, Power, Shutter, Input, Custom (and *Cue*
    once F3 lands);
  - **tiles in 3 columns**, names only, grouped by category under small headers when *All*
    is active; the current command has a primary border and a check; the list scrolls with a
    fade;
  - footer: *Enter a command string…* → the Name + Command string fields of the current
    "Custom Command…" flow.
- **No keyboard-hint line and no command codes** in the panel (owner, 2026-10-13).
  Keyboard navigation itself still works (arrows, Enter, Esc).
- Data: the built-in table `_CommandGroup`/`_CommandEntry` in `scheduled_tasks_dialog.dart`
  (Power 2, Shutter 2, Input 11) plus `customCommandsProvider`. Move the table to `domain/`
  so the picker search is a pure, tested function.

### 4.5 Target: several groups
- Two options: **All projectors** ("20 in project") and **Groups** ("10 of 12 selected,
  18 projectors").
- Under them the project's groups as **toggle chips** (dot + name), any number selected.
- **Model change:** `ScheduledTask.targetGroupId` (`String?`) → `targetGroupIds`
  (`List<String>`): one field in the Freezed model, then `build_runner`. Tasks are saved in
  the project file by hand-written JSON (`_scheduledTaskFromJson` / `_scheduledTaskToJson`
  in `project_provider.dart`):
  - read `targetGroupIds`; a file that has only the old `targetGroupId` gives a one-item
    list;
  - write `targetGroupIds` **and** the old `targetGroupId` (the first id), so a file saved
    by this version and opened in an older app still keeps one target group.
  - No format version bump: the file's `'version': 2` is written but never read, so
    raising it would change nothing (2026-10-15).
- The other uses of the field (the scheduler's target resolution, group delete, the task
  diff in `project_provider.dart`, the dialog) move to the list.
- Deleting a group removes its id from every task. A task left with no groups is **paused**
  (switch off; card target chip "No target") — decided 2026-10-13. The delete confirm (§3.5)
  says so: "**Shutter close, 22:30** is paused".

### 4.6 When
- Row 1: **Repeat** segmented (Once / Daily / Weekly) and **Time**; for *Once* also **Date**
  in the same row.
- Row 2, **Weekly only**: **Days**: 7 round toggles (32 px), a thin divider, presets
  *Weekdays* / *Weekend* / *Every day*.

### 4.7 Completed one-time tasks
- Completed = a one-time task that has run (`lastRunAt != null`).
- Editor of a completed task: header pill "Ran Sat 10 Oct, 18:00" (green), a note "This
  one-time task has run. Pick a new date to schedule it again.", the normal fields, footer
  *Delete* / *Duplicate* / *Schedule again* (enabled once the date is in the future).
- *Clear* removes all completed tasks (confirm with `ConfirmDialog`).

### 4.8 `[later]` Missed runs (behaviour change, decided 2026-10-13)
**Deferred** (owner, 2026-10-15): the Scheduled Tasks redesign ships without it, and the
scheduler keeps today's behaviour until this step is taken up. What waits with it: the
Missed section (§4.2), the amber "Missed" pill in the editor (below), the amber Scheduled
tasks badge in the toolbar (§7f.3) and the missed-run tests (§9).

The scheduler only runs while the app is open (one tick per minute,
`scheduled_tasks_provider.dart`). A run is **missed** when its time passes while the app is
closed, the computer is off or asleep, or the tick is late. **Missed runs are never executed
late**; they are recorded and shown in the Missed list.

Today's behaviour this replaces:
- **Once**: `isTaskDue` fires whenever `now` is after `oneTimeAt` and the task hasn't run, so
  a task for Thu 18:00 fires on Fri 09:00 the moment the app opens. New rule: it fires only
  within a **2-minute grace** of `oneTimeAt`; later than that it is marked missed and
  disabled.
- **Daily / Weekly**: fire only on the exact minute, so a run while the app was closed is lost
  silently. New: that run is recorded as missed; the next run happens as usual.

Detection:
- The scheduler keeps a **last tick time**. On each tick, and on startup / project load, it
  lists the occurrences of every enabled task in the gap `(lastTick, now − grace]`; each one
  becomes a missed record. Pure function in `domain/schedule_due.dart`:
  `missedOccurrences(task, from, to)`, unit-tested.
- The last tick time and the missed records are **not** written into the project file (that
  would mark the project dirty on every tick). They live in a small per-project state file in
  the config dir (`schedule_state/<hash of the project path>.json`), plain JSON like the rest.
  A project without a path yet (never saved) keeps them in memory only.
- First open of a project with no state file: only one-time tasks whose `oneTimeAt` is in the
  past and that never ran count as missed (there is no record of when the app last ran).
- Each missed run also writes one Event Log line (warning): `[Scheduler] "Power on" missed
  Tue 13 Oct, 08:00 (app was not running)`.

Records and actions:
- `MissedRun { taskId, scheduledAt }` (plain Dart, hand-written JSON).
- A missed **one-time** task is disabled and shown only in Missed. Its editor works like a
  completed one (§4.7) with an amber pill "Missed Thu 8 Oct, 18:00"; *Schedule again* moves
  it back to the active list and drops its record.
- *Clear* on Missed removes the records; a missed one-time task is deleted with its record
  (confirm with `ConfirmDialog`, which says how many tasks go).

---

## 5. `[x]` Brightness Control

Done 2026-10-16. Differs from the text below: the values are read again on every mode
switch, the − / + buttons step **0.1 %** and repeat while held (`StepButton`), not 1 %.

Boards: *Brightness Control: Normal mode / User 2 mode / reading values*. Approved
2026-10-14. Today (`brightness_control_dialog.dart`) it is a 460 px `AlertDialog` titled
`Brightness Control - <IP>` with an Operating Mode dropdown and two bare sliders.

- Dialog **560×594**, title bar icon `brightness_6`, title **Brightness Control** without
  the IP. The cap is 640 since the visual rules (2026-10-16): the larger card titles made
  the content a few pixels taller than 594, and the dialog takes only the height it needs.
- The projector (model + IP, group pill, status) is in the **title bar** (§1.1), no projector
  card (the first mockups had one; dropped 2026-10-14, which took the dialog from 676 to 594).
- **Operating mode** card: title + "User modes unlock Max light output"; the dropdown becomes
  **six tiles** in one row (icon over label, 60 px high): *Normal* (sun), *Eco* (leaf),
  *Quiet* (moon), a small gap, *User 1 / User 2 / User 3* (person). Selected tile:
  `primaryContainer` fill, 2 px primary border. A tap sends the mode at once, as today.
- **Light output** card: icon tile, title, subtitle, the value large on the right (`85%`,
  26 px, tabular); below it the slider between **− / +** buttons (32 px, step 1 %; − in a
  muted red, + in a muted green, so they don't read as the card's icon tile, which shares
  the primary colour; owner, 2026-10-14); a scale
  row `8%` … `100%` under the track.
  - Subtitle: "Sent when you release the slider"; in a User mode "Limited to 80% by Max
    light output".
  - In a User mode the track above Max is **hatched** with a tick at Max, and the scale shows
    "Max 80%" under the tick instead of `100%`. The thumb can't pass it (as today:
    `lightMax = _maxLightOutput`).
- **Max light output** card: same layout (icon: arrow up to a bar), subtitle "Ceiling for
  Light output in this User mode".
  - In Normal / Eco / Quiet the card **stays in place, locked**: muted surface, subtitle
    "Only in User 1, 2 or 3 mode", a lock pill **User modes** instead of the value, slider
    and buttons disabled and dimmed. The dialog height doesn't change between modes (today's
    `Visibility(maintainSize)` hint text goes).
- **Loading** (reading `OPEI1`, `LOPI2`, `LOPI3`): the full layout with skeleton blocks in
  place of the tiles, values and sliders, instead of a centred spinner; the footer says
  "Reading current values from the projector…" with a small spinner.
- **Footer**: only an info line "Changes are sent to the projector right away". No *Done* /
  *Close* button — the dialog closes with ✕ (owner, 2026-10-14).
- **Behaviour:** unchanged except the − / + buttons. Each press changes the value by 1 %;
  presses are **debounced (~400 ms)** and sent as one `LOPI2` / `LOPI3` write, so a burst of
  clicks doesn't open a TCP connection per click. Keep `_PercentSlider`'s local drag state
  (a drag rebuilds only its own card).

---

## 6. `[x]` Color Correction

Done 2026-10-17 (wave B). Differs from the text below: dialog **640×600** (the 7 colors
tab had too little room at 580, and a 3 colors tile cut `2048, 2048, 2048` at 560); the value fields are 72×32 (visual rules §4); the
Method subtitle is "Match projectors side by side"; the Kelvin track is 6 px with a white
outlined thumb (visual rules §6a, large slider); the R / G / B rows use the shared thin
`LabeledSliderRow`; a typed value is sent after 400 ms, so holding a field's arrow doesn't
open a connection per step; the Low snap to 0 within ±3 applies to a slider drag only.
The editor has no "Changed" subtitle: the colour's name sits centred on its preview, and
the dot on the tile is the only "changed" mark (owner, 2026-10-17).

Boards: *Color Correction: matching off / matching, 3 colors / matching, 7 colors /
temperature User 1 / temperature Custom / temperature fixed by matching*. Approved
2026-10-14. Today (`color_correction_dialog.dart`) it is 560×680 with an underlined
`TabBar`, a `SegmentedButton` per tab, 3 or 7 cards of R / G / B sliders in one long scroll,
White Balance High and Low as two separate cards, and a centred grey line for Off / Default.

### 6.1 Frame
- Dialog **560×580**, title bar icon `palette`, title **Color Correction** without the IP.
- The projector is in the **title bar** (§1.1), no projector card (dropped 2026-10-14, 660 →
  580).
- **Tabs** in the `SegmentedTabs` strip: *Color Matching*, *Color Temperature*. Each tab
  carries a **state pill**: `Off` / `3 colors` / `7 colors`, and `Default` / `User 1` /
  `User 2` / `6500 K` / `Fixed`. Both states are visible without switching tabs.
- **Footer**: info line "Changes are sent to the projector right away", no button, the
  dialog closes with ✕ (as Brightness Control, §5).
- **Value fields** next to the R / G / B sliders are the app's `SleekStepperInput`
  (60×26, arrows on the right), synced with the slider both ways. Kelvin keeps a large
  value with − / + buttons (§6.4).

### 6.2 Color Matching
- **Method** card, one row: title + "Match projectors that sit side by side", segmented
  *Off / 3 colors / 7 colors* on the right. Switching keeps today's sequence (await the
  `CMAI0` write, then refresh the method's values and white balance, or `QTE` on Off).
- **Off**: an empty-state card: icon, "Color matching is off", a line on what 3 and 7 colors
  adjust, and a note "While it is on, Color Temperature is fixed and only white balance can
  be changed."
- **3 or 7 colors**: one card with a **row of colour tiles** and, under a divider, the
  **editor of the selected colour only** (replaces the 21-slider scroll):
  - 7 colors: seven tiles (dot over name), Red, Green, Blue, Cyan, Magenta, Yellow, White.
  - 3 colors: three wide tiles, dot left, name and the current values under it in small
    monospace (`2048, 96, 0`). Same tile height as 7 colors, so the dialog doesn't jump.
  - Selected tile: `primaryContainer`, 2 px primary border. A **dot** in the corner marks a
    colour whose values differ from its default.
  - Editor: colour preview square (the mixed RGB), name, subtitle "Changed" when it differs
    from the default (nothing otherwise), a text button **Reset**; then rows R / G / B:
    channel letter tile, slider 0 to 2048 in the channel colour, stepper input.

### 6.3 Color Temperature
- **Mode** card: four tiles in one row (icon + label, 44 px): *Default*, *User 1*, *User 2*,
  *Custom* (thermometer). Subtitle changes with the mode.
- **Default**: no second card (only the mode tiles).
- **User 1 / User 2**: one **White balance** card, a table: rows R / G / B, columns **High**
  (0 to 255) and **Low** (-127 to +127), each a slider + stepper input. The Low slider fills
  from a centre zero mark. Keep today's snap to 0 within ±3 on Low.
- **Custom**: see §6.4.
- **Fixed by Color Matching** (method 3 or 7): the mode tiles are dimmed and disabled, none
  selected (`QTE` reads `ER401` then), an amber lock pill "Color Matching: 3 colors"; the
  White balance card stays editable with the subtitle "Still adjustable while Color Matching
  is on" (today's behaviour).

### 6.4 Custom temperature
- Card: thermometer tile, "Color temperature", "Lower is warmer, higher is cooler", the value
  large on the right (`6500 K`).
- The existing blackbody gradient (`_kKelvinGradient`) as a 10 px track with a white thumb,
  between − / + buttons (step 100 K; − muted red, + muted green, as in Brightness §5),
  scale `3200 K` … `13000 K`.
- **Presets** row: chips *3200 K*, *5400 K*, *6500 K*, *9300 K*; the chip matching the value is
  selected. A tap sends `OTE:<K>`.
- − / + and preset taps are debounced like Brightness (§5) so a burst sends one `OTE`.

### 6.5 Behaviour changes
- **Reset** per colour: writes the default values of that colour (the current
  `_values3` / `_values7` initial values, confirmed as the factory defaults by the owner,
  2026-10-15) with one `VMR` / `VMG` / `VMB` or `C7CS<n>` write.
- **Changed** dot and subtitle: computed against the same defaults; only the active method's
  values are read, so only its tiles show dots.
- **Temperature presets** (§6.4).
- **Stepper inputs** for every RGB and white-balance value: typing a value commits on Enter
  or focus loss and sends one write, like a slider release.
- Load stays as today: only the active method's and mode's registers are queried.

---

## 7. `[x]` Geometry Correction

Done 2026-10-17 (wave B), with the Keystone / Curved preview of
`GEOMETRY_PREVIEW_PLAN.md`. Differs from the text below: no *Schematic* pill (the note
under the drawing says it is approximate; owner, 2026-10-17); Corner's four corners are one
column of rows, not a 2×2 grid (two 72 px fields don't fit half the card); *Throw ratio*
is a plain 40 px field without arrows; the corner selection pill (`Upper right`,
`2 selected`) is blue, as it shows state; the Off card's mode tiles are 40 px. Fixed on the
way: a race between loading a mode and switching again, duplicate corner writes, and the
order of a multi-corner commit.

Boards (dark only): *Geometry Correction: off / Keystone / Curved Correction / Corner, one
corner, Auto / Corner, two corners, Manual / reading values*, and the row *Geometry
Correction in the minimum window (800 × 600)*: *off / Curved, controls scroll / Corner, top of
the list / Corner, scrolled to the end*. Approved 2026-10-14. Today
(`geometry_correction_dialog.dart`) it is up to 920 wide and 90 % of the screen high, a
`SegmentedButton` with the four modes, `DialogSplitLayout` (canvas 5 : sliders 4), "Preview
not available" in Keystone and Curved, and a centred spinner while a mode loads.

### 7.1 Frame
- Dialog **920×720**, title bar with the projector (§1.1), title **Geometry Correction**.
- **Mode tiles** in one row (icon + label, 46 px): *Off*, *Keystone*, *Curved Correction*,
  *Corner Correction*. Selected tile: `primaryContainer`, 2 px primary border. Switching
  keeps today's sequence: the selection changes at once; `VXX:QPDI1=ON` first when leaving
  Off on a Quad Pixel Drive model, then `GMMI0`, then the first load of the mode.
- Body: **preview card** on the left (480 px) and a **controls card** on the right.
- Footer: info line "Changes are sent to the projector right away", no button (as §5, §6).
- Sliders are `LabeledSliderRow` with the stepper input, grouped under small headers with
  the range on the right of the header (`V -40 to 40, H -15 to 15`). Symmetric ranges fill
  from a centre zero mark.

### 7.2 Off
An empty-state card: "Geometry correction is off", one line, and three small cards, one per
mode, each with a mini drawing and one line on what it fixes. Under them a **Quad Pixel Drive
note**, by `quadPixelTierFor(model)`:
- Tier A: "Quad Pixel Drive turns on by itself when you choose a mode. This model needs it
  for geometry correction, and Corner Correction gets a wider inward range."
- Tier B: only the first sentence (their inward limits are unconfirmed, they stay standard).
- Other models: no note.

### 7.3 Keystone
- Preview card: header *Preview*, pill *Schematic*, text button **Reset**; the drawing (panel
  frame + image shape); legend *Panel* / *Image* and the note "The drawing is approximate,
  check the result on the screen."
- Controls: **Keystone**, degrees (Vertical -40 to 40, Horizontal -15 to 15, step 0.2);
  **Balance** (Vertical -60 to 60, Horizontal -30 to 30); **Lens**: *Throw ratio* stepper,
  "0.7 to 16.5, match the lens in use".

### 7.4 Curved Correction
- Same preview card as Keystone.
- Controls: **Arc** (Vertical, Horizontal, -40 to 40), **Keystone**, **Balance**, and **Lens
  and image**: *Throw ratio* and the *Maintain aspect ratio* switch ("Keep the image
  proportions while it bends").

**Preview in Keystone and Curved:** approved to add (2026-10-15). The drawing follows the
projector's own behaviour, measured with a camera on 2026-10-16, instead of VSS (which
computes its own corrections; decided by the owner 2026-10-16): model, constants, accuracy
and implementation in `GEOMETRY_PREVIEW_PLAN.md` (its §3 has the owner's decisions: pill
*Schematic* kept, no capped-angle hint, two centre lines and no grid). The unused
`_TrapezoidPainter` is replaced, not extended. The mockup's schematic is the target layout of
the card.

### 7.5 Corner Correction
- **Canvas card**: header *Corners*, a pill with the selection (`Upper right`, `2 selected`),
  text button **Reset all**. Canvas (the logical 480×300 of today): dashed **outer limit**,
  thin **default frame**, a tinted box per selected corner showing **its range** (`_bounds`),
  the image shape with Pincushion bows and the Linearity cross. Handles: unselected = card
  fill with a primary ring; selected = primary fill, white ring and a soft halo.
- Card footer: legend *Outer limit*, *Default frame*, *Range of the selected corner*; a hint
  line with key caps: "Drag a corner, or move it 1 step with ← ↑ → ↓. Ctrl click selects more
  corners, double click resets one."
- Interaction unchanged: drag, arrow keys with hold-repeat (`KeyHoldRepeater`), Ctrl / Shift /
  Cmd click for several corners, double click resets a corner, a click on empty space clears.
- **Corners** group in the controls card: header "Corners, panel pixels" and, on Tier A, a
  pill *Extended inward range*. A 2×2 grid of tiles (Upper left, Upper right, Lower left,
  Lower right): name, a dot when the corner is not at 0, and **H / V stepper inputs** (raw
  protocol units). The selected corners' tiles are highlighted; a tile click selects its
  corner (Ctrl click adds), the same selection as the canvas.
- **Linearity and pincushion** group: *Auto / Manual* segmented in the header; sub-headers
  *Linearity* (-127 to 127: Vertical, Horizontal) and *Pincushion* (-100 to 100: Upper,
  Lower, Left, Right). In Auto the six rows are disabled and dimmed.

### 7.6 Loading
- Opening and a first switch to a mode show the **full layout** at once: the canvas or
  preview area with a spinner and "Reading Corner Correction from the projector" ("Mode is
  already switched. The controls appear once the 15 values are read."), skeleton blocks in
  the controls card. Replaces the centred spinner.

### 7.7 Small windows
No separate compact layout: the dialog adapts like every other (§1.4) (owner, 2026-10-15).
The minimum-window boards show where it ends up at 800×600, about 720×510 for the dialog:
- mode tiles with short labels (*Off*, *Keystone*, *Curved*, *Corner*), the full name in a
  tooltip;
- the preview / canvas card shrinks and the canvas scales with it; handles keep their screen
  size; the keyboard hint moves into a keyboard icon (tooltip) in the canvas header and the
  legend fits one line;
- the controls card scrolls, with a scrollbar and a fade at the bottom;
- the corner tiles go from the 2×2 grid to one column when the card is too narrow for two.

### 7.8 Behaviour changes
- **Numeric H / V per corner**: typing commits on Enter or focus loss, clamps to the corner's
  limits for the model's tier (`cornerInwardH/V`, `cornerOutwardH/V`) and sends that corner's
  `GMFI` pair, like a drag release.
- **Reset** in Keystone writes 0 to `GMKS8`, `GMKS9`, `GMKI4`, `GMKI7`; in Curved to `GMCI2`,
  `GMCI3`, `GMCI6`, `GMCI7`, `GMCS8`, `GMCS9`. Throw ratio and Maintain aspect ratio are kept.
  **Reset all** in Corner stays as today (the eight `GMFI` corner values).
- **Quad Pixel Drive note** by tier (§7.2).
- **Preview** in Keystone and Curved (§7.4, `GEOMETRY_PREVIEW_PLAN.md`).
- **Loading** layout (§7.6) and the adaptive layout (§7.7, §1.4).

---

## 7a. `[x]` Edge Blending

Done 2026-10-19 (wave C, fixes after the owner's check). Differs from the text below: the
Black Level tab's pill shows the Black Level Mode; the pair's A / B switch is a
`SegmentedTabs` with custom tab content (letter, IP in mono, status dot), shared by both
tabs; the hints under the canvas are one line each.

Boards (dark only): *Edge Blending: one projector, Right edge selected / Black Level tab /
mode Off / pair side by side, linked / pair, B not replying*. Approved 2026-10-14, after the
Black Level rework in `EDGE_BLENDING_PLAN.md` stage 8 (R, G, B only; zones measured from the
zone end; limits where border lines never cross). Today (`edge_blending/`) the dialog is up
to 960 wide and 90 % of the screen high, titled `Edge Blending - <IP>` (a pair: the two
names), with a `SegmentedButton` Off / On / User, an underlined `TabBar`,
`DialogSplitLayout` (canvas left, panel right), the Markers and Auto test pattern switches
above the edge cards, and in a pair the panel header "Switch on the canvas".

### 7a.1 Frame
- Dialog **960×800**, title bar icon `gradient`, title
  **Edge Blending**, projector in the title bar (§1.1). A pair shows both:
  `Pair: RQ25K (192.168.0.41), RQ25K (192.168.0.42)`; the group pill when both are in the
  same group; the status badge reads *Online* while both reply, amber *B not replying*
  otherwise. `DialogTitleBar(pairIds:, badges:)` draws the pair line and the shared group
  (ready 2026-10-17); the dialog passes the badge, since "replying" is its own state.
- The frame comes from Geometry, now shared (2026-10-17): `CanvasCard`, `CanvasLegend`,
  `CanvasNote` (`common/canvas_card.dart`), `ControlsCard`, `ControlsGroup`,
  `ControlsGroupHeader`, `ControlsSubHeader`, `SettingRow`, `CardPill`
  (`common/controls_card.dart`), `ModeTileRow`, and the thin `LabeledSliderRow` with its
  `limit` hatch.
- **Mode tiles** (54 px, icon + label + one muted line): *Off* "No blending", *On* "Built-in
  blend curve", *User* "Curve stored on the projector". A pair with mixed modes selects none,
  as today.
- **Tabs** in `SegmentedTabs`: *Edge Blending* with a pill (`2 edges`, `Linked`, `Off`) and
  *Black Level* with the Black Level Mode (`Soft edge + level`, `Black level only`).
- Body: **canvas card** on the left (480 px) and a **controls card** on the right. Footer:
  info line "Changes are sent to the projector right away", no button.
- **Canvas card header**: left side empty for one projector; in a pair the arrangement
  segmented *Side by side / Stacked* and the swap button. Right side, **in the same place in
  both**: icon toggles **Markers** (`Icons.width_normal`: a frame with two vertical lines,
  like the Start and zone end lines the markers draw) and **Auto test pattern**
  (`Icons.grid_on`), both stock icons in an `IconButton` with `isSelected` (owner,
  2026-10-15; today they are two labelled switches in the panel), then *Reset all* as an
  icon button (`Icons.restart_alt`, as today). The
  toggles' names are in their tooltips; in a pair the tooltip adds "on both projectors". The
  `EATI1` ER401 warning moves from the label onto the Auto test pattern toggle's tooltip.

### 7a.2 Edge Blending tab
- **Start and Width have their own colours** (owner, 2026-10-14): Start amber, Width
  primary, on the canvas lines and handles, the slider fill and thumb, a small square before
  the slider label, and the legend.
- **Handles at the same height** on each line, as today; where Start and Width overlap,
  Width is on top and is picked first (today's hit order). The selected handle is filled and
  shows its value in a pill (`Width 640`).
- The canvas draws the band from the raster edge to Start black, the blend zone as a ramp,
  and a dashed line at Start and the zone end. Legend: *Start*, *Width, zone end*, *Blend
  zone*; one hint line with key caps (drag, ← → 1 step, Shift 10, double click resets an
  edge, Esc clears).
- **Edge cards**, one per edge: side icon, name, switch. An enabled edge shows Start and Width
  (`LabeledSliderRow` + stepper), with a **tick at the limit** (`maxFor`, §8 "Limits rule").
  A disabled edge **collapses to one row** with "Off" and its switch. The selected edge's
  card has the primary border. A note under the cards: "The tick on a track is the limit:
  the border lines of opposite edges never cross, so each edge's Start, Width and border
  limit the other."

### 7a.3 Pair
- Canvas: pill **A** / **B** with the IP by each raster (the active one filled), a
  **Linked** pill between them while Link is on, the inactive raster dimmed and dashed, and
  the **overlap** under the facing edges: "Overlap 640 px, 17 % of a raster" (from the
  pair layout functions in `domain/edge_blend_pair.dart`).
- Controls card: an **A / B segmented** at the top (letter, IP, status dot) replaces
  "Switch on the canvas"; clicking a raster or its pill still switches. Header "Edges of A".
- The facing edge's card carries the Link control as a labelled chip: **Linked with B Left**
  (primary), off as **Link with B Left**; unavailable: **Link needs B** (no reply) or the
  mixed-raster tooltip. Note: "Linked: on, Width and the overlapped black level go to B as
  well. Start stays per projector."

### 7a.4 Black Level tab
- Canvas per `EDGE_BLENDING_PLAN.md` §8 "Black level zones" (`domain/black_level_zones.dart`):
  black to Start, Overlapped to the zone end, Overlapped + border (hatched) to the border
  line, Non-overlapped inside; the border handle on the border line, enabled edges only; a
  disabled edge draws only its dashed outline. Legend *Non-overlapped*, *Overlapped*,
  *Overlapped + border* and one hint line: "Each area shows its own level. Drag the border
  line to set its width." (at most two lines under the canvas).
- Controls card, top to bottom:
  1. **Mode**: segmented *Soft edge + Black level* / *Black level only*.
  2. **Edges** table ("overlapped level, border width"): row per edge with side icon and
     name, the Link icon (pair), the Interlocked checkbox, **R / G / B steppers**, then,
     after a thin vertical divider in the field rows only, the **border width** stepper.
     The width column header is "Width" with a ↔ icon in primary, and its fields have a
     primary tint, so colour values and widths don't read as one group (owner, 2026-10-14).
     The selected edge's row is highlighted. A disabled edge's row is dimmed; its levels
     stay editable, its **width field is disabled** (the value stays shown: it still counts
     for the limits).
  3. **Non-overlapped area**, 0 to 255, *Interlocked* checkbox in the header, three R / G / B
     sliders with steppers, always all three (moving one moves all while Interlocked).
  4. **Black border level**, 0 to 255, *Interlocked*, R / G / B sliders.

  Order of the groups: Edges, Non-overlapped area, Black border level (owner, 2026-10-14).
- This replaces the four border width sliders under the Black border card: the widths live
  with their edge, and the canvas handles stay the way to drag them.

### 7a.5 Off and unreachable
- **Off**: canvas and controls stay in place, dimmed and inert (today's `IgnorePointer` +
  opacity), and an **opaque** note card over the canvas: "Edge blending is off. The values
  stay on the projector and apply again when you choose On or User."
- **Pair, one projector not replying**: the other works on its own. The silent one keeps
  its place on the canvas as a dashed placeholder with "No reply" and **Retry**, so nothing
  jumps when it answers; its pill and the A / B segmented show an error dot; Link shows
  *Link needs B*; Markers and Auto test pattern go to the replying projector only (as
  today, `_reachable`).
- One projector not replying, or loading: today's centred states, inside the new frame.

### 7a.6 Behaviour changes
- A / B segmented in the controls card (§7a.3).
- Border widths as steppers in the Edges table instead of sliders (§7a.4).
- A disabled edge's card collapses to one row (§7a.2).
- Overlap readout in a pair (§7a.3).
- Markers / Auto test pattern as icon toggles in the canvas header (§7a.1).
- Writes, limits and Link routing are unchanged (`EDGE_BLENDING_PLAN.md`).

---

## 7b. `[x]` Remote Preview

Done 2026-10-17 (wave B). Differs from the text below: the `6 of 8 online` badge is green
when all are online, amber when some, red when none; the "Preview not available" icon is
40 px; while the feed connects the Pre-show subtitle reads "Connecting to the live feed";
with some projectors on it reads "K on"; the tags over the plane are fully rounded and
without letter spacing. The signal tag's frequency comes from
`domain/preview_signal_tag.dart`; the Web API mocks, `openapi.yaml` and the goldens were
updated with it.

Boards (dark only): *Remote Preview: live, shutter open / Standby with Pre-show / not
available / 8 projectors*. Approved 2026-10-14. Today (`remote_preview_dialog.dart`,
`preview_viewport.dart`) it is an `AlertDialog` titled `Remote Preview - <name> <IP> · <group>`
(several: `Remote Preview - N projectors`), a 16:9 plane with a 2 px frame, the grid with
captions `name · group` and the IP, and a bare *Pre-show mode* row with a switch.

### 7b.1 Frame
- One projector: dialog **720×600**; several: **980×630**. Title bar icon `monitor`, title
  **Remote Preview**, the projector in the title bar (§1.1). Several projectors: subtitle
  `8 projectors (192.168.0.41 to .48)` (`collapseIpRanges`, §1.3), no group pill, status
  badge `6 of 8 online`.
- Footer: info line "Live from the projector, about 1 frame a second" and, on the right, the
  **frame colour legend**: *Shutter open* (green), *Shutter closed* (red), *Not on* (grey).
- No status chips under the preview: power, shutter, input and signal are already shown by
  the title bar badge, the frame colour and the signal tag (owner, 2026-10-14). No "Live"
  tag either.

### 7b.2 Preview plane
- Black 16:9 plane, radius 10 (8 in the grid), the 2 px frame coloured as today
  (`_frameOpen` / `_frameClosed`, `outline` when not on).
- Tags as today, restyled (dark translucent pill, white text): top left `PRE-SHOW`,
  `TEST PATTERN` or `ASPECT DIFFERS` (Pre-show wins the slot); bottom right the signal, with
  the separators of the UI text rule: `HDMI1: 3840x2160/60p (134.99 kHz, 59.99 Hz)`
  (today `HDMI1 · 3840x2160/60p (134.99kHz/59.99Hz)`). `previewSignalTag` is shared with the
  Web API preview stream, so the web page's tag changes with it: in the same commit run
  `flutter test --update-goldens test/unit/web_api_dto_test.dart` and update any tag in
  `web_ui/mocks/`.
- Notices centred as today (*No signal*, *HDCP-protected content*, *Starting up*, *Image
  rotating*); connecting: a small spinner.
- **Not available**: monitor-off icon, "Preview not available", one line "The projector's
  web page did not answer.", a pill **Retry** (outlined white).

### 7b.3 Grid (several projectors)
- Three columns of 300 px tiles (two up to four projectors, as today), gap 8, two rows
  visible, the rest scrolls with an always-visible scrollbar in its own gutter (today's
  rule).
- Caption under each tile: group colour dot, model in bold, IP in monospace on the right
  (replaces `name · group` + IP).

### 7b.4 Pre-show card
- One card under the preview or grid: icon tile (eye; primary container while on),
  **Pre-show mode**, a subtitle, the switch on the right. Subtitles:
  - on: "Only in Standby: this projector is on" (switch disabled);
  - Standby with a live feed, on: "Keeps the input alive for preview, the projector stays
    off. Stays on after you close this window.";
  - no feed: "Needs the live feed and Standby" (disabled);
  - several: "In Standby with a live feed: 1 of 8 projectors, on. Applies to every
    projector that can take it."
  - applying: a small spinner before the switch, as today.
- "Stays on after you close this window" says up front what today's close snackbar
  ("Pre-show stays active on the projector") says afterwards; the snackbar stays.

### 7b.5 Behaviour changes
- Title, captions and the signal tag follow the UI text rule (no `·`).
- Frame colour legend in the footer, Pre-show as a card with state subtitles.
- Everything else (sockets, signal source, pre-show eligibility, sizing to the window) is
  unchanged (`REMOTE_PREVIEW_PLAN.md`).

---

## 7c. `[x]` Custom Command (Add / Edit Command)

Done 2026-10-15 (wave A), as described below.

Boards (dark only): *Add Command: empty / filled / OSC address taken*, *Edit Command*.
Approved 2026-10-14. Today (`custom_command_dialog.dart`) it is 400 wide with two outlined
fields (label inside), a one-line OSC preview (`/pgrid/all/custom/<slug>`) and *Cancel* /
*Add* (*Save* when editing).

### 7c.1 Layout
- Dialog **520×500**, title bar icon `code`, title **Add Command** / **Edit Command**. No
  projector in the title bar: a command isn't tied to one projector.
- **Name**: label above the field (as in Groups and Add Projectors), focused on open, help
  line "Shown on the button and used for the OSC address". No placeholder: the label names
  the field (hint text rule, §1).
- **Command**: monospace field, help line "Sent as is to the selected projectors, in
  NTCONTROL form". Placeholder `OSH:1` (a known-good command; the mockup's `VXX:DYNI0=+00001`
  was only an illustration).
- **OSC addresses** card, always shown at its full height so nothing moves while typing:
  header with the OSC icon (`Icons.sensors`, as the OSC page in Preferences) and "Follow the
  name" on the right, two rows, label above a
  monospace address:
  - *All projectors*: `/pgrid/all/custom/<slug>`;
  - *One group*: `/pgrid/group/{group-name}/custom/<slug>`, `{group-name}` in primary (the
    address OSC already accepts, `osc_service.dart`, not shown today).
  - No name yet: both rows read "Type a name to get the address" (muted).
- Footer: *Cancel* and the filled **Add command** (with a + icon) or **Save**.

### 7c.2 States
- **Address taken** (the existing slug check, `_isDuplicate`): the Name field and label in
  error colour, error line "Another command already has this OSC address", the card's
  header says `Taken by "Shutter Close"` and its addresses are struck through and muted;
  the add button is disabled. Replaces "Name already used", which hid that two different
  names can give the same address.
- **Edit**: as Add with the values filled and **Save**; the footer's left side reads
  "Renaming changes the OSC address" (a show controller pointing at the old address stops
  working).

### 7c.3 Behaviour changes
- The group address is shown; the error names the command that holds the address; the
  Edit footer note. Saving, the slug rule and the duplicate check are unchanged.
- `CustomCommand.oscAddress` (`/pgrid/custom/<slug>`) is unused and doesn't match what OSC
  accepts; the dialog builds the two addresses from the slug instead (drop or fix the
  getter in the same step).

---

## 7d. `[x]` Keyboard Shortcuts

Done 2026-10-16. Differs from the text below: the cards are not in fixed columns; each
card goes to the shorter of the two columns by its measured height, so the columns end
level. The key column is 176 px wide. Section icons follow the icon tile rule (§1).

Boards (dark only): *Keyboard Shortcuts*, *Keyboard Shortcuts: search*. Approved 2026-10-14.
Today (`keyboard_shortcuts_dialog.dart`) it is 560×620, one long list of eight sections
under uppercase headers, keys as monospace badges, and some descriptions with dashes
("Lens shift — normal speed", "Zoom in / out (50 – 200%)").

- Dialog **860×680**, title bar icon `keyboard`, no footer.
- **Search field** on top, focused on open: "Search shortcuts" (the examples went with the
  hint text rule in §1, 2026-10-16), the count on the right (`33 shortcuts`; while searching `5 of 33` and a clear button).
  It matches descriptions and keys ("ctrl g", "esc"); matched text is highlighted, each
  section header shows `4 of 6`, sections without matches are hidden, and a hint line under
  the results says what the search covers. Pure filter function in `domain/` (unit-tested).
- **Sections as cards in two columns** (Project, Canvas navigation, Edit, View; Selection,
  Projector control, Alignment, Lens shift), each with an icon tile and a title in sentence
  case; *Projector control* adds "selected projectors" on the right. The columns scroll with
  a scrollbar and a fade at the bottom.
- **Keys and mouse actions look different**: keys are solid caps in monospace (`Ctrl` `S`),
  mouse actions are dashed pills with a mouse icon (*Click*, *Drag*, *Scroll*, *Middle
  drag*, *Click empty space*). One cap per key, no "+". macOS keeps today's mapping (`⌘`,
  `⇧`, Redo `⌘ ⇧ Z`).
- **Descriptions rewritten** to the UI text rule and shorter: "Zoom in or out (50 to
  200%)", "Lens shift, normal speed", "Add or remove a projector", "Box select", "Select
  the whole group of the selected projector", "Exit the app".
- Behaviour change: the search; the list itself is unchanged.

---

## 7e. `[x]` About

Done 2026-10-16. Differs from the text below: only the hint on the right and its icon are
the link (hand cursor), not the whole row; *Third-party licenses* has no hint, so its
chevron is the link. The version pill is as wide as its text, in the accent colour.

Board (dark only): *About*. Approved 2026-10-14, after a look at what About windows usually
hold (macOS: icon, name, version, copyright, optional credits; GNOME / libadwaita: centred
header, links as rows with icons; Flutter: `showAboutDialog` with name, version, legalese
and a licenses button). Today (`about_dialog.dart`) it is 360 wide: name, `Version x`, a
one-line description, "Author", `© 2025-2026` and *View Licenses*.

- Dialog **480×615**, title bar icon `info`, everything centred.
- **Header**: the app icon (the launcher icon artwork, 80 px, radius 18, soft shadow; the
  artwork is not in the app bundle today, only `flutter_launcher_icons` reads it, so add a
  160 px copy under `assets:` in `pubspec.yaml`),
  **Projector Grid** (22 px, bold), a pill `Version 1.4.2 (build 11)` (`PackageInfo`
  version and build number), and under it **Made by Aleksei Vlasov** (15.5 px, name bold).
  No description text (owner, 2026-10-14).
- **Links card**, one row each (icon tile, label, a muted hint, an external-link icon or a
  chevron):
  1. *What's new in 1.4.2*, "Release notes", opens an external page (the release notes of
     that version);
  2. *Project page*, `github.com/zap-syr`, opens https://github.com/zap-syr/projector-grid;
  3. *Report a bug*, "GitHub issues", opens
     https://github.com/zap-syr/projector-grid/issues/new;
  4. *Third-party licenses*, chevron, opens `showLicensePage` in the app (replaces the
     *View Licenses* button);
  5. *Support the project*, "gumroad.com", heart icon on a pink tile, opens
     https://projectorhub.gumroad.com/l/projectorgrid.
- **Footer**, centred and muted: `© 2025–2026 Aleksei Vlasov`.
- External links open in the default browser the way the app already does it
  (`projector_card.dart`, "Open Web UI": `cmd /c start` on Windows, `open` on macOS); move
  that into one shared helper rather than adding `url_launcher`.
- Not added on purpose (owner, 2026-10-14): a description, platforms and protocols rows,
  the settings folder, a copy-version button.

---

## 7f. `[x]` Main toolbar

Done 2026-10-17 (wave B). Differs from the text below: the badges take the visual
rules' neutral colour and 11.5 px figures (the mockup had a lighter grey and 10 px); the
Alignment icon is `center_focus_strong`, as in the banner; the tool buttons have tooltips
in both modes. `[later]`: a tooltip with `Ctrl+1` / `Ctrl+2` on the view switch (needs a
parameter in `SegmentedTabs`); the toolbar background a tone lighter, as in the mockup,
if the owner wants it after a look. Counts come from `toolbar_counts_provider.dart`, the
next run from `domain/schedule_next_run.dart`.

Boards (dark only): *Toolbar: wide window, 1600 / 1180 / Alignment on, a missed task /
minimum window 800, compact*. Approved 2026-10-14. Today (`toolbar.dart`) the left side is
four outlined buttons with long labels (*Add Projectors*, *Manage Groups*, *Scheduled
Tasks*, *Alignment*) in a horizontal `SingleChildScrollView`, the right side a
`SegmentedButton` *Controls / Monitoring*. Around 1180 px wide the last button is already
cut off, and the scroll doesn't show that more is there.

### 7f.1 Layout
- Height 52. Left: the filled **Add projectors** pill (icon + label, always labelled), a
  thin vertical divider, then the **tool buttons** without outlines: *Groups* (was *Manage
  Groups*), *Scheduled tasks*, *Alignment*, icon + label, 36 px high, radius 10, a light
  fill on hover. Right: the **view switch** *Controls / Monitoring* (icon + label) in the
  dialogs' segmented style. No horizontal scroll.
- Labels in sentence case: "Add projectors", "Scheduled tasks".
- **Alignment on**: the tool button takes the primary-container fill. Nothing else is
  added to it (no "On" pill), so its width never changes.

### 7f.2 Compact mode
- Below the threshold the three tool buttons become **icon-only** 38 px buttons with a
  tooltip (§7g, e.g. "Scheduled tasks, 12 active, next run at 22:30"). *Add projectors*
  and the view switch keep their labels; at 800 px everything fits.
- The mode is chosen from the **window width**, not from the toolbar's measured content:
  a constant threshold of about 900 px (the full layout's width with the widest badges),
  with hysteresis (compact below ~880, full again above ~920) so it never flickers at the
  edge. If even the compact row can't fit some day, the extra tools go into a `⋯` menu.

### 7f.3 Badges, without layout jumps
- **Groups** shows the number of groups, **Scheduled tasks** the number of active tasks,
  as a small round badge on the **top-right corner of the icon**, in both modes. It sits
  over the icon (a `Stack`), outside the row's layout, so a change of value, or the badge
  appearing or disappearing, never moves anything (owner's concern, 2026-10-14).
- Fixed size: at least 17 px, tabular figures, `9+` above 9, a 2 px ring in the toolbar's
  colour to cut it out of the icon. Zero shows no badge.
- State is shown by **colour, not text**: `[later]` with §4.8, missed runs turn the
  Scheduled tasks badge amber with the same number; the tooltip says "12 active, 1 missed
  run".
- The counts come from `select`-ed providers (group count, active / missed task counts),
  so the toolbar doesn't rebuild on every polling tick.

---

## 7g. `[x]` Tooltip

Board (dark only): *Tooltip: variants*. Approved 2026-10-14. Today `CustomTooltip`
(`custom_tooltip.dart`) is an `inverseSurface` box, radius 4, padding 8×5, 12 px text,
extra lines in italic.

- A raised surface instead of the inverse colour: `#2E3238` in dark (surface container
  highest), white in light (board *Tooltip: variants (light)*: border `#D6D5DA`, a
  stronger shadow, key caps `#F0EFF3`, warning in dark amber `#8A5300`), a 1 px border
  (`outlineVariant`), radius 9, a soft shadow, padding 11×7, at
  most **260 px** wide with wrapping, and a small **arrow** to its anchor.
- Text: the first line is the title, 12.5 px semibold; an optional second line is the
  detail, 12 px regular in `onSurfaceVariant` (replaces the italic lines). Left-aligned
  when it has two lines.
- Optional **shortcut** on the right of the title, as key caps in the Keyboard Shortcuts
  style (§7d): "Enter Alignment mode" `Ctrl` `L`.
- **Warning** variant: amber border and an amber title with a warning icon (e.g. "Auto
  test pattern unavailable", "Not available while a test pattern is on").
- Placement stays as today (above by default, below with `TooltipPlacement.bottom`,
  clamped to the window); the arrow follows the side. Still ignores the pointer.
- API: `CustomTooltip(message:, detail:, shortcut:, warning:)`; the `\n`-split italic
  lines go. One change in one widget restyles every `CustomTooltip` (12 uses).
- Six Material `Tooltip`s are left in the app (one is the group chip on the card, which
  §7j.3 removes). Move the rest to `CustomTooltip`, or where that doesn't fit give
  `TooltipThemeData` the same surface, border and text (no arrow), so no old-style tooltip
  is left.
- The arrow: when the bubble is clamped to the window edge the arrow is no longer at its
  centre, so the layout places bubble and arrow as two children of one
  `CustomMultiChildLayout` (the current `CustomSingleChildLayout` can't hand the clamped
  offset to its child).

---

## 7h. `[x]` Control bar

Done 2026-10-17 (wave B, then the owner's review). Split into `widgets/control_bar/`.
Differs from the text below:
- Width **344** (was 320), so *Standby* fits beside its icon.
- Every button and dropdown is **36 px** high, *Set* / *Show* included.
- *Set*, *Show* and *Run* are **tonal** (`primaryContainer`), the On / Off pairs outlined.
- The On / Off icons are coloured: green for Power On, Shutter Open and OSD On; red for
  Standby, Close, OSD Off and Test pattern *Off* (`grid_off` icon). In the Power / Shutter
  / OSD rows the icon sits 12 px from the left edge, so icons and labels line up.
- **Without a selection the buttons stay enabled** and send nothing, so the bar doesn't
  rebuild on every selection change (replaces "disabled as today", §7h.1).
- No command count on the Custom tab, no "Favorites", "seconds" or "Calibration, lens
  type" hints, no OSC hint under the custom commands (it is in the OSC reference).
- Lens buttons 38 px in the cross, 36 px in Focus and Zoom, 20 px chevrons; Lens setup
  opens and closes in 150 ms.
- `[later]`: sentence-case test pattern and calibration names in the shared option maps
  (the Web API uses them too).

Boards (dark only): *Control bar: General / Lens setup open, scrolled / System / Custom*,
each 320×970. Approved 2026-10-14. Today (`control_bar.dart`) it is the 320 px right-hand
panel with an underlined `TabBar` (General / System / Custom), uppercase primary headers
with a rule ("POWER ——"), pairs of outlined buttons, a lens-shift cross of 12 outlined
round buttons with *Home Position* full width under it, *Calibration* and *Lens Type*
always shown, 6-button Focus and Zoom rows, and *Test Patterns* with an *OFF* button,
four favourite slots and a dropdown with *Set*.

### 7h.1 Frame
- Width stays **320**. Tabs in the segmented style of the dialogs (`SegmentedTabs`):
  *General*, *System*, *Custom* with the command count as a pill.
- Groups become **cards** (radius 14) with a small icon and a sentence-case title instead
  of the uppercase headers with a rule. Content scrolls inside the panel as today.
- No "target" card at the top (tried and dropped by the owner, 2026-10-14). With nothing
  selected the controls stay enabled and send nothing (owner, 2026-10-17; was "disabled
  as today").

### 7h.2 General
- **Power / Shutter / OSD** in one card, one row each: label on the left, two action
  buttons with icons on the right (*On* / *Standby*, *Open* / *Close*, *On* / *Off*). Rows
  are **50 px** with **36 px** buttons, so they are easy to hit (owner, 2026-10-14).
- **Input**: dropdown + *Set*.
- **Lens shift** card:
  - **Home position** is a round 30 px icon button (house) on the right of the card
    header, away from the arrows (owner: not in the centre of the cross, too easy to hit
    by mistake), with the new tooltip (§7g), title only: "Home position". An icon, not a
    labelled pill, so the header stays short (owner, 2026-10-14).
  - The cross keeps today's 12 buttons and speeds (owner: no speed selector): per
    direction three round 34 px buttons, slow / normal / fast from the centre outwards,
    drawn with one, two and three chevrons (the existing `assets/icons/lens_shift/*_slow`,
    `_normal`, `_fast` SVGs, no new artwork); the centre is empty. 5 px between rows, 6 px
    above the cross and 16 px below it.
  - **Focus** and **Zoom** rows, 54 px each: label, three buttons towards near / out, a
    gap, three towards far / in, the same chevron icons.
  - **Lens setup**: a collapsible row (tune icon, "Lens setup", hint "Calibration, lens
    type", chevron), **collapsed by default**. Open, it shows *Calibration* and *Lens
    type*, each a label above a dropdown + *Set*.
- **Test pattern** card: one row with *Off* and the four favourites as thumbnails (the
  existing pattern icons), an empty slot drawn dashed with a + that adds the selected
  pattern; under it the dropdown (with the pattern's thumbnail) + **Show** (was *Set*).

### 7h.3 System
- Cards: **Picture** (Picture mode), **Display** (Back color, Startup logo, Projection
  method), **Shutter fade** (Fade in, Fade out, "seconds" in the header), and a **Quad
  Pixel Drive** row with *On* / *Off*. Each setting is a label above a dropdown + *Set*.
- Option labels follow the UI text rule and sentence case: "Front, ceiling" (was "Front /
  Ceiling"), "1.5 s" (was "1.5s"), "Off" (was "0.0s (OFF)"), "Default logo", "User logo".

### 7h.4 Custom
- One card with a row per command: name (bold), the command in monospace, a **Run** pill
  and a **⋮** menu with *Edit* and *Delete* (Delete through `ConfirmDialog`, §1.2). Under
  the card a dashed **Add command** button and a hint that each command also answers on
  OSC at `/pgrid/all/custom/<name>`.

### 7h.5 Behaviour changes
- Home position moves to the Lens shift header; Lens setup collapses (collapsed by
  default); Edit / Delete of a custom command go into its ⋮ menu; *Set* becomes *Show* for
  test patterns; option labels as in §7h.3.
- Unchanged: commands go to the selected projectors, the motor throttle
  (`_throttledSend`), the keyboard lens shortcuts, the favourites file
  (`test_pattern_favorites.json`) and its add / Ctrl+click remove rules.

---

## 7i. `[x]` Monitoring view

Done 2026-10-19 (wave C, fixes after the owner's check). Differs from the text below:
- Bar: search plus quick filter chips *All*, *Online*, *Attention*, *Offline*, *Standby*
  (outlined chips with counts, always shown, dimmed at 0; a selected filter that empties
  stays selected and shows "No projectors match" with *Show all*). Non-matching projectors
  are hidden, the bar shows "8 of 20"; the filter lives for the session only. *Group by*
  sits left, next to the filters. As the window narrows the filters, then the other
  controls, drop to icons. No group filter and no *Export CSV* yet (deferred by the owner).
- Ctrl+F (Cmd+F) focuses the search; Esc clears it, then closes the projector panel.
- Extended cards show *AC* in place of light hours; compact tiles show a shutter icon next
  to power, and power is red in standby and offline.
- Cards' group rows are a filled band edge to edge, the same height as the table's.
- The panel's Test pattern row has the pattern thumbnail (`TestPatternThumb`).

Boards (dark only): *Monitoring: table, grouped / table with the projector panel / cards,
extended / cards, compact, with the projector panel / table without groups*, each in the
app window at 1600×960. Approved direction 2026-10-14. Today (`monitoring_table.dart`) it is
one wide table of up to 17 single-line columns (Connection, Model, Serial, IP, Power,
Shutter, Input, Signal, runtimes, temperatures, AC, Errors, …) with uppercase state words
(`ON`, `OPEN`, `NO ERRORS`). `MONITORING_UI_PLAN.md` holds the table's existing features
(column chooser, sort, resize, reorder) and the planned filter, search and export; this
section is the look and the new views on top of it.

**Palette** (owner, 2026-10-14): the app's blue-seeded M3 dark tones, as in the dialogs
(`#191C20` background, `#1D2024` bars, `#212429` cards, `#30333A` lines), never a neutral
near-black; secondary text no darker than `#80838D`. The same applies to the toolbar
(§7f) and control bar (§7h) boards.

### 7i.1 Bar above the data
- One 56 px row: **search** ("Search IP, model, serial"), **filter chips** with counts (*All
  20*, *Needs attention 3*, *Offline 1*, *Standby 3*), a group filter (*All groups ▾*) and
  **Group by** (*group* / *none*); on the right the **view switch** *Table / Cards*, in Cards
  also a **density switch** *Compact / Extended*, in Table the column chooser, and *Export
  CSV*.
- No summary tiles above the data (tried and dropped: they repeat the status bar and the
  Alerts window, owner 2026-10-14).

### 7i.2 Table
- **Grouped by group** by default: a group row (colour square, name in near-white, a
  readable summary "8 projectors, 7 online, 1 needs attention", collapse chevron) above its
  projectors. *Group by: none* gives one flat table sorted by the chosen column, with a
  **Group** column (dot + name) instead of the group rows.
- Fewer, two-line columns (9 instead of up to 17): **Projector** (status dot, IP in
  monospace; model under it), **Power** and **Shutter** (icon + word in sentence case:
  *On* / *Standby*, *Open* / *Closed*), **Input, signal** (input; the signal as a **pill**:
  green with the resolution, red *No signal*, grey *Unknown* when offline), **Temperature**
  (In / Ex with small bars, the bar and value amber above the alert threshold),
  **Runtime** (projector hours; light hours under it), **AC**, **Errors** (*None* muted,
  or a badge *Exhaust hot* / *Error F305* / *Offline*), and row actions on hover (Remote
  Preview, ⋮).
- Problem rows carry a 3 px accent on the left: amber warning, red error, grey offline. An
  offline row shows its last known values dimmed and "last seen 16:41" under the model.
- The column chooser keeps working on the new columns; the old single fields stay
  available as optional columns.

### 7i.3 Cards
- **Extended**: five per row at 1600, grouped like the table. Each card: status dot, IP,
  group dot; model; **Power** and **Shutter** pills; then the **Input** block (input name
  large, signal pill as in the table); a problem badge; intake / exhaust with bars,
  runtime and light hours. Problem cards get an amber or red border, offline ones are
  dimmed.
- **Compact** (the former "wall"): 176×96 tiles, grouped: **full IP** (not the last
  octet), power icon, input, signal pill. Warning tiles are tinted amber with the reason in
  the corner (`52 °C`), errors red with the code (`F305`), offline tiles dashed. For big
  installations: many projectors on one screen.

### 7i.4 Projector panel
- Clicking a table row, an extended card or a compact tile opens a 380 px panel from the
  right, **over** the content with a shadow, so the table and cards keep their layout (no
  reflow, owner 2026-10-14). ✕ closes it; the selected row / tile is highlighted.
- Content: header (status dot, IP, model, serial, group), a **Needs attention / Error**
  section with the reason and since when, **Status** (power, shutter, input, signal pill,
  test pattern), **Temperature** gauges with the threshold mark, **Runtime and power**,
  and actions in one row: *Preview*, *Web UI*, *Find on canvas* (labels never wrap).

### 7i.5 New data and open points
- "Last seen" for offline projectors: `ProjectorNode.lastSeen` (done 2026-10-17, before
  wave C). Set when a projector goes offline from the last poll it answered this session,
  null while it answers; telemetry, so `_stripTransient` / `_mergeWithTelemetry` keep an
  undo from rolling it back. The answer time itself stays off the node, so an unchanged
  poll still changes nothing. "Since" for warnings and errors is the alert's own `since`
  (`alertsProvider`), no new field.
- The signal pill is shared: `SignalPill` (`common/status_pill.dart`) over
  `signalStateOf` (`domain/signal_state.dart`), for the table, the cards, the panel and
  the quick status popover (§7j.6).
- Temperature thresholds on the bars come from the alert rules (`AlertRule`).
- *No signal* is red only while the projector is on; in Standby, warming up, cooling or
  offline it is grey, since no signal is expected then (owner, 2026-10-15). Same rule for
  the signal pill in the table, the cards, the panel and the quick status popover (§7j.6).

---

## 7j. `[x]` Projector card (Controls canvas)

Done 2026-10-19 (wave C, fixes after the owner's check). Differs from the text below: the
offline outline is 1 px in the error colour at 60 %, not 1.5 px; a selected card shows
only the selection ring on hover, no second hover outline. The quick status popover's
actions (2026-10-19) are two tonal buttons sharing the footer width, labelled *Monitoring*
and *Preview* with the full names (*Show in Monitoring*, *Remote Preview*) in their
tooltips, as the panel's *Preview* / *Locate*, so both fit the 340 px popover. *Show in
Monitoring* clears a search or quick filter that would hide the projector, expands its
collapsed group and scrolls its row or card to the middle of the view.

Boards (dark only): *Projector card: states, group bands C and D / canvas, group C band
inside / canvas, group D band under / quick status popover / Alignment mode / group
colors x states (C, E, F) / group C muted band, before and after*. Approved 2026-10-15
with group variant **C**, muted. Today (`projector_card.dart`): a grey status bar with a
green / red power icon, a red eye for a closed shutter, the alert badge and a connection
dot; the name and IP below; a grouped card tinted 15% with the group colour and a 9 px pill
under the card.

The card stays a **control target**: it shows what you need before sending a command.
Temperatures, signal details and errors stay in Monitoring (§7i).

### 7j.1 Frame
- Same **120×100** (`kCardWidth` / `kCardHeight`), so saved layouts, snapping and the
  Alignment neighbour rules don't change. Radius 10, 1 px border `#42464E`, a light
  top-to-bottom gradient on the body (`#272B32` to `#212429`).
- **Header band** 26 px, tinted by the power state so it reads from a distance: green when
  on, red in standby, amber while warming up or cooling and when the login fails, strong
  red when offline.
- **Text**: the name in 14 bold. It is the model as read from the projector (`PT-RQ35K`),
  so cards often repeat it. The IP sits under it in the monospace font and tells them apart.
  The test pattern thumbnail (20×12) stays bottom right.

### 7j.2 State colours
| State | Header | Icons |
|---|---|---|
| On, shutter open | green tint | power green, eye green |
| On, shutter closed | green tint | power green, eye-off **red** |
| Warming up / cooling | amber tint | power amber, eye-off red |
| Standby | red tint | power **red** (like the projector LED), eye-off grey |
| Offline | strong red, *Offline* with an unplugged-plug icon | none; red 1.5 px outline, reddish body |
| Login failed | amber tint, *Login failed* with a lock | none |

- The **connection dot is gone**: offline is shown by the whole card, a failed login in
  words. The red outline belongs to offline only, so standby (header tint only) never reads
  as a fault.
- **Right side of the header**: the alert badge (warning amber, error red, with the count
  from 2) and the grey open lock for a projector without a password. Power and shutter
  stay on the left, so a new alert never moves them.

### 7j.3 Group: muted band inside the card (variant C)
- An **18 px band** at the bottom of the card, the group name in 10.5 semibold. The body
  gets shorter by the band; the card keeps its 100 px.
- **Muted** (owner, 2026-10-15): the band is the group colour mixed 55% into the card
  colour (`Color.lerp(cardColor, groupColor, 0.55)`), not the full colour. At full colour a
  red group on a standby card made the whole card read red, an amber group merged with
  warming up and a green one with the "on" header.
- **Text colour** comes from the brightness of the *mixed* colour, not the group colour.
  With today's palette that is light text (`#F4F5F8`, a faint shadow) on every band; black
  text on the muted yellow, green and blue bands was unreadable.
- **No group border**: the card keeps its neutral outline, so a red outline still means
  offline only. The 15% body tint and the pill under the card go away, so nothing hangs
  below the card any more.
- The group palette stays as it is (a reorder that puts red last was drawn and declined).
- A long name ellipsizes. The full name is in the quick status popover (§7j.6) and the
  context menu; no `Tooltip` inside the card, which sits under `MenuAnchor` (the AXTree
  crash the chip's comment describes).
- Offline grouped cards dim the band to 70%.
- Drawn for comparison and not taken: D (a band joined under the card), E (today's pill
  with the 15% body tint: the tint merges with the state header), F (pill only), and a
  grey band with a colour chip. Board *Projector card: group C muted band, before and
  after* shows the change.

### 7j.4 Selection and hover
- **Selected**: a 2.5 px `#AAC7FF` ring 3 px outside the card with a soft blue glow, and a
  blue tint over the body. No check mark (owner). The ring never mixes with the red,
  green or group colours.
- **Hover**: the border turns `#AAC7FF` at 70%.
- In Alignment mode the rings stay as today (orange focused with a glow, pale neighbours,
  60% scrim on closed cards); the band is inside the card, so the ring is unaffected.

### 7j.5 Context menu
- Header: **model and IP** on one line (`PT-RZ120  10.0.1.52`), nothing else.
- Sections split by dividers: *Edit*, *Quick status* (`Space`, §7j.6); *Brightness Control, Color Correction, Geometry
  Correction, Edge Blending*; *Remote Preview, Open in Browser*; *Assign to Group ›,
  Select in Group*; *Delete* in red. Surface `#272A30`, radius 12, 32 px rows, as the
  tooltip (§7g).

### 7j.6 Quick status popover (new)
- **Opens with Space** when exactly one card is selected, **no hover trigger** (owner,
  2026-10-15). Space again or Esc closes it. With no card or several cards selected Space
  does nothing. Not in Alignment mode.
- The binding lives in the canvas `Shortcuts` (`projector_workspace.dart`, Space is free
  there), so it works only while the canvas has focus and never takes a space from a text
  field. Focus stays on the canvas while it is open, so the arrows, I / O and the other
  canvas keys keep working.
- Esc is already bound to `AlignmentExitIntent` in the same map. Alignment and the popover
  never overlap, so Esc maps to one intent whose action closes whichever of the two is
  active.
- **Closes by itself** when the selection changes, the card is dragged or deleted, the
  canvas zooms or scrolls, the view switches to Monitoring, or Alignment mode starts.
- **One popover for the whole canvas**: a single `OverlayPortal` in the workspace, outside
  the cards, placed next to the selected card with an arrow (zoom taken into account,
  flipped at the window edge). Its content watches only that node through `select`, so a
  polling tick doesn't rebuild the canvas. No Material `Tooltip` inside it (`CustomTooltip`
  only).
- **Discoverable**: a *Quick status* item with the `Space` key in the card context menu
  (§7j.5) and a row in Keyboard Shortcuts (§7d).
- **Content**: model, IP, group dot + name; **Power**, **Shutter**, **Input** with the
  signal pill as in Monitoring, **Temperature** (intake, exhaust, amber above the alert
  threshold) and the active alerts. All of it is already in `ProjectorNode` and
  `alertsProvider`, no new fields. "Updated 2 s ago" and "on for 2 h" from the mockup are
  left out (owner, 2026-10-15), and so are light source hours and a selection summary in
  the status bar (both repeat Monitoring, owner 2026-10-15).
- **Actions**: *Remote Preview*, and *Show in Monitoring* (switches the view and opens this
  projector's panel) once the Monitoring panel (§7i.4) exists.

---

## 7k. `[ ]` Event log panel

Boards (dark only): *Event log: the panel in the window, a row hovered / Alerts filter
and search / empty, no match, minimum height, 800 px window, clear / a command sent to
several projectors, collapsed and opened*. Approved 2026-10-19; updated 2026-10-20 to
one *Alerts* chip, *Locate* without glow and the 120 px minimum. Today
(`event_log_panel.dart`): a 34 px bar with a blue *EVENT LOG*, text filter tabs with
counts, a 22 px search field, three 14 px icon buttons; 26 px rows in 11 px text with a
6 px severity dot; a command to several projectors writes one line per projector and a
separate summary line naming models.

The panel stays a docked strip under the canvas, resizable by its grip. It gets the
dialogs' type, fields, chips and icons (`projector-grid-visual-rules`).

### 7k.1 Header
- **56 px**, the toolbar colour. Left: a 30 px `DialogIconTile` with the list icon and
  *Event log* in `cardTitle`, sentence case (the blue capitals go).
- **Filter chips**: outlined, rounded, the count after the name, the selected one in
  `primaryContainer`, as the Monitoring bar (§7i.1), not `SegmentedTabs`. *All*,
  *Alerts* (with a red dot), *Commands*, *Connection*, *OSC* and the new *Web*. *Alerts*
  takes every error and warning of any source (the old *Errors* folds into it, the
  board's *Problems* chip is dropped, decided 2026-10-19) and every alert event, the
  info ones too (acknowledged, cleared), so an alert's history reads in one place.
  Projector error codes come only as their *Projector error* alert (the poll's separate
  `hardware` line, always red even for a warning code, is gone, 2026-10-20). A chip
  with no events stays in place, dimmed (§8 of the visual rules); a selected one that
  empties stays selected.
- *Web* takes the web server's own events (`LogEventType.web`: started, stopped,
  clients, errors) **and the commands sent from the Web page**. The latter are told
  apart only by the command's source, which wave 2 adds; until then *Web* shows the
  server events alone, and that is expected on the wave 1 check.
- **Search log**: a 40 px `dialogFieldDecoration` field with the search icon, the ✕ in
  `Visibility(maintainSize: true)`. It searches IP, model and message; matches are
  highlighted in the row.
- **Buttons**, 36 px icon buttons with `CustomTooltip`s, after a thin divider: *Follow
  new events*, *Copy*, *Clear*, *Close*.
- **Narrow**: chosen from the **panel's width** (it always spans the window), below
  **1120 px**, back to full above **1200 px** (hysteresis as the toolbar, §7f.2), so it doesn't flicker at
  the edge. The title text goes, the chips step down to icon + count with the name in a
  tooltip, the search field narrows. Nothing is dropped. (The board's half-width frames
  only show the compact header; the panel itself is never half width.)
- **Copy** copies what is shown (filter and search applied), one line per row:
  `21:04:12  error  10.0.1.33 PT-RZ120  Projector  Error F305: exhaust fan stopped`, *App*
  where there is no projector (not `–`), the date before the time for an event of an
  earlier day. No SnackBar: the button shows a check for about a second and its tooltip
  reads *Copied 42 events*.

### 7k.2 Columns and rows
- A **column header** under the bar: *Time*, *Projector*, *Source*, *Event* (`label`).
- **Rows 34 px** (was 26), text `body` 14. Time and IP in `mono`, the model after the IP in
  `description`; an event with no projector shows *App* or the group in its place.
- **Time**: today's events show the time only (*21:04:12*); an event from an earlier day
  shows the date before it (*19 Oct 23:58:04*). The log isn't cleared at midnight, so a
  night shift would otherwise mix two days under the same hours. The Time column is
  wide enough for the dated form, so it never changes width.
- **Severity is an icon**, not a dot: red error, amber warning, green success, grey info.
  Error and warning rows get a faint tint of their colour and a 3 px left edge; the
  message stays in the primary text colour, only the icon and the edge carry the colour.
- **Source** is an icon and a word: *Command*, *OSC*, *Connection*, *Alert*, *Web*. The
  Source column hides below about 900 px of panel width. It comes from the event's
  type: `command` *Command*, `osc` *OSC*, `connectivity` *Connection*, `alert` *Alert*,
  `web` *Web*. Wave 1 builds it from that alone; the *from …*
  part of command rows comes with the sources in wave 2.
- **OSC rows** show the address in `mono` and the sender (`from 10.0.0.20`). **Command
  rows** name where the command came from in `description` (*from the control bar*, *from
  OSC*, *from scheduled task "Evening shutdown"*, *from Web, 10.0.0.5 (operator)*).
  Today only the Web API passes a source (`'Web · ip · role'`, which breaks the no `·`
  rule): `sendCommandToSelected`, `sendCommandToGroup(s)` and `sendCommandToAll` take a
  `source` too, and the control bar, OSC and the scheduler pass theirs. The scheduler's
  separate `[Scheduler] "name"` line after the dispatch (`scheduled_tasks_provider.dart`)
  goes; the command row names the task instead.
- **Repeats collapse**: the same event (type, severity, message) from the same projector
  becomes one row with *14 times, last 21:02:41* when that projector logged nothing else
  in between; events of other projectors in between don't break the run (polling
  interleaves them). So a projector that flaps doesn't fill the log.
- **Hover actions** on the right of the row: *Locate*, the short text button as in the
  Monitoring panel (`findOnCanvas`: switches to Controls if needed, selects the card and
  scrolls to it, no glow). The row knows the IP, not the id, so the node is looked up
  by IP and *Locate* is hidden when the projector is gone. *Open alerts* on alert rows
  (the active alerts panel), *Copy row*.

### 7k.3 Commands sent to several projectors
- **One row per command** with a chevron, replacing today's per-projector lines plus the
  separate summary line. *Projector*: the group (*Stage, 6 projectors*), or *8 projectors*
  for a mixed selection or several groups. *Event*: the command, where it came from, and
  pills: green *4 sent*, red *1 failed*, grey *1 skipped*.
- **Severity follows the result**: info when every projector got it, warning when some
  failed or were skipped, so the row shows under *Alerts*.
- **While it runs** the row is there from the first reply: it is built from the batch id,
  the pills count up as replies come in, and the summary event only closes it. So a
  command to 100+ projectors (sent in batches of 100) shows one row from the start
  instead of loose projector lines that fold up at the end.
- **Rows start closed.** A click on the row or the chevron lists every projector by IP and
  model, under a tree line: green *Sent*, red *Failed* with the reason (*no answer within
  5 s*), grey *Skipped* with the reason (*offline*, *wrong login*). Opening a row doesn't
  move the rows above it.
- **Retry failed** (hover action on a row with failures) sends the command again to the
  failed projectors only and logs a new row (*from retry*). The batch keeps the command
  and the failed projectors' ids, not their IPs (an IP can change); a projector removed
  since is skipped.
- A command to **one projector** stays a single row.
- **Search** for an IP finds it inside a group row and opens that row. **Copy** writes the
  summary line and its projector lines.
- **Data**: `LogEvent` gets a batch id (plain Dart, no codegen); `_dispatchToNodes` writes
  the projector lines with it and the summary row last. The list shows the summary and
  folds the lines under it. The cap becomes **500 rows**, not 500 events: a batch with
  its projector lines counts as one row and is dropped whole, so a command to 100
  projectors doesn't take 101 places or lose half its lines at the end of the log
  (decided 2026-10-19). The Web API summary
  (`dispatchSummary`, `web_api_dto.dart`) keeps its text.

### 7k.4 Follow and new events
- **Follow** (the arrow to a bar, before *Copy*) is on by default and blue while on: the
  list stays at the newest event, which is at the top.
- **Scrolling down** to older events turns it off, so the list doesn't move under the
  reader; new events then wait in a *5 new events* pill at the top of the list.
- A click on *Follow* or on the pill goes back to the newest event and turns it on again.

### 7k.5 States, size and Clear
- **Empty**: the tile, *No events yet* and *Commands, connection changes, OSC and alerts
  appear here as they happen*.
- **Nothing matches**: *No events match*, the active filter and search named under it, and
  a *Show all* text button. The filter and search stay; nothing resets on its own.
- **Height**: minimum 120 px (was 100: the 56 px header, the column header and one 34 px
  row; `EventLogPanel.minHeight`), maximum the window minus 150 px.
  Today `main_workspace_screen.dart` clamps `maxLogHeight` to `defaultHeight` (240), so the
  grip can't make the panel taller; the clamp goes. The grip keeps its place on top.
  The 150 px reserve includes the status bar, so in the 600 px minimum window (about
  550 px under the toolbar) the panel reaches about 340 px, in 1280×720 about 470 px,
  in a 1080p window about 830 px.
- **The height is saved** in `appSettingsProvider` and restored on start; when the window
  is smaller than the saved height allows, the panel takes the maximum and the saved
  value stays, so it comes back when the window grows.
- **Clear** opens a `ConfirmDialog` (*Clear the event log?*, *All 486 events are removed.
  Copy them first if you need them.*, a destructive *Clear*), since the log can't be
  brought back.
- An `eventLogRequestProvider` request (alerts only, or a search) still selects *Alerts*
  or fills the search as today.

### 7k.6 Decisions (owner, 2026-10-19)
- *Problems* and *Alerts* are one chip, *Alerts*: errors, warnings and all alert events.
- The log keeps 500 rows; a batch is one row.
- *Locate* instead of *Find on canvas*, as in Monitoring; select and scroll, no glow.
- A batch row appears with the first reply and its pills count up.
- Every command path passes its source; the scheduler's extra line goes.
- Repeats fold per projector, ignoring other projectors' events in between.
- Retry targets the failed projectors by id and skips removed ones.
- The panel height is saved; minimum 120 px so one row always shows, maximum the
  window minus 150 px.
- Three waves, each checked on a trial branch: (1) the look, chips, search with
  highlight, height and Clear confirm; (2) batch rows, sources, Retry; (3) repeats,
  hover actions, Follow.
- Added 2026-10-20: *Web* takes the server events and the Web page's commands (the
  commands from wave 2); the narrow header follows the panel's width (about 1000 px,
  with hysteresis); Copy copies what is shown, *App* for no projector, a check on the
  button instead of a SnackBar; events of an earlier day show their date; the Source
  column comes from the event type in wave 1. The mockup now shows one *Alerts* chip,
  *Locate* and the 120 px minimum.
- After the wave 1 check (2026-10-20): the `hardware` log line and its type are gone
  (the alert carries the code with its real severity); alert messages lose the
  *(critical)* / *(warning)* tail (the icon says it); log messages lose their dashes
  (Web, OSC, Alignment; the command summary goes in wave 2); the model sits on the IP's
  baseline. The narrow header switches at 1120 / 1200 px (the full header needs about
  1100 to 1185 px), the Source column hides below 900 px; the grip is 6 px and the
  column header 24 px so 120 px holds one row.

---

## 7l. `[ ]` Status bar

Boards (dark only): *Status bar: in the window, Offline hovered / today, states, 800 px
window, tooltips*. Approved 2026-10-20. Today (`status_bar.dart`,
`status_bar_alerts_button.dart`, `status_bar_web_clients.dart`): a 36 px
`surfaceContainerHigh` row with *Projectors: 18*, *Online: 15*, *Offline: 2* behind
blue-grey, green and red Material dots, the Alerts button with severity icons and counts,
then on the right *Web: 3 (1 operator)* (hidden while web access is off) and *Last refresh:
21:04:12*, which turns into *Refreshing…* with a spinner while a poll runs, so the bar
changes width every poll.

### 7l.1 Frame
- Same place and height: **36 px**, between the toolbar and the view, shared by Controls
  and Monitoring. The bar colour of the toolbar family, a 1 px `outlineVariant` line
  below, instead of `surfaceContainerHigh`.
- Text in `description`, counts in `body` w600 with tabular figures; the OSC port and the
  time in `monoSmall`. Status colours only for status (`AppStatusColors`), no Material
  `Colors.green` / `Colors.red`.
- Items are 28 px flat buttons, radius 8, a light fill on hover, separated by thin
  vertical dividers into: projectors, alerts, and on the right the services and the time.

### 7l.2 Projectors
- **Projectors 18** and a small **health meter** (84×6, rounded): green online, red
  offline, amber wrong login, in proportion. The amber part appears only when a projector
  has a failed login; there is **no Wrong login count** (rare, and the card already says
  *Login failed*, owner 2026-10-20).
- **Online 15** and **Offline 2** with a status dot. A count at 0 stays in place, dimmed.
- Each count is a button: it switches to **Monitoring with the matching quick filter**
  (*Online*, *Offline*, §7i).
- **Offline tooltip** (§7g): the title *2 offline*, then one row per projector, IP in mono
  and the model, in Monitoring order (group, then IP), **5 rows at most** and then *and 12
  more*; the last line *Click to show them in Monitoring* in tertiary. When every projector
  is offline: *All 18 offline*, *Check the network connection*, no list. The **Online
  tooltip** has no list: *15 online* and the click line.
- Counts come from `statusSummaryProvider`, which gains the wrong-login count for the
  meter; the tooltip list `select`s the offline nodes only while it is open.

### 7l.3 Alerts
- *Alerts* and one **pill per severity** (`caption` w600): critical red and warning amber,
  **filled** with a filled icon while unacknowledged, **outlined** once all are
  acknowledged, green for alerts that are over and not acknowledged. Nothing active:
  *None* with an outlined green check.
- Opens Active alerts as today; the button stays pressed (fill) while the panel is open.
  The counts and rules are unchanged (`alertCountsProvider`; the green pill is its
  existing `recovered`).
- The severity pills are a **shared widget** in `widgets/common/` from the start, not
  private to `status_bar_alerts_button.dart`: the alerts panels' group headers and
  sections (§7m.3) use the same one (owner, 2026-10-20).

### 7l.4 OSC and Web (right side)
- **OSC (new)**: a green dot and the port (*OSC 9000*) while listening. When OSC is on
  in the settings but the port can't be opened: a red dot and *port busy* in red, so a
  failure never looks like "off". A click opens Preferences on OSC. Tooltip: *OSC on port
  9000*, *Status to 10.0.0.20 port 9001*; on error, warning variant *OSC port 9000 is in
  use*, *Choose another in Preferences*.
- **Web**: a green globe, *Web 3* and *(1 operator)* in tertiary; *Web 0* with a grey
  globe when no page is open. Tooltip *Web access, 3 pages open* and a row per page (IP in
  mono, role). A click opens Preferences on Web Access, as today.
- **Both are hidden while switched off** in Preferences, as Web is today (owner,
  2026-10-20): that only changes from Preferences, never during work, so the shift of
  the items to their left is acceptable.
- The OSC error state comes **only from an explicit bind failure** that `oscProvider`
  reports (today its state is only running / not running), never from "on in the
  settings but not running": that is also true for a moment at start and while the
  service restarts on a new port, and must not flash *port busy* (owner, 2026-10-20).

### 7l.5 Updated
- **Updated 21:04:12** replaces *Last refresh* and *Refreshing…*. The time always stays;
  while a poll runs only the clock icon becomes a 12 px spinner (still inside its
  `RepaintBoundary`), so the bar never changes width.
- Tooltip *Updated 21:04:12*, *Polling every 5 s*.
- ~~**Polling late**~~ `[dropped]` (owner, 2026-10-20): with many projectors a full pass
  can rightly take longer than an interval, so "3 intervals without a poll" would turn
  amber with nothing wrong. The time never changes colour.

### 7l.6 Narrow window
- Below about 1000 px the words step down to icons and counts with the names in
  tooltips, as the toolbar does (§7f.2): the meter and *18*, dots and counts, the alert
  pills without *Alerts*, the OSC dot and port, the globe and count, the time without
  *Updated*. Nothing is dropped. Chosen from the window width with hysteresis, not from
  measured content.

---

## 7m. `[ ]` Alerts panels

Boards (dark only): *Alerts panel: in the window, grouped by projector, a row hovered /
grouped by alert, project groups, a long message / empty, all acknowledged, no match, one
projector*. Approved 2026-10-20. Today (`active_alerts_panel.dart`,
`projector_alert_panel.dart`, `alert_row.dart`, `alert_panel_parts.dart`): a 404 px
`surfaceContainerHigh` panel, radius 12, 6 px inset; a 32 px header with three unlabelled
icon buttons (Fold all, Acknowledge all, Open event log); 24 px chips with severity icons
only; rows of 46 px whose message is large, bold and in the severity colour, with a
tinted icon tile, a duration and a start time stacked, and an outlined blue 26 px
Acknowledge square; section headers in capitals; *ACKNOWLEDGED (2)*.

Behaviour stays: anchored to the status bar's Alerts button (§7l.3) and to the card
badge, grouped by projector or by alert, optionally in project groups, the severity
filter, acknowledged alerts folded at the bottom, groups folded past 4.

### 7m.1 Frame
- The menu surface (`surfaceContainerHigh`, 1 px `outlineVariant`), radius **14**, the
  popover shadow, no inset: the list and the footer run edge to edge. Width **420**
  (Active alerts) and **340** (one projector, from the card badge).
- **Header 52 px**: *Active alerts* in `cardTitle` and *4 active* in `description`
  (*3 acknowledged* when nothing is left); on the right 32 px icon buttons with
  `CustomTooltip`s: *Sort into project groups* (filled `primaryContainer` while on), the
  grouping switch *By projector* / *By alert* (two icons in the `SegmentedTabs` style)
  and *Fold all* / *Unfold all*. The one-projector panel's header is the model in
  `cardTitle`, the IP in `monoSmall` and its severity pills.
- **Filters** on their own row under the header: outlined 30 px chips with words, *All 4*,
  *Critical 2*, *Warning 1*, the severity icon before the word, the selected one in
  `primaryContainer` (as Monitoring and the event log). A chip at 0 stays, dimmed.
- **Footer 56 px**, as the dialogs: *Event log* (list icon) as a text button on the left,
  **Acknowledge all** as the **filled** button on the right, the panel's one main action
  (owner, 2026-10-20: not `primaryContainer`, that is only the control bar's send
  buttons). With nothing to acknowledge it is disabled, never removed. The one-projector
  panel's *Event log* opens the log searched for its IP, as today.

### 7m.2 Rows
- **52 px**, **70** when the message needs a second line (the message wraps to two lines
  at most, then ellipsizes); a `DialogSurfaces.soft`-like fill, radius 10, indented under
  its group.
- Left a **3 px severity edge** (critical red, warning amber, over green), then the
  severity icon 18 px; both **centred on the row's height**, as the time and the
  Acknowledge button (owner, 2026-10-20).
- Text: the **message** in `body` w500, **white**, not in the severity colour; under it in
  `description` the alert kind (*Projector error*, *Temperature*), or, grouped by alert,
  the projector as IP in mono and the model on the first line with the message under it.
- An alert that is over and not acknowledged: green check and edge, *Signal lost, over
  at 21:03* with the time part in green.
- On the right the **start time** in `monoSmall` (one value; the duration goes into the
  tooltip, *Started 21:04, 6 min ago*) and **Acknowledge**: a quiet 30 px icon button
  (check, `secondary`), filled `primaryContainer` on hover, tooltip *Acknowledge*.
  Groups and sections take the double check (*Acknowledge projector*, *Acknowledge
  alert group*, *Acknowledge Stage*).
- The row height comes from the message's line count, measured with the ambient style
  (§8 of the visual rules), so `AlertScrollArea` still counts the hidden rows.

### 7m.3 Group headers and sections
- **Projector group** 36 px: chevron, the IP in mono and the model in `description`,
  then on the right the severity pills of the status bar (filled critical / warning,
  green over) and the double-check button.
- **Alert group** 36 px: chevron, the severity icon, the alert kind in w600 and *2
  projectors* in `description` (the earliest start in its tooltip), its pills and the
  double check.
- **Project group section** 30 px: chevron, the group colour square, the name in sentence
  case (`label`, not capitals) and *2 projectors* in `caption`, pills, double check.
- **Acknowledged** fold at the bottom: *Acknowledged 3* in `label` after a divider; its
  lines 30 px: the outlined severity icon, the IP in mono, the message, the start time in
  tertiary mono.

### 7m.4 Empty and filtered
- Nothing active: a tile with a green check, *No active alerts*, *Everything is within
  limits. Past alerts are in the event log*; the footer keeps *Event log* only.
- All acknowledged: a tile with the double check, *All acknowledged*, *These alerts are
  still active and leave the list when the condition clears*, the acknowledged lines
  open under it, *Acknowledge all* disabled.
- A filter that hides everything: *No warnings*, *2 critical alerts are hidden by the
  filter* and a *Show all* text button; the filter stays selected.

### 7m.5 Notes
- `AlertPalette.text` (the severity text tones) is no longer used for messages; the
  severity colours come from `AppStatusColors` like the rest of the app.
- Tooltips through `CustomTooltip` only: the Material `Tooltip` is what broke the
  accessibility tree under `MenuAnchor` (the reason the panels have none today).

---

## 8. Order

1. **Foundation** (§1): `DialogTitleBar` icon + all dialogs migrated in one go (the change is
   mechanical: one `icon:` argument each), dialog radius in the theme, `ConfirmDialog` and the
   six confirmations, the theme extension and monospace style (§1.5), the shared pieces
   (§1.3) and the adaptive-layout rule (§1.4) applied to the dialogs that aren't redesigned
   later (Preferences). Visible app-wide, low risk — ship it first. The new tooltip (§7g)
   goes in the same step: one widget, used everywhere.
2. **Groups** (§3): smallest of the three; brings `GroupColorPalette` and `collapseIpRanges`.
3. **Add Projectors + Edit Projector** (§2): reuses `collapseIpRanges`; last-used
   credentials setting; the login card is one widget shared by both dialogs.
4. **Brightness Control** (§5): self-contained, one file; brings the projector in the title
   bar (§1.1).
5. **Color Correction** (§6): one file; reuses `SegmentedTabs` and the debounce from
   Brightness Control.
6. **Geometry Correction** (§7): one file; mode tiles, grouped sliders, corner steppers,
   adaptive layout (§1.4). The Keystone / Curved preview lands in the same step
   (`GEOMETRY_PREVIEW_PLAN.md` §2.5): the pure model and its tests first, then the painter.
7. **Edge Blending** (§7a): the `edge_blending/` widgets; reuses the Geometry frame (mode
   tiles, canvas card + controls card). The canvas painter keeps its logic and gets the new
   colours, legend and placeholders.
8. **Remote Preview** (§7b): `remote_preview_dialog.dart` and `preview_viewport.dart`;
   restyle only, no new data.
9. **Custom Command** (§7c): one file, small; can ride along with the foundation step.
10. **Keyboard Shortcuts and About** (§7d, §7e): two small files; the shortcut search
    filter goes to `domain/`.
11. **Main toolbar** (§7f): `toolbar.dart`; the missed-run badge colour waits for §4.8
    (deferred).
12. **Control bar** (§7h): `control_bar.dart`; split into one widget per card while at it
    (the file is ~1300 lines).
13. **Projector card** (§7j): `projector_card.dart` and `alert_badge.dart`; state colours,
    the group band and the selection ring first, then the context menu, then the quick
    status popover; its *Show in Monitoring* action is added with the Monitoring panel in
    step 14.
14. **Monitoring view** (§7i): table restyle and grouping first (it builds on
    `monitoring_table.dart` and `MONITORING_UI_PLAN.md`), then Cards (compact / extended)
    and the projector panel, then filter / search / export.
15. **Scheduled Tasks** (§4): largest; model change (`targetGroupIds`), one dialog instead
   of two, command picker. Missed runs and their state file (§4.8) are deferred to a later
   step of their own.
16. **Event log panel** (§7k): `event_log_panel.dart` split into header, row and batch row
    widgets; three waves (§7k.6): the restyle, chips, search, height and Clear first,
    then the batch id, grouped command rows, sources and Retry, then repeats, hover
    actions and Follow.
17. **Status bar** (§7l): `status_bar.dart` and its two item widgets; the restyle, the
    meter, *Updated* and the shared severity pills (`widgets/common/`) first, then the
    count buttons and tooltips, then the OSC item with the bind error in `oscProvider`.
18. **Alerts panels** (§7m): `alert_row.dart` and `alert_panel_parts.dart` first (both
    panels share them), then the header, filters and footer of `active_alerts_panel.dart`
    and `projector_alert_panel.dart`. Goes with or after the status bar, whose pills it
    reuses.

Each step: behaviour change only where this plan says so; `flutter analyze`, `dart format`,
tests below, then a GUI check in both themes (`flutter-windows-gui-check`).

---

## 9. Tests

- **Unit** (`test/unit/`): `collapseIpRanges`; first unused group colour; target chip label
  ("Main stage" / "N groups"); command picker search; project-file migration
  `targetGroupId` → `targetGroupIds` (old file read as a one-item list, both fields
  written).
- `[later]` with §4.8: unit `isTaskDue` with the 2-minute grace and `missedOccurrences`
  (daily / weekly / once, gaps over midnight and weekday boundaries, no state file);
  provider (`fake_async`) app "closed" over a run → missed record, no command sent, a late
  one-time task is not executed.
- **Provider**: deleting a group strips it from tasks; last-used credentials saved after an
  add.
- **Widget**: `DialogTitleBar` renders icon + title + close; `ConfirmDialog` returns
  true/false; Edit Projector: IP check states, port saved, wrong-login state shown for an
  `unauthorized` node; Manage Groups inline edit and the new-group form open/close; Scheduled Tasks
  select → edit → save; command picker filters and picks; Brightness Control: Max card locked
  outside User modes, Light output capped at Max in a User mode, a burst of + presses sends
  one `LOPI2` write (`FakeProtocolService`); Color Correction: the tile row has 3 or 7 tiles
  by method, Reset sends the default triple, the temperature mode tiles are disabled while
  matching is on, a preset chip sends one `OTE`; Geometry Correction: the Quad Pixel Drive
  note per tier (A full, B short, none hidden), a corner H stepper sends that corner's `GMFI`
  pair clamped to the tier limit, Reset in Keystone sends the four zeros and keeps `GMKS0`,
  the Linearity / Pincushion rows are disabled in Auto, a corner drag lands on the right
  value with the canvas scaled below 1 (§1.4); every redesigned dialog lays out without
  overflow in an 800×600 window;
  Edge Blending: a disabled edge's card collapses and its border width field is disabled,
  the A / B segmented switches the active projector, the Markers toggle writes both in a
  pair and only the replying one when the other is silent, the Off note is shown;
  Remote Preview: the Pre-show subtitle per state, the grid caption with model + IP, the
  frame colour per shutter; unit test for `previewSignalTag` in its new form;
  Custom Command: both OSC addresses follow the name, a taken address names the command
  and disables Add, the Edit footer note; Keyboard Shortcuts: the search filters by
  description and key and hides empty sections (plus a unit test of the filter); About:
  version and build shown, each link row opens its target; main toolbar: compact below
  the threshold and full above it with hysteresis, a badge value change keeps every button's
  position (same `Offset` before and after), zero hides the badge, `9+`; tooltip: title,
  detail, shortcut and warning variants render, the arrow follows the placement; control
  bar: Home position sends `kLensHomeCommand`, Lens setup starts collapsed and opens, each
  of the 12 cross buttons sends its axis / direction / speed, a custom command's ⋮ menu
  edits and deletes (with confirm), controls enabled without a selection and sending
  nothing; Monitoring:
  group rows and *Group by: none*, the signal pill per state, the panel opens over the
  table without changing column widths, Compact / Extended switch, offline rows dimmed;
  projector card: header tint and icon colours per power / shutter state, the red
  outline only when offline, *Login failed* for an `unauthorized` node, the group band
  with the group name and none for an ungrouped card, the band colour is the 55% mix and
  its text colour follows the mixed colour, no group border, the selection ring, an alert
  appearing doesn't move the power icon (same `Offset`), the context menu header shows
  model + IP, the quick status popover opens with Space for one selected card only, closes
  on Space / Esc / a selection change / a drag, and doesn't open in Alignment mode;
  event log: each chip filters as listed and *Alerts* takes errors, warnings and info
  alert events, an empty chip stays in place dimmed, a command to several projectors
  shows one closed row with the right pills and severity and opens to its projector
  lines, the row is there after the first reply and its pills count up, a command to one
  projector stays one row, a search for an IP opens its group row, repeats collapse with
  the count across other projectors' events, *Locate* is hidden for a removed projector,
  Retry sends to the failed ids only, Follow turns off on scroll and the pill brings it
  back, Clear asks first, the panel grows past 240 px and its height is restored; unit
  tests for the repeat folding, the batch grouping and the 500-row cap dropping a batch
  whole (pure functions in `domain/`);
  status bar: the meter's parts follow online / wrong login / offline and the amber part
  is absent without a failed login, a count at 0 stays in place dimmed, a click on
  Offline opens Monitoring with the Offline filter, the Offline tooltip shows 5 rows and
  "and N more" and the all-offline text, OSC and Web hidden while off, *port busy* only
  on a bind failure and not while the service is starting or restarting, the bar keeps
  its width while polling (same `Size` before and during), at an **800 px** window the
  compact bar lays out without overflow in both themes and with every item shown (OSC,
  Web, all three alert pills, the largest counts); a unit test for the tooltip list
  (pure function in `domain/`);
  alerts panels: the message is in the primary text colour and only the icon and edge
  carry the severity, a long message takes two lines and the row grows to 70, the icon,
  time and Acknowledge share the row's centre line, Acknowledge all is a filled button
  and disabled (same `Size`) when nothing is left, a chip at 0 stays dimmed, the filter
  with no match shows *Show all*, both groupings and the project-group sections render
  with their pills;
  `DialogTitleBar` with a projector id shows model + IP, the group pill only for a grouped
  projector, and the status badge, and the badge follows the node going offline while the
  dialog is open.

---

## 10. Open questions

- ~~A scheduled task whose target groups were all deleted~~ — decided 2026-10-13: paused
  (§4.5).
- ~~Icons in §1.1~~ — confirmed 2026-10-19 as they are in the code; the menus that open a
  dialog (card context menu, Alignment *Adjust*, the Remote Preview buttons) use the same
  icon as its title bar.
- ~~Scheduled Tasks master-detail, unsaved edits (§4.1)~~ — decided 2026-10-15: a
  `ConfirmDialog` "Discard changes?".
- ~~Monitoring, No signal colour (§7i.5)~~ — decided 2026-10-15: grey while the projector
  isn't on.
- ~~Color Matching defaults (§6.5)~~ — decided 2026-10-15: the `_values3` / `_values7`
  initial values are the factory defaults.
- ~~Geometry preview in Keystone / Curved (§7.4)~~ — decided 2026-10-15: drawn from VSS
  screenshots the owner provides. Replaced 2026-10-16: drawn from camera measurements of
  the projector (VSS differs from it), `GEOMETRY_PREVIEW_PLAN.md`.
- ~~Compact Geometry layout (§7.7)~~ — decided 2026-10-15: no separate mode, every dialog
  adapts to the window down to 800×600 (§1.4).
- ~~Missed runs, when~~ — decided 2026-10-15: deferred (§4.8).
- ~~Edit Projector: card or title bar~~ — decided 2026-10-14: it keeps its projector card
  (§2.6), since it shows the address being edited.
- ~~Missed runs~~ — decided 2026-10-13: never run late, one-time and recurring alike; shown
  in their own Missed list (§4.8).
- ~~Projector card group marker~~ — decided 2026-10-15: muted band inside the card (§7j.3,
  variant C).
- ~~Quick status popover trigger (§7j.6)~~ — decided 2026-10-15: Space for one selected
  card, no hover, no new model fields.
- ~~Event log, commands to several projectors (§7k.3)~~ — decided 2026-10-19: one closed
  row per command with result pills, opened to the projector lines by IP and model.
- ~~Event log filters, cap, Locate, sources, repeats, height (§7k.6)~~ — decided
  2026-10-19: one *Alerts* chip, 500 rows, *Locate* without glow, a source on every
  command path, per-projector repeats, saved height, minimum 120 px.
- ~~Status bar, wrong login and services that are off (§7l)~~ — decided 2026-10-20: no
  Wrong login count, only the amber part of the meter; OSC and Web hidden while off, OSC
  shown red when its port is busy, from an explicit bind failure only; no *Polling late*
  state; the severity pills a shared widget; an 800 px no-overflow test.
- ~~Alerts panels, colour and main button (§7m)~~ — decided 2026-10-20: messages in white
  with the colour in the icon and edge, icons centred in the row, Acknowledge all as the
  filled button in a footer.
