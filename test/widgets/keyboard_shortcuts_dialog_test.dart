import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
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
