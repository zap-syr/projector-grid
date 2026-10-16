---
name: projector-grid-visual-rules
description: >
  The visual rules of Projector Grid's UI (owner-approved 2026-10-16): the type scale
  (AppText roles), the UI font, text colours, field placeholders and hint text, icon
  colours and sizes, icon tiles, buttons, card surfaces and corner radii, and layout
  stability (fixed size and order of elements across tabs, modes and dialogs). Use this skill
  whenever you add or change any widget, dialog, card, field, button, icon or text in
  lib/ of this project, redesign a dialog from plan/DIALOG_REDESIGN_PLAN.md, or draw a
  mockup of the app. It overrides the generic flutter-desktop-ui guidance where they
  differ.
---

# Projector Grid visual rules

One set of rules for every screen, so dialogs redesigned by different agents look like
one app. When something here and the redesign plan disagree, these rules win: they came
later and the owner approved them across all dialogs. When a case isn't covered, ask the
owner instead of inventing a new size, colour or variant.

The code that implements the rules:
- `lib/core/theme/app_theme.dart`: `AppTheme.fontFamily`, `AppTheme.tracking`,
  `AppTheme.mono`, `AppText` (the roles), `AppStatusColors`.
- `lib/features/workspace/presentation/widgets/common/dialog_parts.dart`:
  `DialogSurfaces`, `DialogCard`, `DialogIconTile`, `LabeledField`, `FieldHelp`,
  `dialogFieldDecoration`, `plainFieldStyle`, `monoFieldStyle`, `DialogFooter`.
- `dialog_title_bar.dart`: `DialogTitleBar`.

## 1. Fonts

- **UI font: Inter**, bundled under `assets/fonts/inter/` (Regular, Medium, SemiBold,
  Bold), set once as `ThemeData.fontFamily` from `AppTheme.fontFamily`. Its OFL licence
  is registered in `main.dart` (`LicenseRegistry`). Plus Jakarta Sans stays bundled
  (`assets/fonts/plus_jakarta_sans/`) as the alternative the owner may switch back to;
  don't remove it.
- **Mono font: IBM Plex Mono**, through `AppTheme.mono(...)`, `AppText.mono` or
  `AppText.monoSmall`, for IPs, ports, NTCONTROL commands, OSC addresses and key caps.
- **A widget never names a font** (`fontFamily:`) and never uses `'monospace'`.
- **Tracking.** The UI font gets +1 % letter spacing up to 14 px and none above
  (`AppTheme.tracking(size)`). It is applied to the text theme and to every `AppText`
  role. Mono text has letter spacing 0.
- **Changing the font later** means new files under `assets/fonts/`, the pubspec
  `fonts:` entry, the licence in `main.dart` and `AppTheme.fontFamily` (switching between
  the two bundled fonts is that one name). Then check the
  places with a fixed width for text: footer buttons, the Keyboard Shortcuts key column
  (176 px) and mode tile labels.

## 2. Type scale: `AppText` roles

`final t = AppText.of(context);` then `style: t.description`. **No `fontSize:` in widgets**:
take a role, and when you need a variant use `copyWith` on a role for weight, colour,
height or decoration, never for size.

| Role | Size | Weight | Colour | Use |
|---|---|---|---|---|
| `hero` | 22 | 700 | primary | the app name in About only |
| `dialogTitle` | 16 | 600 | primary | the title bar title, a confirm dialog's title |
| `cardTitle` | 15 | 600 | primary | the title of a card or section, a card's headline (`12 addresses`) |
| `label` | 12.5 | 600 | secondary | the label above a field, a small header (`What changes`, `OSC addresses`), table column headers |
| `body` | 14 | 400 | primary | body text, list rows, field values, tabs, mode tiles; row names take `w600` or `w500` |
| `description` | 12.5 | 400 | secondary | a card subtitle, a help line under a field, a footer message, a summary line, an empty state's second line |
| `caption` | 11.5 | 500 | tertiary | scale labels, counters (`9 / 24`, `4 of 6`), legends, pill text |
| `value` | 26 | 600 | primary, tabular | the large value of a card (`85%`); its unit is `cardTitle` w400 secondary |
| `mono` | 13.5 Plex Mono | 400 | primary | IPs, ports, commands, OSC addresses in fields and rows |
| `monoSmall` | 12 Plex Mono | 400 | secondary | model + IP under a title, IP and OSC chips, a dropdown's detail |

Pills: `caption` at `w600` in the pill's colour. Key caps (`key_caps.dart`) keep their own
small mono size: they are a fixed-height component.

## 3. Text colours

Four, all in `AppText`:
- `primary` = `onSurface`: titles, values, body.
- `secondary` = `onSurfaceVariant`: labels, descriptions, help lines, inline icons.
- `tertiary` = `outline`: captions, scale labels, placeholders, quiet text.
- `disabled` = `onSurface` at 38 %: **only** for disabled controls and rows (a Discover
  row already in the project).

No other alpha recipes for text (no `onSurfaceVariant` at 60 % or 75 %). Status colours
(`error`, `AppStatusColors.success`, `warning`) only for status.

## 4. Fields and placeholders

- **Every text field uses `dialogFieldDecoration(context, …)`**: 40 px high, radius 10,
  filled with `DialogSurfaces.field`, label above it (`LabeledField`) and an optional
  `FieldHelp` under it. A search field passes `prefixIcon: Icons.search`. Dropdowns use
  `AppDropdown`, the same height.
- **One exception: the value field next to a slider** (the stepper input with ↑ ↓ that
  shows and types a slider's value: R / G / B, white balance, Geometry degrees and corner
  H / V) is **32 px** high, so a row of sliders stays compact (owner, 2026-10-16, board
  *Value field next to a slider*, option 2). Same fill, border and Plex Mono value as the
  other fields; radius 8. A field that stands on its own (Throw ratio) stays 40.
- **Field text**: words (names, search, login) use `plainFieldStyle` (UI font, 14); IPs,
  ports, commands and OSC addresses use `monoFieldStyle` (Plex Mono, 13.5).
- **The placeholder takes the font of the value it stands for**, so it never changes font
  when typing starts. `dialogFieldDecoration` gives it only the colour (`tertiary`); the
  font and size come from the field's `style`. Never set a `hintStyle` of your own.

### Hint text (placeholder wording)

1. **One thing, not two.** A placeholder either names the action (`Search shortcuts`) or
   shows the format (`192.168.0.10`), never both.
2. **No `e.g.`, no list of examples, no ellipsis, no full stop.**
3. **Two or three words at most**, no articles, sentence case.
4. **A format is shown by a sample value**, not words: `192.168.0.10`, `OSH:1`,
   `DD/MM/YYYY`. It is in Plex Mono, as the value would be.
5. **Don't repeat the label.** A field with a label above it has no placeholder unless it
   adds the format. A sample in a word field (`Dynamic contrast`) reads as a filled-in
   value, so it isn't used either.
6. **A search field without a label** names what it searches: `Search shortcuts`,
   `Search log`.
7. **A state placeholder** that describes the current value is fine: `Not set`,
   `Unchanged`.

The ellipsis in menu items (`Settings…`, `Save As…`) is the standard "opens a dialog" mark
and is not affected by these rules.

## 5. Icons

### Colour: three levels
1. **Dialog mark**: `primaryContainer` fill, `onPrimaryContainer` icon. Only in the title
   bar (`DialogTitleBar`), one per dialog. A confirm dialog's round icon is its mark.
2. **Card or section**: `DialogIconTile`: a neutral tile (`DialogSurfaces.soft`) with a
   **primary** icon. Every card and section tile, link rows included.
3. **Locked or unavailable**: `DialogIconTile(muted: true)`: the same grey tile, icon in
   `outline`.

Inline icons beside text (a header icon, a help icon, a field's suffix) are `secondary`.
**Blue fills and blue text only mean state**: a selected tab or mode tile, a switch that is
on, a link, a filled button. A pill or tile is never blue just to stand out. One exception (owner,
2026-10-16): the About version pill is `primaryContainer` with `onPrimaryContainer`
text, part of the app's identity in that header. Status colours only for status.

A tile doesn't fill to show that something is on (Pre-show on, for one): the switch or
the selected control shows the state, the tile stays `DialogIconTile`. A lock pill (a
setting fixed by another one: Brightness' *User modes*, Color Temperature fixed by Color
Matching) is a neutral pill on `DialogSurfaces.soft` with a lock icon, never amber
(owner, 2026-10-16).

### Sizes
- **14**: inline with text (pill icons, `Last used`, the mouse pill).
- **16**: small tiles (30 px) and rows (help lines, link chevrons, confirm change rows).
- **18**: buttons, card tiles (34 px), the title bar tile, field prefix icons.
- **20**: the close button and mode tiles.

### Tiles
- Sizes: **30** for a section or row tile, **34** for a card tile, 40 for the Edit
  Projector info card.
- **Radius is 30 % of the size**: 9 for 30, about 10 for 34. `DialogIconTile` does it;
  the title bar tile (30) uses 9.

## 6. Buttons

- **Filled**: the main action. **Only one filled button is enabled at a time** in a
  dialog. When a second one appears (Manage Groups' form with *Create group*), the first
  (*New group*) is disabled while it is open.
- **Tonal**: a secondary action in place (`Scan again` in Discover).
- **Text**: Cancel and dismiss.
- **Outlined**: the command buttons of the control bar (*On* / *Standby*, *Open* /
  *Close*, *Set*, *Show*, *Run*): many of them side by side, so they don't fill (owner,
  2026-10-16). Not used in dialogs.
- **Destructive**: filled in `error`, only in confirm dialogs (`ConfirmDialog`). A delete
  inside a dialog is an error icon or text button that opens that confirm.
- **Dashed**: adds a row inside a list (New task).
- **Disabled keeps its width**, and a label that changes keeps the width of the longest
  label (`DialogFooter.widestActionLabel`).
- Icons in buttons are 18.

## 6a. Sliders

Two styles (owner, 2026-10-16), each always built from `AppSliderTrackShape`
(`common/slider_tracks.dart`):
- **Large**, for a card with one main value (Brightness' Light output and Max light
  output, Color Temperature's Kelvin): track 6 px, thumb radius 9, overlay radius 16,
  − / + `StepButton`s on both sides, a scale row under the track.
- **Thin**, for dense lists of sliders (Geometry, R / G / B, white balance, Edge
  Blending): track 2 px, thumb radius 6, as `LabeledSliderRow`, with the 32 px value
  field (§4) on the right.
- A symmetric range fills from a centre zero tick (`zeroFraction`), a cap hatches the
  track past it (`limitFraction`).
- Anything placed under or over a thumb position (a tick, a scale label such as
  `Max 80%`) takes its x from `AppSliderTrackShape.positionOf`, never
  `width * fraction`: a discrete slider keeps the thumb half the track height in from
  each end.

## 7. Surfaces, cards and corners

- Dialog body: `DialogSurfaces.body`. **Every card in a dialog is `DialogCard`**, so its
  fill is `DialogSurfaces.card` (raised above the body in both themes). Don't use
  `surfaceContainer` or other container tones for a card.
- Inside a card: `DialogSurfaces.editor` for an open editor, `DialogSurfaces.soft` for
  tiles and neutral pills, `DialogSurfaces.field` for fields.
- Radii: dialog 20 (theme), card 14, field and dropdown 10, tiles 30 % of their size,
  pills fully rounded.
- Card border `outlineVariant`; highlighted (selected or open form) 2 px `primary`;
  warning a `warning` border.
- Dividers inside a card: `outlineVariant` at 60 %.

## 8. Layout stability and consistency

The owner checks this on every redesign. Nothing may jump when the user switches a tab, a
mode or a state.

### Across tabs and modes in one dialog
- **The dialog doesn't change size between tabs.** Give it one size for all tabs, by
  `SizedBox.expand` inside the `ConstrainedBox` cap, or by the height of the tallest tab.
  Never size it to the current tab's content.
- **An element that repeats on several tabs keeps its size, position and order on every
  tab.** Examples are the login card in Add Projectors, the footer and its button, the
  field row and the list or preview card. It is the same widget with the same
  parameters. When one tab needs a variant, such as Discover's one-row login, the variant
  keeps the same height and the same place: its text and its top edge don't move on
  switching.
- **The same slot is at the same height on every tab.** A list or preview card that
  fills the rest of the body ends the same distance above the footer on every tab
  (`DialogScrollBody.fill`).
- **The order is the same on every tab.** Tabs or mode tiles first, then inputs, then the
  shared cards (such as the login card), then the result, list or preview. A tab doesn't
  reorder shared pieces.
- **Content that is missing keeps its place.** Use a placeholder of the same size
  (`RangePreviewPlaceholder`, a skeleton while loading), `Visibility(maintainSize: true)`
  for a button that comes and goes (the ✕ in a field), or an invisible widest label for
  text that changes (`DialogFooter.widestActionLabel`, the `100.0%` behind a value). A
  locked card stays in place, dimmed, instead of disappearing (Brightness' Max light
  output).
- **States don't move things.** Loading, empty, error and filled states of a card have
  the same height. A help line under a field is always there (an empty `FieldHelp('')`
  holds the line), and an error replaces it instead of being added under it.

### Across dialogs
- **One frame, one order:** title bar (`DialogTitleBar`), then tabs or mode tiles, then
  the body cards, then the footer (`DialogFooter`). Per-projector dialogs put the
  projector in the title bar, never in a body card.
- **The same element looks the same everywhere.** Use the shared component, not a copy:
  `DialogCard`, `DialogIconTile`, `LabeledField` + `dialogFieldDecoration`,
  `SegmentedTabs`, `ModeTileRow`, `StatusPill` / `ConnectionStatusBadge`, `GroupPill`,
  `IpChips`, `StepButton`, `DialogFooter`, `SentRightAwayNote`. When a shared piece is
  missing something, extend it (a parameter) instead of hand-rolling a near copy in the
  dialog.
- **Same sizes for the same job:** every field and dropdown is 40 px high. Mode tiles of
  one dialog share one height. Footer buttons have the same height, and the primary one
  is on the right.
- **Spacing depends on the task**, it is not a fixed rule: a dense list of small cards
  wants tighter gaps than a form. Within one dialog keep it consistent. For reference,
  the redesigned dialogs use: card padding 16 and 16 between cards (Brightness, Add
  Projectors), 10 between the small section cards of Keyboard Shortcuts, 6 between a
  label and its field, 24 around the body.
- **Same wording for the same thing:** the same button label (`Cancel`, `Save`,
  `Add …`), the same status names (`Online`, `Offline`, `Wrong login`, `No login`) and the
  same footer note (`Changes are sent to the projector right away`).

### How to check
- Switch every tab and mode, both ways, and check that the title bar, the tabs, the shared
  cards and the footer button don't move by a pixel. Check loading, empty and error
  states the same way.
- Where it matters, add a widget test that reads `tester.getTopLeft(...)` / `getSize(...)`
  of the shared element on each tab and expects them equal.
- Check at the maximum size and at the 800×600 window (§1.4 of the redesign plan).

## 9. Text

- UI text is English and separates with commas, colons and parentheses, never `·` or
  dashes; ranges read `0 to 255`.
- Projectors are named by IP or model + IP (`RZ34K (192.168.0.41)`), never the model
  alone.
- NTCONTROL command codes are not shown to the user.

## 10. Checklist before you finish

- `grep` your files for `fontSize:`, `fontFamily:`, `withValues(alpha:` on text colours,
  `FilledButton.tonal` and `hintText:`, and check each against the rules above.
- Two filled buttons enabled at once? A blue tile or pill that isn't state?
- The layout stays put (§8): no size or position change between tabs, modes, states or
  labels; repeated elements are the shared component, in the same order everywhere.
- A dialog's size from the plan is a cap (`ConstrainedBox(maxHeight:)` around a
  `mainAxisSize.min` column), so a role that grows the text doesn't cut the content off.
  A scrolling body is `DialogScrollBody`; a bare `Scrollbar` without a `ScrollController`
  throws on desktop as soon as the mouse moves over it.
- `dart analyze` and `dart format` clean. GUI check in both themes before any commit,
  and only commit when the owner says so.
