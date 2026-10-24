import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_workspace.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  late ProviderContainer container;

  Future<void> pumpCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fake = FakeProtocolService()
      ..pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: ProjectorWorkspace()),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(ProjectorWorkspace)),
    );
    container.read(workspaceProvider.notifier).setNodes([
      node('1', x: 40, y: 40),
    ]);
    await tester.pumpAndSettle();
  }

  Offset canvas(WidgetTester tester, Offset local) =>
      tester.getTopLeft(find.byType(ProjectorWorkspace)) + local;

  testWidgets('a jittery two-finger scroll draws no selection marquee', (
    tester,
  ) async {
    await pumpCanvas(tester);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(canvas(tester, const Offset(250, 200)));
    // Fingers wobbling up and down: lots of travel, little net movement —
    // the case where a pan recognizer would win over the scroll views.
    for (var i = 0; i < 4; i++) {
      await gesture.panZoomUpdate(
        canvas(tester, const Offset(250, 200)),
        pan: Offset(0, i.isEven ? -10 : 0),
      );
      await tester.pump();
    }
    await gesture.panZoomUpdate(
      canvas(tester, const Offset(250, 200)),
      pan: const Offset(-150, -120),
    );
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();

    expect(container.read(selectionProvider), isEmpty);
  });

  testWidgets('a two-finger scroll over a card does not move it', (
    tester,
  ) async {
    await pumpCanvas(tester);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(canvas(tester, const Offset(100, 90)));
    for (var i = 1; i <= 5; i++) {
      await gesture.panZoomUpdate(
        canvas(tester, const Offset(100, 90)),
        pan: Offset(i * 15.0, i * 15.0),
      );
      await tester.pump();
    }
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();

    final card = container.read(workspaceProvider).single;
    expect((card.x, card.y), (40.0, 40.0));
  });

  testWidgets('pinch zooms the canvas', (tester) async {
    await pumpCanvas(tester);
    expect(find.text('100%'), findsOneWidget);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(canvas(tester, const Offset(400, 300)));
    await gesture.panZoomUpdate(
      canvas(tester, const Offset(400, 300)),
      scale: 1.5,
    );
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.text('150%'), findsOneWidget);

    await gesture.panZoomStart(canvas(tester, const Offset(400, 300)));
    await gesture.panZoomUpdate(
      canvas(tester, const Offset(400, 300)),
      scale: 0.5,
    );
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget);
  });
}
