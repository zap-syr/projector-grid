import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_workspace.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

/// Alignment switched on and off directly, without the entry handshake.
class _FakeAlignment extends AlignmentNotifier {
  void setActive(bool active) => state = state.copyWith(active: active);
}

const _popover = ValueKey('quick-status');

void main() {
  useTempConfigDir();

  late FakeProtocolService fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeProtocolService()
      ..pollResults['10.0.0.1'] = (ProbeResult.online, telemetry())
      ..pollResults['10.0.0.2'] = (ProbeResult.online, telemetry());
  });

  Future<void> pumpCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(fake),
          alignmentProvider.overrideWith(_FakeAlignment.new),
        ],
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
      node('2', x: 300, y: 40),
    ]);
    await tester.pumpAndSettle();
  }

  void select(Set<String> ids) =>
      container.read(selectionProvider.notifier).set(ids);

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Finder inPopover(String text) =>
      find.descendant(of: find.byKey(_popover), matching: find.text(text));

  testWidgets('Space opens it for the one selected card, Space closes it', (
    tester,
  ) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsOneWidget);
    expect(inPopover('10.0.0.1'), findsOneWidget);
    expect(inPopover('Power'), findsOneWidget);
    expect(inPopover('Remote Preview'), findsOneWidget);
    expect(inPopover('Show in Monitoring'), findsNothing);

    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('it sits beside the card, on its right', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    final card = tester.getRect(
      find.byKey(const ValueKey('card-border')).first,
    );
    final popover = tester.getRect(find.byKey(_popover));
    expect(popover.left, greaterThan(card.right));
    expect(popover.top, lessThanOrEqualTo(card.center.dy));
    expect(popover.bottom, greaterThanOrEqualTo(card.center.dy));
  });

  testWidgets('Space does nothing with no card or two cards selected', (
    tester,
  ) async {
    await pumpCanvas(tester);
    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsNothing);

    select({'1', '2'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('Esc closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('a selection change closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    select({'2'});
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('the same selection set again keeps it open', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    select({'1'});
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsOneWidget);
  });

  testWidgets('dragging the card closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    final card = tester.getCenter(
      find.byKey(const ValueKey('card-border')).first,
    );
    await tester.dragFrom(
      card,
      const Offset(60, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('zooming closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('scrolling the canvas closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 500));
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(700, 500),
        scrollDelta: Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('switching to Monitoring closes it', (tester) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    container.read(appSettingsProvider.notifier).setMonitoringView(true);
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('it does not open in Alignment mode, and Alignment closes it', (
    tester,
  ) async {
    await pumpCanvas(tester);
    select({'1'});
    await tester.pump();
    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsOneWidget);

    final alignment =
        container.read(alignmentProvider.notifier) as _FakeAlignment;
    alignment.setActive(true);
    await tester.pumpAndSettle();
    expect(find.byKey(_popover), findsNothing);

    await press(tester, LogicalKeyboardKey.space);
    expect(find.byKey(_popover), findsNothing);
  });

  testWidgets('Esc in Alignment mode still leaves Alignment', (tester) async {
    await pumpCanvas(tester);
    final alignment =
        container.read(alignmentProvider.notifier) as _FakeAlignment;
    alignment.setActive(true);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.escape);
    expect(container.read(alignmentProvider).active, isFalse);
  });

  testWidgets('the context menu item opens it for that card alone', (
    tester,
  ) async {
    await pumpCanvas(tester);
    select({'1', '2'});
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('card-border')).last,
      buttons: kSecondaryButton,
      // The border is drawn over the card and ignores the pointer; the card
      // under it takes the click.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick status'));
    await tester.pumpAndSettle();
    expect(container.read(selectionProvider), {'2'});
    expect(inPopover('10.0.0.2'), findsOneWidget);
  });
}
