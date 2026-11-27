import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/preferences_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  // The app's minimum window size — the dialog must fit it without overflow.
  Future<void> pumpDialog(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: const Scaffold(body: PreferencesDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('every section lays out at the minimum window size', (
    tester,
  ) async {
    await pumpDialog(tester);
    expect(find.text('Update interval'), findsOneWidget);

    await openSection(tester, 'Alerts');
    expect(find.text('Exhaust temperature'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OSC message'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('OSC message'), findsOneWidget);

    await openSection(tester, 'OSC');
    expect(find.text('Network interface'), findsOneWidget);

    await openSection(tester, 'Web Access');
    expect(find.text('Viewer PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected PIN jumps to Web Access and names the field', (
    tester,
  ) async {
    await pumpDialog(tester);
    await openSection(tester, 'Web Access');
    // The service card's switch comes first on the page.
    await tester.tap(find.byType(Switch).first);
    await openSection(tester, 'General');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Viewer PIN'), findsOneWidget);
    expect(find.text('Viewer PIN: Required'), findsOneWidget);
    expect(find.byType(PreferencesDialog), findsOneWidget);
  });

  testWidgets('a warning threshold at or above critical blocks Save', (
    tester,
  ) async {
    await pumpDialog(tester);
    await openSection(tester, 'Alerts');
    // Intake warning, then intake critical, then the exhaust pair.
    await tester.enterText(find.byType(TextField).at(0), '50');
    await openSection(tester, 'General');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Exhaust temperature'), findsOneWidget);
    expect(
      find.text('Intake temperature: Warning must be below critical'),
      findsOneWidget,
    );
  });

  group('plain HTTP note', () {
    for (final (name, theme, status) in [
      ('light', AppTheme.lightTheme, AppStatusColors.light),
      ('dark', AppTheme.darkTheme, AppStatusColors.dark),
    ]) {
      testWidgets('takes its colours from AppStatusColors ($name)', (
        tester,
      ) async {
        await pumpDialog(tester, theme: theme);
        await openSection(tester, 'Web Access');

        final text = find.textContaining('Plain HTTP');
        final box = tester.widget<Container>(
          find.ancestor(of: text, matching: find.byType(Container)).first,
        );
        expect(
          (box.decoration as BoxDecoration).color,
          status.warningContainer,
        );
        expect(tester.widget<Text>(text).style?.color, status.warning);
        final icon = find.descendant(
          of: find.ancestor(of: text, matching: find.byType(Row)).first,
          matching: find.byIcon(Icons.warning_amber_rounded),
        );
        expect(tester.widget<Icon>(icon).color, status.warning);
      });
    }

    testWidgets('the alert warning icon is the status warning colour', (
      tester,
    ) async {
      await pumpDialog(tester, theme: AppTheme.lightTheme);
      await openSection(tester, 'Alerts');
      final icons = tester.widgetList<Icon>(find.byIcon(Icons.warning));
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, AppStatusColors.light.warning);
      }
    });
  });

  group('value field', () {
    TextField intervalField(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).first);

    testWidgets('focusing selects the whole value', (tester) async {
      await pumpDialog(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      final controller = intervalField(tester).controller!;
      expect(controller.selection.start, 0);
      expect(controller.selection.end, controller.text.length);
    });

    testWidgets('Esc puts the old value back and leaves the field', (
      tester,
    ) async {
      await pumpDialog(tester);
      final before = intervalField(tester).controller!.text;
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '999');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(intervalField(tester).controller!.text, before);
      expect(intervalField(tester).focusNode!.hasFocus, isFalse);
    });
  });
}
