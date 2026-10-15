# Dialog Redesign Plan

Status: `[ ]` pending · `[~]` in progress · `[x]` done · `[dropped]` not doing · `[later]` deferred

Design approved by the owner on 2026-10-13. Mockups (light and dark for every board,
Geometry Correction, Edge Blending, Remote Preview, Custom Command, Keyboard Shortcuts,
About, the main toolbar, the tooltip, the control bar, the Monitoring view and the
projector card dark only; the tooltip also in light):
https://claude.ai/artifact/AL2c8Kh9aoXrrv2eUmVdcJ (canvas *Projector Grid dialogs redesign*).
Roadmap item: `ROADMAP_PLAN.md` §13 (U7).

The redesign covers twelve dialogs in depth (Add Projectors, Edit Projector, Groups,
Scheduled Tasks, Brightness Control, Color Correction, Geometry Correction, Edge Blending,
Remote Preview, Custom Command, Keyboard Shortcuts, About), the main toolbar, the
tooltip, the control bar, the Monitoring view and the projector card on the Controls
canvas (§7f, §7g, §7h, §7i, §7j), and one
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

## 1. `[ ]` Shared foundation (all dialogs)

### 1.1 Title bar with an icon
`DialogTitleBar` (`presentation/widgets/dialog_title_bar.dart`) is used by every dialog, so
changing it changes them all.

- New required parameter `icon` (`IconData`). Layout, left to right: **icon tile** 30×30,
  radius 8, `primaryContainer` fill, icon 18 px in `onPrimaryContainer`; gap 12; title
  (`titleMedium`, weight 500); close button 40×40, circular, `onSurfaceVariant`.
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
| Add Projectors | `add_projector_dialog.dart` | `videocam` / projector glyph (as in the mockup) |
| Edit Projector | `edit_projector_dialog.dart` | `edit` |
| Manage Groups, New Group | `manage_groups_dialog.dart` | `layers` |
| Scheduled Tasks | `scheduled_tasks_dialog.dart` | `schedule` |
| Custom Command | `custom_command_dialog.dart` | `code` |
| Geometry Correction | `geometry_correction_dialog.dart` | `crop_free` (mockup: trapezoid with corner dots) |
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
`projector` (`ProjectorNode`) instead. The bar then shows:
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

### 1.3 Shared pieces built for the three dialogs
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

---

## 2. `[ ]` Add Projectors

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

## 3. `[ ]` Groups

Boards: *Groups: inline editor / delete confirm / new group / new group from context menu /
new group from context menu, 60 projectors*.

### 3.1 Manage Groups
- Width **560** (today wider), height 640. Same width as the compact New Group dialog, so the
  palette tiles come out square in both.
- Header row: "4 groups, 16 of 20 projectors assigned" and a tonal **New group** button.
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

---

## 4. `[ ]` Scheduled Tasks

Boards: *Scheduled Tasks: weekly task / new task, validation / command picker / many tasks,
10 groups / completed tasks*. Dialog 980×660.

### 4.1 One master-detail dialog
Today the list and the editor are two dialogs (`ScheduledTasksDialog` opens
`_ScheduledTaskEditorDialog`). They become **one**: list on the left (330 px), editor on the
right. Selecting a card loads it into the editor; *New task* adds a dashed **New** card at
the top of the list and an empty editor.

### 4.2 Task list
- Header: "14 tasks, 12 active" and a tonal *New task* (disabled while a new task is open).
- Card: time (22 px, tabular), active switch; command + **target chip**; schedule line
  (weekday dots for weekly, "Every day", "Once, Sun 18 Oct") and "Next: Tue 13 Oct" /
  "Paused". Paused cards are dimmed. Selected card: primary border + ring.
- **Target chip**: All projectors; one group → dot + name; **two or more groups → up to five
  stacked dots + "N groups"**, the names in a tooltip. Same width whether 2 or 30 groups.
- The list **scrolls**: scrollbar, fade at the bottom (and top when scrolled).
- Two sections under the active tasks, each a collapsible header row with its count and
  *Clear* when expanded (owner, 2026-10-13):
  - **Missed N** — one row per missed run (§4.8): muted card, no switch, amber line
    "⚠ Missed Tue 13 Oct, 08:00". For a recurring task the task itself stays in the active
    list; the Missed row is only the record of that run. Selecting the row opens the task.
  - **Completed N** — one-time tasks that ran: muted card, no switch, green line
    "✓ Ran Sat 10 Oct, 18:00".
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
- Click opens a **panel** under the field, full editor width:
  - search field on top ("Search commands, e.g. hdmi, shutter"), focused on open;
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
  (`List<String>`). Project files: read the old single field as a one-item list; write the
  new field only. Tasks are saved in the project file (`project_provider.dart`), so bump its
  format version.
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

### 4.8 Missed runs (behaviour change, decided 2026-10-13)
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

## 5. `[ ]` Brightness Control

Boards: *Brightness Control: Normal mode / User 2 mode / reading values*. Approved
2026-10-14. Today (`brightness_control_dialog.dart`) it is a 460 px `AlertDialog` titled
`Brightness Control - <IP>` with an Operating Mode dropdown and two bare sliders.

- Dialog **560×594**, title bar icon `brightness_6`, title **Brightness Control** without
  the IP.
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

## 6. `[ ]` Color Correction

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
  `_values3` / `_values7` initial values) with one `VMR` / `VMG` / `VMB` or `C7CS<n>` write.
- **Changed** dot and subtitle: computed against the same defaults; only the active method's
  values are read, so only its tiles show dots.
- **Temperature presets** (§6.4).
- **Stepper inputs** for every RGB and white-balance value: typing a value commits on Enter
  or focus loss and sends one write, like a slider release.
- Load stays as today: only the active method's and mode's registers are queried.

---

## 7. `[ ]` Geometry Correction

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

**Preview in Keystone and Curved:** approved to add. The drawing should follow how VSS
renders these modes; the owner will work that out later. The unused `_TrapezoidPainter` in
the dialog is the starting point. Until then the mockup's schematic is the target layout.

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

### 7.7 Minimum window
The app's minimum window is 800×600 (`main.dart`); with the `Dialog` insets and the 90 %
height cap the dialog gets about **720×510**. Below a dialog width of about **880** a compact
layout is used:
- Mode tiles 40 px with short labels (*Off*, *Keystone*, *Curved*, *Corner*); the full name
  in a tooltip.
- Preview / canvas card 360 px; the canvas scales down, handles drawn larger to stay easy to
  grab. The keyboard hint moves into a keyboard icon (tooltip) in the canvas header; the
  legend is one line (*Corner range*).
- The controls card **scrolls**, with a scrollbar and a fade at the bottom.
- Corners become a **list of four rows** (corner, changed dot, H, V) instead of the 2×2 grid.
- Off: no large icon, a shorter line, the three mode cards and the Quad Pixel Drive note.

### 7.8 Behaviour changes
- **Numeric H / V per corner**: typing commits on Enter or focus loss, clamps to the corner's
  limits for the model's tier (`cornerInwardH/V`, `cornerOutwardH/V`) and sends that corner's
  `GMFI` pair, like a drag release.
- **Reset** in Keystone writes 0 to `GMKS8`, `GMKS9`, `GMKI4`, `GMKI7`; in Curved to `GMCI2`,
  `GMCI3`, `GMCI6`, `GMCI7`, `GMCS8`, `GMCS9`. Throw ratio and Maintain aspect ratio are kept.
  **Reset all** in Corner stays as today (the eight `GMFI` corner values).
- **Quad Pixel Drive note** by tier (§7.2).
- **Preview** in Keystone and Curved (§7.4, after the VSS study).
- **Loading** layout (§7.6) and the compact layout (§7.7).

---

## 7a. `[ ]` Edge Blending

Boards (dark only): *Edge Blending: one projector, Right edge selected / Black Level tab /
mode Off / pair side by side, linked / pair, B not replying*. Approved 2026-10-14, after the
Black Level rework in `EDGE_BLENDING_PLAN.md` stage 8 (R, G, B only; zones measured from the
zone end; limits where border lines never cross). Today (`edge_blending/`) the dialog is up
to 960 wide and 90 % of the screen high, titled `Edge Blending - <IP>` (a pair: the two
names), with a `SegmentedButton` Off / On / User, an underlined `TabBar`,
`DialogSplitLayout` (canvas left, panel right), the Markers and Auto test pattern switches
above the edge cards, and in a pair the panel header "Switch on the canvas".

### 7a.1 Frame
- Dialog **960×800**, title bar icon `gradient` (mockup: two overlapping frames), title
  **Edge Blending**, projector in the title bar (§1.1). A pair shows both:
  `Pair: RQ25K (192.168.0.41), RQ25K (192.168.0.42)`; the group pill when both are in the
  same group; the status badge reads *Online* while both reply, amber *B not replying*
  otherwise.
- **Mode tiles** (54 px, icon + label + one muted line): *Off* "No blending", *On* "Built-in
  blend curve", *User* "Curve stored on the projector". A pair with mixed modes selects none,
  as today.
- **Tabs** in `SegmentedTabs`: *Edge Blending* with a pill (`2 edges`, `Linked`, `Off`) and
  *Black Level* with the Black Level Mode (`Soft edge + level`, `Black level only`).
- Body: **canvas card** on the left (480 px) and a **controls card** on the right. Footer:
  info line "Changes are sent to the projector right away", no button.
- **Canvas card header**: left side empty for one projector; in a pair the arrangement
  segmented *Side by side / Stacked* and the swap button. Right side, **in the same place in
  both**: icon toggles **Markers** (a custom icon: image frame with two dashed vertical
  lines, the Start and zone end lines the markers draw; `CustomPaint`, no Material icon fits)
  and **Auto test pattern** (frame with a grid), then *Reset all* as an icon button. The
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

## 7b. `[ ]` Remote Preview

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
  Web API preview stream, so the web page's tag changes with it.
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

## 7c. `[ ]` Custom Command (Add / Edit Command)

Boards (dark only): *Add Command: empty / filled / OSC address taken*, *Edit Command*.
Approved 2026-10-14. Today (`custom_command_dialog.dart`) it is 400 wide with two outlined
fields (label inside), a one-line OSC preview (`/pgrid/all/custom/<slug>`) and *Cancel* /
*Add* (*Save* when editing).

### 7c.1 Layout
- Dialog **520×500**, title bar icon `code`, title **Add Command** / **Edit Command**. No
  projector in the title bar: a command isn't tied to one projector.
- **Name**: label above the field (as in Groups and Add Projectors), focused on open, help
  line "Shown on the button and used for the OSC address".
- **Command**: monospace field, help line "Sent as is to the selected projectors, in
  NTCONTROL form". Placeholder `OSH:1` (a known-good command; the mockup's `VXX:DYNI0=+00001`
  was only an illustration).
- **OSC addresses** card, always shown at its full height so nothing moves while typing:
  header with the OSC icon and "Follow the name" on the right, two rows, label above a
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

## 7d. `[ ]` Keyboard Shortcuts

Boards (dark only): *Keyboard Shortcuts*, *Keyboard Shortcuts: search*. Approved 2026-10-14.
Today (`keyboard_shortcuts_dialog.dart`) it is 560×620, one long list of eight sections
under uppercase headers, keys as monospace badges, and some descriptions with dashes
("Lens shift — normal speed", "Zoom in / out (50 – 200%)").

- Dialog **860×680**, title bar icon `keyboard`, no footer.
- **Search field** on top, focused on open: "Search shortcuts, e.g. shutter, zoom, undo",
  the count on the right (`33 shortcuts`; while searching `5 of 33` and a clear button).
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

## 7e. `[ ]` About

Board (dark only): *About*. Approved 2026-10-14, after a look at what About windows usually
hold (macOS: icon, name, version, copyright, optional credits; GNOME / libadwaita: centred
header, links as rows with icons; Flutter: `showAboutDialog` with name, version, legalese
and a licenses button). Today (`about_dialog.dart`) it is 360 wide: name, `Version x`, a
one-line description, "Author", `© 2025-2026` and *View Licenses*.

- Dialog **480×615**, title bar icon `info`, everything centred.
- **Header**: the app icon (the launcher icon artwork, 80 px, radius 18, soft shadow),
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

## 7f. `[ ]` Main toolbar

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
- State is shown by **colour, not text**: missed runs (§4.8) turn the Scheduled tasks
  badge amber with the same number; the tooltip says "12 active, 1 missed run".
- The counts come from `select`-ed providers (group count, active / missed task counts),
  so the toolbar doesn't rebuild on every polling tick.

---

## 7g. `[ ]` Tooltip

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
  lines go. One change in one widget restyles every tooltip in the app.

---

## 7h. `[ ]` Control bar

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
  selected the controls are disabled as today.

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
    drawn with one, two and three chevrons; the centre is empty. 5 px between rows, 6 px
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

## 7i. `[ ]` Monitoring view

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
- "Last seen" for offline projectors and "since" for warnings and errors: not stored
  today, needed for the offline rows and the panel.
- Temperature thresholds on the bars come from the alert rules (`AlertRule`).
- Open: *No signal* is red everywhere, also on projectors in Standby, where no signal is
  expected; proposed to show it grey while the projector isn't on.

---

## 7j. `[ ]` Projector card (Controls canvas)

Boards (dark only): *Projector card: states, group bands C and D / canvas, group C band
inside / canvas, group D band under / quick status popover / Alignment mode*. Approved
2026-10-15 with group variant **C**. Today (`projector_card.dart`): a grey status bar with a
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

### 7j.3 Group: band inside the card (variant C)
- An **18 px band** at the bottom of the card, filled with the group colour, the group name
  in 10.5 semibold, black or white by `estimateBrightnessForColor` as today's chip. The
  body gets shorter by the band; the card keeps its 100 px.
- The border takes the group colour at 55%. The 15% body tint and the pill under the card
  go away, so nothing hangs below the card any more.
- A long name ellipsizes. The full name is in the quick status popover (§7j.6) and the
  context menu; no `Tooltip` inside the card, which sits under `MenuAnchor` (the AXTree
  crash the chip's comment describes).
- Offline grouped cards dim the band to 55%.
- Variant D (a 20 px band joined under the card) was drawn for comparison and not taken.

### 7j.4 Selection and hover
- **Selected**: a 2.5 px `#AAC7FF` ring 3 px outside the card with a soft blue glow, and a
  blue tint over the body. No check mark (owner). The ring never mixes with the red,
  green or group colours.
- **Hover**: the border turns `#AAC7FF` at 70%.
- In Alignment mode the rings stay as today (orange focused with a glow, pale neighbours,
  60% scrim on closed cards); the band is inside the card, so the ring is unaffected.

### 7j.5 Context menu
- Header: **model and IP** on one line (`PT-RZ120  10.0.1.52`), nothing else.
- Sections split by dividers: *Edit*; *Brightness Control, Color Correction, Geometry
  Correction, Edge Blending*; *Remote Preview, Open in Browser*; *Assign to Group ›,
  Select in Group*; *Delete* in red. Surface `#272A30`, radius 12, 32 px rows, as the
  tooltip (§7g).

### 7j.6 Quick status popover (new)
- **Opens** after the pointer rests on a card for about half a second, or with Space on
  the focused card. It sits next to the card with an arrow. Moving onto it keeps it open;
  leaving, Esc or a drag closes it. Not shown while dragging or in Alignment mode.
- **Content**: model, IP, group dot + name, "Updated 2 s ago"; **Power** (word + how long),
  **Shutter**, **Input** with the signal pill as in Monitoring, **Temperature** (intake,
  exhaust, amber above the alert threshold) and the active alerts. Light source hours are
  left out, and so is a selection summary in the status bar (both repeat Monitoring, owner
  2026-10-15).
- **Actions**: *Show in Monitoring* (switches the view and opens this projector's panel,
  §7i.4) and *Remote Preview*.
- New data: "on for 2 h 14 min" needs the time of the last power change; not stored today.

---

## 8. Order

1. **Foundation** (§1): `DialogTitleBar` icon + all dialogs migrated in one go (the change is
   mechanical: one `icon:` argument each), dialog radius in the theme, `ConfirmDialog` and the
   six confirmations. Visible app-wide, low risk — ship it first. The new tooltip (§7g) goes
   in the same step: one widget, used everywhere.
2. **Groups** (§3): smallest of the three; brings `GroupColorPalette` and `collapseIpRanges`.
3. **Add Projectors + Edit Projector** (§2): reuses `collapseIpRanges`; last-used
   credentials setting; the login card is one widget shared by both dialogs.
4. **Brightness Control** (§5): self-contained, one file; brings the projector in the title
   bar (§1.1).
5. **Color Correction** (§6): one file; reuses `SegmentedTabs` and the debounce from
   Brightness Control.
6. **Geometry Correction** (§7): one file; mode tiles, grouped sliders, corner steppers,
   compact layout. The Keystone / Curved preview can follow separately after the VSS study.
7. **Edge Blending** (§7a): the `edge_blending/` widgets; reuses the Geometry frame (mode
   tiles, canvas card + controls card). The canvas painter keeps its logic and gets the new
   colours, legend and placeholders.
8. **Remote Preview** (§7b): `remote_preview_dialog.dart` and `preview_viewport.dart`;
   restyle only, no new data.
9. **Custom Command** (§7c): one file, small; can ride along with the foundation step.
10. **Keyboard Shortcuts and About** (§7d, §7e): two small files; the shortcut search
    filter goes to `domain/`.
11. **Main toolbar** (§7f): `toolbar.dart`; the missed-run badge colour waits for §4.8.
12. **Control bar** (§7h): `control_bar.dart`; split into one widget per card while at it
    (the file is ~1300 lines).
13. **Projector card** (§7j): `projector_card.dart` and `alert_badge.dart`; state colours,
    the group band and the selection ring first, then the context menu, then the quick
    status popover (it links to the Monitoring panel, so it lands with or after step 14).
14. **Monitoring view** (§7i): table restyle and grouping first (it builds on
    `monitoring_table.dart` and `MONITORING_UI_PLAN.md`), then Cards (compact / extended)
    and the projector panel, then filter / search / export.
15. **Scheduled Tasks** (§4): largest; model change (`targetGroupIds`), missed runs and their
   state file, one dialog instead of two, command picker.

Each step: behaviour change only where this plan says so; `flutter analyze`, `dart format`,
tests below, then a GUI check in both themes (`flutter-windows-gui-check`).

---

## 9. Tests

- **Unit** (`test/unit/`): `collapseIpRanges`; first unused group colour; target chip label
  ("Main stage" / "N groups"); command picker search; `isTaskDue` with the 2-minute grace;
  `missedOccurrences` (daily / weekly / once, gaps over midnight and weekday boundaries, no
  state file); project-file migration `targetGroupId` → `targetGroupIds`.
- **Provider** (`fake_async`): app "closed" over a run → missed record, no command sent;
  a late one-time task is not executed.
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
  the Linearity / Pincushion rows are disabled in Auto, the compact layout below ~880 px;
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
  edits and deletes (with confirm), controls disabled without a selection; Monitoring:
  group rows and *Group by: none*, the signal pill per state, the panel opens over the
  table without changing column widths, Compact / Extended switch, offline rows dimmed;
  projector card: header tint and icon colours per power / shutter state, the red
  outline only when offline, *Login failed* for an `unauthorized` node, the group band
  with the group name and none for an ungrouped card, the selection ring, an alert
  appearing doesn't move the power icon (same `Offset`), the context menu header shows
  model + IP, the quick status popover opens on hover delay and Space and not while
  dragging;
  `DialogTitleBar` with a `projector` shows model + IP, the group pill only for a grouped
  projector, and the status badge.

---

## 10. Open questions

- ~~A scheduled task whose target groups were all deleted~~ — decided 2026-10-13: paused
  (§4.5).
- Icons in §1.1 are proposals; confirm during the GUI check.
- Color Matching defaults (§6.5): the `_values3` / `_values7` initial values are assumed to
  be the factory defaults. Check on a projector before Reset and the Changed dot rely on
  them.
- Geometry preview in Keystone / Curved (§7.4): how VSS draws these modes, to be studied by
  the owner before the painter is finished.
- ~~Edit Projector: card or title bar~~ — decided 2026-10-14: it keeps its projector card
  (§2.6), since it shows the address being edited.
- ~~Missed runs~~ — decided 2026-10-13: never run late, one-time and recurring alike; shown
  in their own Missed list (§4.8).
- ~~Projector card group marker~~ — decided 2026-10-15: band inside the card (§7j.3,
  variant C).
- Quick status popover (§7j.6): the hover delay (about 500 ms) and Space as the key, to
  confirm in the GUI check.
