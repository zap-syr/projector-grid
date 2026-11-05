import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/lens_commands.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/project_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selected_lens_lock_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _bar = CommandSource.controlBar;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  late FakeProtocolService fake;
  setUp(() => fake = FakeProtocolService());

  testWidgets('lens commands skip locked projectors from any source', (
    tester,
  ) async {
    final c = makeContainer(fake);
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1'), node('2'), node('3')]);
    ws.setLensLocked(['1', '2'], true, source: _bar);

    final home = await ws.sendCommandToAll(kLensHomeCommand, source: _bar);
    expect(fake.sentCommands, [('10.0.0.3', kLensHomeCommand)]);
    expect(home.skipped.map((n) => n.id), ['1', '2']);
    final skippedLines = [
      for (final e in c.read(eventLogProvider))
        if (e.outcome == CommandOutcome.skipped) e.message,
    ];
    expect(skippedLines, ['Skipped: lens locked', 'Skipped: lens locked']);

    fake.sentCommands.clear();
    const web = CommandSource.web(ip: '10.0.0.5', role: 'operator');
    await ws.sendCommandToNodes(['1'], 'VXX:LNSI0=+00001', source: web);
    expect(fake.sentCommands, isEmpty, reason: 'calibration is blocked too');

    // Anything that doesn't move the lens still goes.
    await ws.sendCommandToNodes(['1'], 'OSH:1', source: web);
    await ws.sendCommandToNodes(['1'], 'VXX:LNEI1=+00001', source: web);
    expect(fake.sentCommands, [
      ('10.0.0.1', 'OSH:1'),
      ('10.0.0.1', 'VXX:LNEI1=+00001'),
    ]);
    c.dispose();
  });

  test('one log row kind per change, nothing for no change', () {
    final c = makeContainer(fake);
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1'), node('2')]);
    ws.setLensLocked(['1', '2'], true, source: _bar);
    ws.setLensLocked(['1'], true, source: _bar);
    final events = c.read(eventLogProvider);
    expect(events, hasLength(2));
    expect(
      events.map((e) => e.groupKind),
      everyElement(LogGroupKind.lensLocked),
    );
  });

  test('toggle locks a mixed selection first, then unlocks it', () {
    final c = makeContainer(fake);
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1'), node('2'), node('3')]);
    c.listen(selectedLensLockProvider, (_, _) {});
    c.read(selectionProvider.notifier).set({'1', '2'});
    ws.setLensLocked(['1'], true, source: _bar);
    expect(c.read(selectedLensLockProvider), (
      state: LensLockState.some,
      locked: 1,
      total: 2,
    ));

    ws.toggleLensLockOfSelected(source: _bar);
    expect(c.read(selectedLensLockProvider).state, LensLockState.all);
    ws.toggleLensLockOfSelected(source: _bar);
    expect(c.read(selectedLensLockProvider).state, LensLockState.none);
    expect(
      c.read(workspaceProvider).map((n) => n.lensLocked),
      everyElement(false),
    );
  });

  test('undo never lifts or sets the lock, and the project is dirty', () {
    final c = makeContainer(fake);
    c.listen(projectStateProvider, (_, _) {});
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1', x: 40)]);
    drag(c, '1', const Offset(100, 0));
    ws.setLensLocked(['1'], true, source: _bar);
    expect(c.read(projectStateProvider).isDirty, isTrue);

    ws.undo();
    final n = c.read(workspaceProvider).single;
    expect(n.x, 40, reason: 'the move is undone');
    expect(n.lensLocked, isTrue, reason: 'the lock is not');
  });
}
