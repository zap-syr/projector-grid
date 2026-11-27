import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/settings_rows.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/settings_value_field.dart';

void main() {
  final theme = AppTheme.darkTheme;

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('settings row note', () {
    testWidgets('takes the caption role', (tester) async {
      await pump(
        tester,
        const SettingsRow(label: 'Label', hint: 'A note', control: SizedBox()),
      );
      final style = tester.widget<Text>(find.text('A note')).style!;
      expect(style.fontSize, 11.5);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, theme.colorScheme.outline);
      expect(style.height, 1.3);
    });

    testWidgets('is the error colour when the row has an error', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsRow(label: 'Label', error: 'Bad', control: SizedBox()),
      );
      final style = tester.widget<Text>(find.text('Bad')).style!;
      expect(style.fontSize, 11.5);
      expect(style.color, theme.colorScheme.error);
    });
  });

  group('settings value field placeholder', () {
    TextStyle hintOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintStyle!;

    testWidgets('is upright, tertiary and the size of the value', (
      tester,
    ) async {
      await pump(
        tester,
        SettingsValueField(
          controller: TextEditingController(),
          hintText: 'Not set',
          width: 120,
        ),
      );
      final hint = hintOf(tester);
      expect(hint.fontStyle, isNot(FontStyle.italic));
      expect(hint.fontSize, 14);
      expect(hint.color, theme.colorScheme.outline);
    });

    testWidgets('does not take the PIN dots letter spacing', (tester) async {
      await pump(
        tester,
        SettingsValueField(
          controller: TextEditingController(),
          hintText: 'Not set',
          obscureText: true,
          width: 120,
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.letterSpacing, 2.5);
      expect(field.decoration!.hintStyle!.letterSpacing, isNot(2.5));
      expect(field.decoration!.hintStyle!.fontSize, 14);
    });
  });
}
