import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alignment.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  late FakeProtocolService fake;
  setUp(() {
    fake = FakeProtocolService()
      ..rawResponses.addAll({
        'QSH': '0',
        'QTS': '00',
        'QVX:SEFS1': 'SEFS1=0.0',
        'QVX:SEFS2': 'SEFS2=0.0',
      });
  });

  // One row of three cards, 20 px apart: 1 | 2 | 3.
  ProviderContainer setUpRow() {
    final c = makeContainer(fake);
    c.read(workspaceProvider.notifier).setNodes([
      node('1', x: 40),
      node('2', x: 180),
      node('3', x: 320),
    ]);
    return c;
  }

  List<String> sentTo(String ip) => [
    for (final (i, cmd) in fake.sentCommands)
      if (i == ip) cmd,
  ];

  Future<void> settle() => pumpEventQueue();

  test('enter focuses the first card and closes the rest', () async {
    final c = setUpRow();
    await c.read(alignmentProvider.notifier).enter();
    await settle();

    final state = c.read(alignmentProvider);
    expect(state.active, isTrue);
    expect(state.focusedId, '1');
    expect(c.read(selectionProvider), {'1'});
    expect(state.roles, {
      '1': AlignmentRole.focused,
      '2': AlignmentRole.closed,
      '3': AlignmentRole.closed,
    });
    // Geometry preset by default: cross hatch on the focused projector.
    expect(sentTo('10.0.0.1'), ['OTS:07']);
    expect(sentTo('10.0.0.2'), ['OSH:1']);
    expect(c.read(workspaceProvider).first.testPattern, 'OTS:07');
  });

  test('the focused projector stays selected while the mode is on', () async {
    final c = setUpRow();
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    c.read(workspaceProvider.notifier).deselectAll();
    expect(c.read(selectionProvider), {'1'});
    c.read(workspaceProvider.notifier).selectAll();
    expect(c.read(selectionProvider), {'1'});

    await a.exit();
    c.read(workspaceProvider.notifier).deselectAll();
    expect(c.read(selectionProvider), isEmpty);
  });

  test('next / previous step in layout order and wrap', () async {
    final c = setUpRow();
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    await settle();
    fake.sentCommands.clear();

    a.next();
    await settle();
    expect(c.read(alignmentProvider).focusedId, '2');
    expect(sentTo('10.0.0.1'), ['OSH:1']);
    expect(sentTo('10.0.0.2'), ['OTS:07', 'OSH:0']);

    a.previous();
    a.previous();
    await settle();
    expect(c.read(alignmentProvider).focusedId, '3');
  });

  test('rapid presses send only what the final focus needs', () async {
    final c = setUpRow();
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    await settle();
    fake.sentCommands.clear();

    // 10 presses in one go: 1 → … → 2 (10 steps around a row of 3).
    for (var i = 0; i < 10; i++) {
      a.next();
    }
    await settle();

    expect(c.read(alignmentProvider).focusedId, '2');
    expect(sentTo('10.0.0.1'), ['OSH:1']);
    expect(sentTo('10.0.0.2'), ['OTS:07', 'OSH:0']);
    // 3 was only passed through: at most the pattern the first press
    // started, and its shutter never opened.
    expect(sentTo('10.0.0.3'), isNot(contains('OSH:0')));
    expect(fake.sentCommands.length, lessThanOrEqualTo(4));
  });

  test(
    'a projector that stops answering does not hold up the others',
    () async {
      final c = setUpRow();
      final a = c.read(alignmentProvider.notifier);
      final hung = Completer<void>();
      fake.holdCommands['10.0.0.2'] = hung;
      await a.enter(); // 2's close command now hangs
      await settle();

      a.next();
      a.next(); // focus 3 while 2 is still stuck
      await settle();
      // OSH:1 is entry closing it; then it's focused without waiting on 2.
      expect(sentTo('10.0.0.3'), ['OSH:1', 'OTS:07', 'OSH:0']);

      hung.complete();
      await settle();
    },
  );

  test('neighbours get the Others pattern', () async {
    final c = setUpRow();
    final a = c.read(alignmentProvider.notifier);
    c.read(selectionProvider.notifier).selectOnly('2');
    // A remembered preference: set before entering, it applies on entry.
    a.toggleNeighbours();
    await a.enter();
    await settle();
    expect(sentTo('10.0.0.1'), ['OTS:70']);
    expect(sentTo('10.0.0.3'), ['OTS:70']);
    expect(c.read(appSettingsProvider).alignmentShowNeighbours, isTrue);
  });

  test('scope is the selection when two or more cards are selected', () async {
    final c = setUpRow();
    c.read(selectionProvider.notifier).set({'2', '3'});
    await c.read(alignmentProvider.notifier).enter();
    await settle();
    expect(c.read(alignmentProvider).scope, {'2', '3'});
    expect(c.read(alignmentProvider).focusedId, '2');
    expect(sentTo('10.0.0.1'), isEmpty);
  });

  test('offline projectors are left out', () async {
    final c = makeContainer(fake);
    c.read(workspaceProvider.notifier).setNodes([
      node('1'),
      node('2', x: 180, status: ConnectionStatus.offline),
    ]);
    await c.read(alignmentProvider.notifier).enter();
    expect(c.read(alignmentProvider).scope, {'1'});
  });

  test('exit restores shutter and pattern captured on entry', () async {
    final c = setUpRow();
    fake.rawResponsesByIp['10.0.0.2'] = {'QTS': '22'};
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    a.next();
    await settle();
    fake.sentCommands.clear();

    await a.exit();
    expect(c.read(alignmentProvider).active, isFalse);
    // 1 showed the cross hatch and was then closed; 2 is still open with
    // the cross hatch.
    expect(sentTo('10.0.0.1'), ['OTS:00', 'OSH:0']);
    expect(sentTo('10.0.0.2'), ['OTS:22']);
    expect(sentTo('10.0.0.3'), ['OSH:0']);
  });

  test('non-zero shutter fade is zeroed, persisted, and restored', () async {
    final c = setUpRow();
    fake.rawResponsesByIp['10.0.0.2'] = {
      'QVX:SEFS1': 'SEFS1=2.0',
      'QVX:SEFS2': 'SEFS2=1.5',
    };
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    await settle();
    expect(sentTo('10.0.0.1'), isNot(contains('VXX:SEFS1=0.0')));
    expect(sentTo('10.0.0.2'), containsAll(['VXX:SEFS1=0.0', 'VXX:SEFS2=0.0']));
    expect(c.read(appSettingsProvider).pendingFadeRestores, {
      '10.0.0.2': (fadeIn: '2.0', fadeOut: '1.5'),
    });

    await a.exit();
    expect(sentTo('10.0.0.2'), containsAll(['VXX:SEFS1=2.0', 'VXX:SEFS2=1.5']));
    expect(c.read(appSettingsProvider).pendingFadeRestores, isEmpty);
  });

  test('fades left zeroed by a previous session are restored when the '
      'projector is online', () async {
    final c = makeContainer(fake);
    c.read(appSettingsProvider.notifier).setPendingFadeRestore('10.0.0.1', (
      fadeIn: '3.0',
      fadeOut: '3.0',
    ));
    c.read(alignmentProvider.notifier);
    c.read(workspaceProvider.notifier).setNodes([node('1')]);
    await settle();
    expect(sentTo('10.0.0.1'), ['VXX:SEFS1=3.0', 'VXX:SEFS2=3.0']);
    expect(c.read(appSettingsProvider).pendingFadeRestores, isEmpty);
  });

  test('changing the preset resends patterns', () async {
    final c = setUpRow();
    final a = c.read(alignmentProvider.notifier);
    await a.enter();
    await settle();
    fake.sentCommands.clear();

    a.setPreset(AlignmentPreset.color);
    await settle();
    expect(sentTo('10.0.0.1'), ['OTS:01']);
    expect(c.read(alignmentProvider).othersPattern, isNull);
    expect(c.read(appSettingsProvider).alignmentPreset, AlignmentPreset.color);
  });
}
