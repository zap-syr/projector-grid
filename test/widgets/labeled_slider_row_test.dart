import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/labeled_slider_row.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, LabeledSliderRow row) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(child: SizedBox(width: 300, child: row)),
          ),
        ),
      );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('a row is 36 px high, label or not', (tester) async {
    await pumpRow(
      tester,
      LabeledSliderRow(
        label: 'R',
        value: 0,
        min: 0,
        max: 255,
        onChanged: (_) {},
        onChangeEnd: (_) {},
      ),
    );
    expect(tester.getSize(find.byType(LabeledSliderRow)).height, 36);

    await pumpRow(
      tester,
      LabeledSliderRow(
        value: 0,
        min: 0,
        max: 255,
        onChanged: (_) {},
        onChangeEnd: (_) {},
      ),
    );
    expect(tester.getSize(find.byType(LabeledSliderRow)).height, 36);
  });

  testWidgets('a typed value goes to onTyped, only when it differs', (
    tester,
  ) async {
    final typed = <double>[];
    final dragged = <double>[];
    await pumpRow(
      tester,
      LabeledSliderRow(
        value: 10,
        min: 0,
        max: 255,
        onChanged: dragged.add,
        onChangeEnd: dragged.add,
        onTyped: typed.add,
      ),
    );
    await type(tester, '10');
    await type(tester, '42');
    expect(typed, [42]);
    expect(dragged, isEmpty);
  });

  testWidgets('without onTyped a typed value goes to onChanged and '
      'onChangeEnd', (tester) async {
    final changed = <double>[];
    final ended = <double>[];
    await pumpRow(
      tester,
      LabeledSliderRow(
        value: 10,
        min: 0,
        max: 255,
        onChanged: changed.add,
        onChangeEnd: ended.add,
      ),
    );
    await type(tester, '42');
    expect(changed, [42]);
    expect(ended, [42]);
  });
}
