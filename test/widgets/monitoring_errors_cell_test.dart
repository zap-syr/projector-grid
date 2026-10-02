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

  Future<void> pump(WidgetTester tester, String errors) => tester.pumpWidget(
    ProviderScope(
      overrides: [alertsProvider.overrideWith(_NoAlerts.new)],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
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

  testWidgets('codes only, critical first, +N past four', (tester) async {
    await pump(tester, 'U201 F305 H001 F011 F306');
    expect(find.text('F305'), findsOneWidget);
    expect(find.text('F011'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Fan error'), findsNothing);
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
