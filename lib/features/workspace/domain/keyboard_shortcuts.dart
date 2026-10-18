/// The shortcut list shown in the Keyboard Shortcuts dialog and the search
/// over it. Pure data and logic, so the search can be unit-tested.
library;

/// One thing the user presses: a key (`Ctrl`, `G`) or a mouse action
/// (`Click`, `Middle drag`), which the dialog draws differently.
class ShortcutInput {
  const ShortcutInput.key(this.label) : mouse = false;
  const ShortcutInput.mouse(this.label) : mouse = true;

  /// Generic label; the dialog maps `Ctrl` / `Shift` to `⌘` / `⇧` on macOS.
  final String label;
  final bool mouse;
}

class ShortcutEntry {
  const ShortcutEntry(this.inputs, this.description);

  final List<ShortcutInput> inputs;
  final String description;
}

enum ShortcutSectionId {
  project,
  canvasNavigation,
  edit,
  view,
  selection,
  projectorControl,
  alignment,
  lensShift,
  edgeBlending,
}

class ShortcutSection {
  const ShortcutSection(this.id, this.title, this.entries, {this.note});

  final ShortcutSectionId id;
  final String title;
  final List<ShortcutEntry> entries;

  /// Muted text on the right of the section header.
  final String? note;
}

ShortcutInput _k(String label) => ShortcutInput.key(label);
ShortcutInput _m(String label) => ShortcutInput.mouse(label);

/// Every shortcut the app binds. [macOS] picks Redo's binding: macOS uses
/// the platform's Cmd+Shift+Z (native Edit menu), Windows Ctrl+Y.
List<ShortcutSection> shortcutSections({required bool macOS}) {
  final ctrl = _k('Ctrl');
  final shift = _k('Shift');
  final arrows = [_k('↑'), _k('↓'), _k('←'), _k('→')];
  return [
    ShortcutSection(ShortcutSectionId.project, 'Project', [
      ShortcutEntry([ctrl, _k('N')], 'New project'),
      ShortcutEntry([ctrl, _k('O')], 'Open project'),
      ShortcutEntry([ctrl, _k('S')], 'Save project'),
      ShortcutEntry([ctrl, shift, _k('S')], 'Save project as'),
      ShortcutEntry([_k('F5')], 'Refresh all projectors'),
      ShortcutEntry([ctrl, _k('Q')], 'Exit the app'),
    ]),
    ShortcutSection(ShortcutSectionId.canvasNavigation, 'Canvas navigation', [
      ShortcutEntry([_m('Middle drag')], 'Pan the canvas'),
      ShortcutEntry([ctrl, _m('Scroll')], 'Zoom in or out (50 to 200%)'),
      ShortcutEntry([_k('F')], 'Focus the selected projectors, or all if none'),
      ShortcutEntry([shift, _k('F')], 'Focus all projectors'),
      ShortcutEntry([_m('Click empty space')], 'Deselect all'),
    ]),
    ShortcutSection(ShortcutSectionId.edit, 'Edit', [
      ShortcutEntry([ctrl, _k('Z')], 'Undo'),
      ShortcutEntry(macOS ? [ctrl, shift, _k('Z')] : [ctrl, _k('Y')], 'Redo'),
    ]),
    ShortcutSection(ShortcutSectionId.view, 'View', [
      ShortcutEntry([ctrl, _k('1')], 'Switch to Controls view'),
      ShortcutEntry([ctrl, _k('2')], 'Switch to Monitoring view'),
      ShortcutEntry([ctrl, _k('F')], 'Search projectors in Monitoring'),
      ShortcutEntry([_k('Esc')], 'Close the projector panel in Monitoring'),
    ]),
    ShortcutSection(ShortcutSectionId.selection, 'Selection', [
      ShortcutEntry([_m('Click')], 'Select a projector, deselect the others'),
      ShortcutEntry([ctrl, _m('Click')], 'Add or remove a projector'),
      ShortcutEntry([ctrl, _m('Drag')], 'Box select'),
      ShortcutEntry([ctrl, _k('A')], 'Select all projectors'),
      ShortcutEntry([ctrl, _k('D')], 'Deselect all projectors'),
      ShortcutEntry([
        ctrl,
        _k('G'),
      ], 'Select the whole group of the selected projector'),
      ShortcutEntry([
        _k('Space'),
      ], 'Quick status of the selected projector, open or close'),
    ]),
    ShortcutSection(ShortcutSectionId.projectorControl, 'Projector control', [
      ShortcutEntry([_k('I')], 'Open the shutter'),
      ShortcutEntry([_k('O')], 'Close the shutter'),
      ShortcutEntry([_k('Delete')], 'Delete from the project'),
    ], note: 'selected projectors'),
    ShortcutSection(ShortcutSectionId.alignment, 'Alignment', [
      ShortcutEntry([ctrl, _k('L')], 'Enter or exit Alignment mode'),
      ShortcutEntry([_k('<'), _k('>')], 'Previous or next projector'),
      ShortcutEntry([_k('N')], 'Neighbours on or off'),
      ShortcutEntry([_k('A')], 'Show All on or off'),
      ShortcutEntry([ctrl, _m('Click')], 'Add or remove a neighbour'),
      ShortcutEntry([_k('Esc')], 'Exit Alignment mode'),
    ]),
    ShortcutSection(ShortcutSectionId.lensShift, 'Lens shift', [
      ShortcutEntry(arrows, 'Lens shift, normal speed'),
      ShortcutEntry([shift, ...arrows], 'Lens shift, fast speed'),
      ShortcutEntry([ctrl, ...arrows], 'Lens shift, slow speed'),
    ]),
    // The canvas card's note keeps to one line, so the details live here.
    ShortcutSection(ShortcutSectionId.edgeBlending, 'Edge Blending', [
      ShortcutEntry(arrows, 'Move the selected handle 1 step'),
      ShortcutEntry([shift, ...arrows], 'Move the selected handle 10 steps'),
      ShortcutEntry([_m('Double click')], 'Reset an edge'),
      ShortcutEntry([_k('Esc')], 'Clear the selection'),
    ], note: 'on the canvas'),
  ];
}

/// An entry that matched, with the parts of its description to highlight
/// as `(start, end)` offsets.
class ShortcutHit {
  const ShortcutHit(this.entry, this.highlights);

  final ShortcutEntry entry;
  final List<(int, int)> highlights;
}

class ShortcutSectionHits {
  const ShortcutSectionHits(this.section, this.hits);

  final ShortcutSection section;
  final List<ShortcutHit> hits;
}

/// Words people type for a key, mapped to the generic label's word. The
/// macOS symbols are here because that's what the dialog shows there.
const _keyAliases = {
  'cmd': 'ctrl',
  'command': 'ctrl',
  'control': 'ctrl',
  '⌘': 'ctrl',
  '⇧': 'shift',
  'escape': 'esc',
  'del': 'delete',
  'up': '↑',
  'down': '↓',
  'left': '←',
  'right': '→',
  'arrow': '↑',
  'arrows': '↑',
};

/// Filters [sections] by [query]. An entry matches when its description
/// contains the query, or when every word of the query names one of its
/// keys or mouse actions (`ctrl g`, `ctrl+g`, `esc`, `middle drag`).
/// Sections without a match are left out; an empty query keeps everything.
List<ShortcutSectionHits> filterShortcuts(
  List<ShortcutSection> sections,
  String query,
) {
  final q = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final terms = q
      .split(RegExp(r'[\s+]+'))
      .where((t) => t.isNotEmpty)
      .map((t) => _keyAliases[t] ?? t)
      .toList();

  final result = <ShortcutSectionHits>[];
  for (final section in sections) {
    final hits = <ShortcutHit>[];
    for (final entry in section.entries) {
      if (q.isEmpty) {
        hits.add(ShortcutHit(entry, const []));
        continue;
      }
      final highlights = _occurrences(entry.description.toLowerCase(), q);
      if (highlights.isNotEmpty || _keysMatch(entry, terms)) {
        hits.add(ShortcutHit(entry, highlights));
      }
    }
    if (hits.isNotEmpty) result.add(ShortcutSectionHits(section, hits));
  }
  return result;
}

int shortcutCount(List<ShortcutSection> sections) =>
    sections.fold(0, (n, s) => n + s.entries.length);

bool _keysMatch(ShortcutEntry entry, List<String> terms) {
  if (terms.isEmpty) return false;
  final words = {
    for (final input in entry.inputs) ...input.label.toLowerCase().split(' '),
  };
  return terms.every(words.contains);
}

List<(int, int)> _occurrences(String text, String needle) {
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = text.indexOf(needle, from);
    if (i < 0) return out;
    out.add((i, i + needle.length));
    from = i + needle.length;
  }
}
