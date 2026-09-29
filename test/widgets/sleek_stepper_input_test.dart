import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/sleek_stepper_input.dart';

void main() {
  late List<String> committed;

  Future<void> pump(
    WidgetTester tester, {
    String initial = '0',
    double min = -10,
    double max = 10,
    double step = 1,
  }) async {
    committed = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SleekStepperInput(
              initialValue: initial,
              min: min,
              max: max,
              step: step,
              onValueChanged: committed.add,
            ),
          ),
        ),
      ),
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('typing + Enter commits the value', (tester) async {
    await pump(tester);
    await typeAndSubmit(tester, '7');
    expect(committed.last, '7');
    expect(fieldText(tester), '7');
  });

  testWidgets('a leading + is accepted', (tester) async {
    await pump(tester);
    await typeAndSubmit(tester, '+3');
    expect(committed.last, '3');
  });

  testWidgets('clamps to max and min', (tester) async {
    await pump(tester);
    await typeAndSubmit(tester, '99');
    expect(committed.last, '10');
    await typeAndSubmit(tester, '-99');
    expect(committed.last, '-10');
  });

  testWidgets('snaps to the step', (tester) async {
    await pump(tester, step: 0.5, initial: '1');
    await typeAndSubmit(tester, '1.3');
    expect(committed.last, '1.5');
  });

  testWidgets('invalid text reverts to the initial value', (tester) async {
    await pump(tester, initial: '4');
    await typeAndSubmit(tester, 'abc');
    expect(committed.last, '4');
    expect(fieldText(tester), '4');
  });

  testWidgets('focus loss commits too', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '5');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    expect(committed.last, '5');
  });

  testWidgets('up/down buttons step and stop at the bounds', (tester) async {
    await pump(tester, initial: '9', max: 10);
    await tester.tap(find.byIcon(Icons.arrow_drop_up));
    await tester.pump();
    expect(committed.last, '10');
    await tester.tap(find.byIcon(Icons.arrow_drop_up));
    await tester.pump();
    expect(committed.last, '10');
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();
    expect(committed.last, '9');
  });

  testWidgets('holding a step button repeats', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_drop_up)),
    );
    await tester.pump(const Duration(milliseconds: 400 + 80 * 3 + 10));
    await gesture.up();
    await tester.pump();
    expect(committed.last, '4');
  });

  testWidgets('a new initialValue from the parent syncs when unfocused', (
    tester,
  ) async {
    await pump(tester, initial: '1');
    await pump(tester, initial: '6');
    expect(fieldText(tester), '6');
  });
}
