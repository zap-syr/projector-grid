import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/lens_commands.dart';
import 'package:projector_grid/features/workspace/presentation/providers/custom_commands_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/confirm_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/control_bar.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/control_bar/control_bar_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/control_bar/lens_card.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/control_bar/system_tab.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_command_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  final configDir = useTempConfigDir();

  late FakeProtocolService fake;
  late ProviderContainer container;

  setUp(() {
    // Online, so a poll doesn't take projector 1 offline (commands skip
    // offline projectors).
    fake = FakeProtocolService()
      ..pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
  });

  /// The bar on the right of a window of [size], with projector 1 selected
  /// unless [select] is false.
  Future<void> pumpBar(
    WidgetTester tester, {
    bool select = true,
    Size size = const Size(1280, 1000),
    List<(String, String)> commands = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The scope belongs to the widget tree, so disposing the tree at the end
    // of the test also cancels the workspace's polling timer.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Row(
              children: [
                Expanded(child: SizedBox()),
                ControlBar(),
              ],
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(ControlBar)),
    );
    // Kept alive as the canvas does in the app; nothing in the bar watches
    // the node list.
    container.listen(workspaceProvider, (_, _) {});
    for (final (name, command) in commands) {
      container.read(customCommandsProvider.notifier).add(name, command);
    }
    container.read(workspaceProvider.notifier).setNodes([node('1')]);
    if (select) container.read(selectionProvider.notifier).set({'1'});
    await tester.pumpAndSettle();
  }

  List<String> sent() => [for (final (_, cmd) in fake.sentCommands) cmd];

  /// A command button by its label: [find.text] would also match the
  /// invisible widest label every Set button lays out (`Show`).
  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is CommandButton && w.label == label);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the bar is 320 px wide', (tester) async {
    await pumpBar(tester);
    expect(tester.getSize(find.byType(ControlBar)).width, 320);
  });

  testWidgets('Home position in the Lens shift header sends the home '
      'command', (tester) async {
    await pumpBar(tester);
    await tapAndSettle(tester, find.byKey(const ValueKey('lens-home')));
    expect(sent(), [kLensHomeCommand]);
  });

  testWidgets('each lens button sends its axis, direction and speed', (
    tester,
  ) async {
    await pumpBar(tester);
    final expected = <ValueKey<String>, String>{};
    for (final speed in LensSpeed.values) {
      expected[lensButtonKey('lens', LensDirection.up, speed)] =
          lensStepCommand(LensAxis.shiftV, plus: true, speed: speed);
      expected[lensButtonKey('lens', LensDirection.down, speed)] =
          lensStepCommand(LensAxis.shiftV, plus: false, speed: speed);
      expected[lensButtonKey('lens', LensDirection.left, speed)] =
          lensStepCommand(LensAxis.shiftH, plus: false, speed: speed);
      expected[lensButtonKey('lens', LensDirection.right, speed)] =
          lensStepCommand(LensAxis.shiftH, plus: true, speed: speed);
      for (final (prefix, axis) in [
        ('focus', LensAxis.focus),
        ('zoom', LensAxis.zoom),
      ]) {
        expected[lensButtonKey(prefix, LensDirection.left, speed)] =
            lensStepCommand(axis, plus: false, speed: speed);
        expected[lensButtonKey(prefix, LensDirection.right, speed)] =
            lensStepCommand(axis, plus: true, speed: speed);
      }
    }
    expect(expected, hasLength(24));
    for (final MapEntry(:key, :value) in expected.entries) {
      fake.sentCommands.clear();
      await tapAndSettle(tester, find.byKey(key));
      expect(sent(), [value], reason: key.value);
    }
  });

  testWidgets('a motor step is dropped while the previous one is in '
      'flight', (tester) async {
    await pumpBar(tester);
    final hold = Completer<void>();
    fake.holdCommands['10.0.0.1'] = hold;
    final up = find.byKey(
      lensButtonKey('lens', LensDirection.up, LensSpeed.slow),
    );
    await tester.tap(up);
    await tester.pump();
    await tester.tap(up);
    await tester.pump();
    expect(sent(), hasLength(1));
    hold.complete();
    await tester.pumpAndSettle();
    await tester.tap(up);
    await tester.pumpAndSettle();
    expect(sent(), hasLength(2));
  });

  testWidgets('Lens setup starts collapsed and opening it only pushes the '
      'cards below it', (tester) async {
    await pumpBar(tester);
    expect(find.text('Calibration'), findsNothing);
    expect(find.text('Lens type'), findsNothing);

    final home = find.byKey(const ValueKey('lens-home'));
    final cross = find.byKey(
      lensButtonKey('lens', LensDirection.left, LensSpeed.fast),
    );
    final testPattern = find.text('Test pattern');
    final homeBefore = tester.getTopLeft(home);
    final crossBefore = tester.getTopLeft(cross);
    final belowBefore = tester.getTopLeft(testPattern);

    await tapAndSettle(tester, find.byKey(const ValueKey('lens-setup-toggle')));
    expect(find.text('Calibration'), findsOneWidget);
    expect(find.text('Lens type'), findsOneWidget);
    // ensureVisible may scroll; compare against the cross, which is above.
    final shift = tester.getTopLeft(cross).dy - crossBefore.dy;
    expect(tester.getTopLeft(home).dy - homeBefore.dy, shift);
    expect(
      tester.getTopLeft(testPattern).dy - belowBefore.dy - shift,
      greaterThan(0),
    );

    // Input's Set comes first, then Calibration's.
    await tapAndSettle(tester, button('Set').at(1));
    expect(sent(), ['VXX:LNSI0=+00001']);
  });

  testWidgets('without a selection the controls are disabled and nothing '
      'moves', (tester) async {
    await pumpBar(tester);
    final probes = [
      button('Standby'),
      find.text('Input'),
      find.byKey(const ValueKey('lens-home')),
      find.byKey(lensButtonKey('zoom', LensDirection.right, LensSpeed.fast)),
      find.byKey(const ValueKey('test-pattern-off')),
      button('Show'),
    ];
    final before = [for (final f in probes) tester.getRect(f)];

    container.read(selectionProvider.notifier).clear();
    await tester.pumpAndSettle();
    for (var i = 0; i < probes.length; i++) {
      expect(tester.getRect(probes[i]), before[i], reason: '$i');
    }

    await tester.tap(button('Standby'));
    await tester.tap(find.byKey(const ValueKey('lens-home')));
    await tester.tap(button('Show'));
    await tester.pumpAndSettle();
    expect(sent(), isEmpty);
    expect(tester.widget<CommandButton>(button('Standby')).onPressed, isNull);
  });

  testWidgets('the tab strip stays put across tabs', (tester) async {
    await pumpBar(tester, commands: [('Freeze', 'OFZ:1')]);
    final tabs = find.byKey(const ValueKey('control-bar-tabs'));
    final rect = tester.getRect(tabs);
    final generalTab = tester.getRect(find.text('General'));
    for (final label in ['System', 'Custom', 'General', 'Custom', 'System']) {
      await openTab(tester, label);
      expect(tester.getRect(tabs), rect, reason: label);
      expect(tester.getRect(find.text('General')), generalTab, reason: label);
    }
    // The Custom tab carries the command count.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Off and Show send test patterns; Show replaced Set', (
    tester,
  ) async {
    await pumpBar(tester);
    await tapAndSettle(tester, find.byKey(const ValueKey('test-pattern-off')));
    await tapAndSettle(tester, button('Show'));
    expect(button('Set'), findsOneWidget); // Input's only
    expect(sent(), ['OTS:00', 'OTS:01']);
  });

  testWidgets('a favourite slot keeps its size filled and empty; empty adds '
      'the picked pattern, Ctrl+click clears', (tester) async {
    // Tall enough that nothing scrolls, so rects compare as they are.
    await pumpBar(tester, size: const Size(1280, 1400));
    final slot = find.byKey(const ValueKey('favorite-slot-0'));
    final emptyRect = tester.getRect(slot);

    await tapAndSettle(tester, slot);
    expect(tester.getRect(slot), emptyRect);
    final file = File('${configDir().path}/test_pattern_favorites.json');
    expect(jsonDecode(file.readAsStringSync()), ['OTS:01', null, null, null]);

    // The picked pattern is a favourite now, so the next slot can't add it.
    await tapAndSettle(tester, find.byKey(const ValueKey('favorite-slot-1')));
    expect(jsonDecode(file.readAsStringSync()), ['OTS:01', null, null, null]);

    // A plain click shows the favourite.
    await tapAndSettle(tester, slot);
    expect(sent(), ['OTS:01']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(slot);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(tester.getRect(slot), emptyRect);
    expect(jsonDecode(file.readAsStringSync()), [null, null, null, null]);
    expect(sent(), ['OTS:01']);
  });

  testWidgets('favourites are read back from the file', (tester) async {
    File('${configDir().path}/test_pattern_favorites.json')
        .writeAsStringSync(jsonEncode(['OTS:87', null, 'bogus', null]));
    await pumpBar(tester);
    await tapAndSettle(tester, find.byKey(const ValueKey('favorite-slot-0')));
    await tapAndSettle(tester, find.byKey(const ValueKey('favorite-slot-2')));
    expect(sent(), ['OTS:87']);
  });

  testWidgets('System options show the new labels and send the same '
      'commands', (tester) async {
    await pumpBar(tester);
    await openTab(tester, 'System');
    expect(find.text('Front, desk'), findsOneWidget);
    expect(find.text('Default logo'), findsOneWidget);
    // Fade in and fade out start at zero, which reads Off.
    expect(find.text('Off'), findsAtLeastNWidgets(2));
    final systemSet = find.descendant(
      of: find.byType(SystemTab),
      matching: button('Set'),
    );
    await tapAndSettle(tester, systemSet.at(3));
    await tapAndSettle(tester, systemSet.at(4));
    expect(sent(), ['OIL:0', 'VXX:SEFS1=0.0']);
    await tapAndSettle(
      tester,
      find.descendant(of: find.byType(SystemTab), matching: button('On')),
    );
    expect(sent().last, 'VXX:QPDI1=+00001');
  });

  testWidgets('a custom command runs, and its ⋮ menu edits and deletes with '
      'a confirm', (tester) async {
    await pumpBar(tester, commands: [('Freeze', 'OFZ:1')]);
    await openTab(tester, 'Custom');
    final id = container.read(customCommandsProvider).single.id;

    await tapAndSettle(tester, find.byKey(ValueKey('run-$id')));
    expect(sent(), ['OFZ:1']);

    await tapAndSettle(tester, find.byKey(ValueKey('more-$id')));
    await tapAndSettle(tester, find.text('Edit'));
    expect(find.byType(CustomCommandDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CustomCommandDialog), findsNothing);

    await tapAndSettle(tester, find.byKey(ValueKey('more-$id')));
    await tapAndSettle(tester, find.text('Delete'));
    expect(find.byType(ConfirmDialog<bool>), findsOneWidget);
    await tapAndSettle(tester, find.text('Cancel'));
    expect(container.read(customCommandsProvider), hasLength(1));

    await tapAndSettle(tester, find.byKey(ValueKey('more-$id')));
    await tapAndSettle(tester, find.text('Delete'));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(ConfirmDialog<bool>),
        matching: find.text('Delete'),
      ),
    );
    expect(container.read(customCommandsProvider), isEmpty);
    expect(find.text('No custom commands yet'), findsOneWidget);
  });

  testWidgets('fits the 800x600 window: no overflow, the General tab '
      'scrolls', (tester) async {
    // 600 minus the title, menu, toolbar and status bars above the bar.
    await pumpBar(tester, size: const Size(800, 470));
    expect(tester.takeException(), isNull);
    final show = button('Show');
    await tester.ensureVisible(show);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(show).dy, lessThanOrEqualTo(470));
    for (final label in ['System', 'Custom']) {
      await openTab(tester, label);
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
