import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/keyboard_shortcuts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/key_caps.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/keyboard_shortcuts_dialog.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: KeyboardShortcutsDialog()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays out in the minimum window and a large one', (tester) async {
    for (final size in const [Size(800, 600), Size(1600, 1000)]) {
      await pumpDialog(tester, size);
      expect(find.text('33 shortcuts'), findsOneWidget);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Selection'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a key combination sits on one line, caps as wide as their key', (
    tester,
  ) async {
    await pumpDialog(tester, const Size(1600, 1000));
    // Ctrl N, "New project". (The test font is far wider than IBM Plex
    // Mono, so a three-key combination may wrap here but not in the app.)
    final row = find.ancestor(
      of: find.text('New project'),
      matching: find.byType(Row),
    );
    Rect cap(String key) => tester.getRect(
      find.descendant(of: row.first, matching: find.text(key)),
    );
    final ctrl = cap('Ctrl');
    final n = cap('N');
    expect(n.center.dy, ctrl.center.dy);
    expect(ctrl.right, lessThan(n.left));
    final sCap = tester.getSize(
      find
          .ancestor(
            of: find.descendant(of: row.first, matching: find.text('N')),
            matching: find.byType(KeyCap),
          )
          .first,
    );
    expect(sCap.width, lessThan(40), reason: 'a one-letter cap stays small');
  });

  testWidgets('the two columns end close together', (tester) async {
    await pumpDialog(tester, const Size(1600, 1000));
    final rects = [
      for (final id in ShortcutSectionId.values)
        tester.getRect(find.byKey(ValueKey(id))),
    ];
    final split = rects.first.left;
    final left = rects.where((r) => r.left == split).toList();
    final right = rects.where((r) => r.left != split).toList();
    expect(left, isNotEmpty);
    expect(right, isNotEmpty);
    double bottom(List<Rect> col) =>
        col.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
    final taller = bottom(left) > bottom(right) ? left : right;
    final lastOfTaller = taller.reduce((a, b) => a.bottom > b.bottom ? a : b);
    // Each card went to the shorter column, so the gap between the bottoms
    // is never more than the last card that tipped it.
    expect(
      (bottom(left) - bottom(right)).abs(),
      lessThanOrEqualTo(lastOfTaller.height),
    );
  });

  testWidgets('search filters by description and key, hiding empty sections', (
    tester,
  ) async {
    await pumpDialog(tester, const Size(800, 600));

    await tester.enterText(find.byType(TextField), 'sel');
    await tester.pump();
    expect(find.text('Selection'), findsOneWidget);
    expect(find.text('Canvas navigation'), findsOneWidget);
    expect(find.text('Project'), findsNothing);
    expect(find.text('Alignment'), findsNothing);
    expect(find.text('5 of 6'), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text('7 of 33'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ctrl g');
    await tester.pump();
    expect(find.text('1 of 33'), findsOneWidget);
    expect(find.text('Selection'), findsOneWidget);
    expect(find.text('Canvas navigation'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('33 shortcuts'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
