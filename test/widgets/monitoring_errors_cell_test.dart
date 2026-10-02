import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/monitoring_errors_cell.dart';

import '../helpers/test_config_dir.dart';

class _NoAlerts extends AlertsNotifier {
  @override
  Map<AlertKey, ActiveAlert> build() => const {};
}

void main() {
  useTempConfigDir();

  Future<void> pump(WidgetTester tester, String errors, {double width = 400}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [alertsProvider.overrideWith(_NoAlerts.new)],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MonitoringErrorsCell(
                    node: ProjectorNode(
                      id: '1',
                      name: 'PRJ-05',
                      ipAddress: '10.0.0.5',
                      x: 0,
                      y: 0,
                      errors: errors,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a wide column shows every code, names stay in the panel', (
    tester,
  ) async {
    await pump(tester, 'U201 F305 H001 F011 F306', width: 600);
    for (final code in ['F305', 'F011', 'F306', 'U201', 'H001']) {
      expect(find.text(code), findsOneWidget, reason: code);
    }
    expect(find.textContaining('+'), findsNothing);
    expect(find.text('Fan error'), findsNothing);
  });

  testWidgets('a narrow column shows whole codes and counts the rest', (
    tester,
  ) async {
    await pump(tester, 'U201 F305 H001 F011 F306', width: 150);
    // Critical first; whatever doesn't fit whole is in +N, none cut.
    expect(find.text('F305'), findsOneWidget);
    expect(find.text('H001'), findsNothing);
    final plus = find.textContaining('+');
    expect(plus, findsOneWidget);
    final shown = [
      'F305',
      'F011',
      'F306',
      'U201',
    ].where((c) => find.text(c).evaluate().isNotEmpty).length;
    expect(tester.widget<Text>(plus).data, '+${5 - shown}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at any width, down to just "+N"', (tester) async {
    for (var width = 10.0; width <= 260; width += 7) {
      await pump(tester, 'U201 F305 H001 F011 F306', width: width);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('hover opens the names', (tester) async {
    await pump(tester, 'F305 X912');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(MonitoringErrorsCell)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fan error'), findsOneWidget);
    expect(find.text('Unknown error'), findsOneWidget);
    // The code tag sits in the cell and again in the panel row.
    expect(find.text('F305'), findsNWidgets(2));
  });
}
