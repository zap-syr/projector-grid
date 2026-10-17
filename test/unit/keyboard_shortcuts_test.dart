import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/keyboard_shortcuts.dart';

void main() {
  final sections = shortcutSections(macOS: false);

  List<String> descriptions(String query) => [
    for (final s in filterShortcuts(sections, query))
      for (final h in s.hits) h.entry.description,
  ];

  test('the list has 34 shortcuts in 8 sections', () {
    expect(sections, hasLength(8));
    expect(shortcutCount(sections), 34);
  });

  test('an empty query keeps every section', () {
    final hits = filterShortcuts(sections, '  ');
    expect(hits, hasLength(8));
    expect(hits.every((s) => s.hits.every((h) => h.highlights.isEmpty)), true);
  });

  test('matches descriptions, case-insensitive, with every occurrence', () {
    expect(descriptions('SHUTTER'), ['Open the shutter', 'Close the shutter']);
    final hit = filterShortcuts(sections, 'sel')
        .expand((s) => s.hits)
        .firstWhere(
          (h) =>
              h.entry.description == 'Select a projector, deselect the others',
        );
    expect(hit.highlights, [(0, 3), (22, 25)]);
  });

  test('matches keys word by word', () {
    expect(descriptions('ctrl g'), [
      'Select the whole group of the selected projector',
    ]);
    expect(descriptions('Ctrl+G'), [
      'Select the whole group of the selected projector',
    ]);
    expect(descriptions('esc'), ['Exit Alignment mode']);
    expect(descriptions('middle drag'), ['Pan the canvas']);
    expect(descriptions('cmd z'), ['Undo']);
  });

  test('sections without a match are left out', () {
    final hits = filterShortcuts(sections, 'zoom');
    expect(hits.map((s) => s.section.id), [ShortcutSectionId.canvasNavigation]);
    expect(filterShortcuts(sections, 'nothing like this'), isEmpty);
  });

  test('Redo follows the platform', () {
    List<String> redo(bool macOS) =>
        shortcutSections(macOS: macOS)
            .expand((s) => s.entries)
            .firstWhere((e) => e.description == 'Redo')
            .inputs
            .map((i) => i.label)
            .toList();
    expect(redo(false), ['Ctrl', 'Y']);
    expect(redo(true), ['Ctrl', 'Shift', 'Z']);
  });
}
