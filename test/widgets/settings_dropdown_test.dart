import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/settings_dropdown.dart';

void main() {
  const entries = [
    SettingsDropdownEntry(
      value: '',
      label: 'Any',
      detail: '0.0.0.0',
      dividerAfter: true,
    ),
    SettingsDropdownEntry(value: '10.0.0.5', label: '10.0.0.5', detail: 'Eth'),
  ];

  Future<List<String>> pump(WidgetTester tester, {String value = ''}) async {
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SettingsDropdown<String>(
              value: value,
              entries: entries,
              onSelected: picked.add,
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('shows the current entry and picks another from the menu', (
    tester,
  ) async {
    final picked = await pump(tester);
    expect(find.text('Any   0.0.0.0', findRichText: true), findsOneWidget);

    await tester.tap(find.byType(SettingsDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('10.0.0.5'));
    await tester.pumpAndSettle();
    expect(picked, ['10.0.0.5']);
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('Esc closes the menu', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(SettingsDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('a value no entry has is shown as-is', (tester) async {
    await pump(tester, value: '192.168.1.9');
    expect(find.text('192.168.1.9', findRichText: true), findsOneWidget);
  });
}
