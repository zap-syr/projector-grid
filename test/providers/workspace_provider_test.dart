import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
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

  List<String> logMessages(c) => [
    for (final e in c.read(eventLogProvider) as List<LogEvent>) e.message,
  ];

  group('nodes', () {
    test(
      'addProjectors lays nodes out on the grid with mapped status',
      () async {
        final c = makeContainer(fake);
        fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
        c.read(workspaceProvider.notifier).addProjectors([
          {'ip': '10.0.0.1', 'name': 'A', 'status': 'online'},
          {'ip': '10.0.0.2', 'name': 'B', 'status': 'auth_error'},
          {'ip': '10.0.0.3', 'name': 'C'},
        ]);
        final nodes = c.read(workspaceProvider);
        expect(nodes.map((n) => (n.x, n.y)), [(40, 40), (180, 40), (320, 40)]);
        expect(nodes.map((n) => n.connectionStatus), [
          ConnectionStatus.connected,
          ConnectionStatus.unauthorized,
          ConnectionStatus.offline,
        ]);
        await pumpEventQueue();
        // Online node polled right away; unauthorized node left alone.
        expect(fake.pollCount, 1);
        expect(c.read(workspaceProvider).first.powerStatus, PowerStatus.on);
      },
    );

    test('deleteSelected removes only selected nodes and clears selection', () {
      final c = makeContainer(fake);
      c.read(workspaceProvider.notifier).setNodes([
        node('1'),
        node('2'),
        node('3'),
      ]);
      c.read(selectionProvider.notifier).set({'1', '3'});
      c.read(workspaceProvider.notifier).deleteSelected();
      expect(c.read(workspaceProvider).map((n) => n.id), ['2']);
      expect(c.read(selectionProvider), isEmpty);
    });

    test('dragging moves all selected nodes, clamped to the canvas', () {
      final c = makeContainer(fake);
      c.read(workspaceProvider.notifier).setNodes([
        node('1', x: 100, y: 100),
        node('2', x: 300, y: 100),
        node('3', x: 500, y: 100),
      ]);
      c.read(selectionProvider.notifier).set({'1', '2'});
      drag(c, '1', const Offset(-200, 50));
      expect(c.read(workspaceProvider).map((n) => (n.x, n.y)), [
        (0, 150),
        (100, 150),
        (500, 100),
      ]);
    });

    test('deleteGroup unassigns its nodes', () {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', groupId: 'g'), node('2')]);
      ws.addGroup(const ProjectorGroup(id: 'g', name: 'Stage', color: 0));
      ws.deleteGroup('g');
      expect(ws.groups, isEmpty);
      expect(c.read(workspaceProvider).first.groupId, isNull);
    });
  });

  group('undo / redo', () {
    test('restores layout and groups', () {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', x: 40, y: 40)]);
      drag(c, '1', const Offset(100, 0));
      ws.addGroup(const ProjectorGroup(id: 'g', name: 'Stage', color: 0));
      expect(ws.canUndo, isTrue);

      ws.undo();
      expect(ws.groups, isEmpty);
      ws.undo();
      expect(c.read(workspaceProvider).single.x, 40);
      expect(ws.canUndo, isFalse);

      ws.redo();
      ws.redo();
      expect(c.read(workspaceProvider).single.x, 140);
      expect(ws.groups.single.id, 'g');
    });

    test(
      'keeps live telemetry instead of the snapshot (CLAUDE.md invariant)',
      () async {
        final c = makeContainer(fake);
        final ws = c.read(workspaceProvider.notifier);
        fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
        ws.setNodes([node('1', x: 40)]);
        await ws.refreshAll();
        drag(c, '1', const Offset(100, 0));

        // Telemetry changes after the snapshot was taken.
        fake.pollResults['10.0.0.1'] = (
          ProbeResult.online,
          telemetry(
            power: 'POWI1=+00001',
            shutter: '1',
            intakeTemp: '0045/0113',
          ),
        );
        await ws.refreshAll();

        ws.undo();
        final n = c.read(workspaceProvider).single;
        expect(n.x, 40, reason: 'layout rolled back');
        expect(n.connectionStatus, ConnectionStatus.connected);
        expect(n.powerStatus, PowerStatus.standby);
        expect(n.shutterStatus, ShutterStatus.closed);
        expect(n.intakeTemp, '45°C');
        expect(n.runtime, '2,185H');
        expect(n.name, 'PT-RQ25K');

        ws.redo();
        final r = c.read(workspaceProvider).single;
        expect(r.x, 140);
        expect(r.intakeTemp, '45°C');
      },
    );

    test('a new edit clears the redo stack', () {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1')]);
      drag(c, '1', const Offset(20, 0));
      ws.undo();
      expect(ws.canRedo, isTrue);
      drag(c, '1', const Offset(40, 0));
      expect(ws.canRedo, isFalse);
    });
  });

  group('commands and optimistic updates', () {
    testWidgets('shutter commands flip state and log', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2')]);
      c.read(selectionProvider.notifier).set({'1'});

      await ws.sendCommandToSelected('OSH:0', source: _bar);
      expect(c.read(workspaceProvider).map((n) => n.shutterStatus), [
        ShutterStatus.open,
        ShutterStatus.closed,
      ]);
      await ws.sendCommandToSelected('OSH:1', source: _bar);
      expect(
        c.read(workspaceProvider).first.shutterStatus,
        ShutterStatus.closed,
      );
      expect(logMessages(c).first, 'Shutter Close');
      expect(c.read(eventLogProvider).first.source, _bar);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('a failed command leaves state untouched and logs it', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.commandSucceeds['10.0.0.1'] = false;
      ws.setNodes([node('1')]);
      await ws.sendCommandToAll('OSH:0', source: _bar);
      expect(
        c.read(workspaceProvider).single.shutterStatus,
        ShutterStatus.closed,
      );
      expect(
        logMessages(c).single,
        'Shutter Open failed: no answer or refused',
      );
      expect(c.read(eventLogProvider).single.severity, LogSeverity.error);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('offline and unauthorized nodes are skipped', (tester) async {
      final c = makeContainer(fake);
      c.read(workspaceProvider.notifier).setNodes([
        node('1'),
        node('2', status: ConnectionStatus.offline),
        node('3', status: ConnectionStatus.unauthorized),
        node('4', status: ConnectionStatus.unprotected),
      ]);
      await c
          .read(workspaceProvider.notifier)
          .sendCommandToAll('OOS:1', source: _bar);
      expect(fake.sentCommands.map((s) => s.$1), ['10.0.0.1', '10.0.0.4']);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('a command to several projectors logs one batch', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.commandSucceeds['10.0.0.2'] = false;
      ws.setNodes([
        node('1'),
        node('2'),
        node('3', status: ConnectionStatus.offline),
        node('4', status: ConnectionStatus.unauthorized),
      ]);
      final result = await ws.sendCommandToAll('OOS:1', source: _bar);
      expect(result.ok, 1);
      expect(result.failed.map((n) => n.id), ['2']);
      expect(result.skipped.map((n) => n.id), ['3', '4']);

      final events = c.read(eventLogProvider);
      final batchIds = events.map((e) => e.batch?.id).toSet();
      expect(batchIds, hasLength(1), reason: 'every line in one batch');
      expect(batchIds.single, isNotNull);
      final summary = events.first;
      expect(summary.isBatchSummary, isTrue);
      expect(summary.severity, LogSeverity.warning);
      expect(summary.message, 'OSD On');
      expect(summary.batch!.target, '4 projectors');
      expect(summary.batch!.source, _bar);
      final lines = {
        for (final e in events.skip(1)) e.projectorIp: (e.outcome, e.message),
      };
      expect(lines, {
        '10.0.0.1': (CommandOutcome.sent, 'Sent'),
        '10.0.0.2': (CommandOutcome.failed, 'Failed: no answer or refused'),
        '10.0.0.3': (CommandOutcome.skipped, 'Skipped: offline'),
        '10.0.0.4': (CommandOutcome.skipped, 'Skipped: wrong login'),
      });
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('a batch to one group names the group', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', groupId: 'g'), node('2', groupId: 'g')]);
      ws.addGroup(const ProjectorGroup(id: 'g', name: 'Stage', color: 0));
      await ws.sendCommandToGroup('g', 'OSH:1', source: CommandSource.osc);
      final summary = c.read(eventLogProvider).first;
      expect(summary.batch!.target, 'Stage, 2 projectors');
      expect(summary.severity, LogSeverity.info);
      c.dispose();
    });

    testWidgets('single-projector commands stay one row', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2')]);
      c.read(selectionProvider.notifier).set({'1'});
      await ws.sendCommandToSelected('OOS:1', source: _bar);
      expect(logMessages(c), ['OSD On']);
      expect(c.read(eventLogProvider).single.batch, isNull);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('one offline projector gets a grey skipped row', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      c.read(selectionProvider.notifier).set({'1'});
      await ws.sendCommandToSelected('OOS:1', source: _bar);
      expect(fake.sentCommands, isEmpty);
      expect(logMessages(c), ['OSD On skipped: offline']);
      expect(c.read(eventLogProvider).single.severity, LogSeverity.info);
      c.dispose();
    });

    testWidgets('group commands only reach that group', (tester) async {
      final c = makeContainer(fake);
      c.read(workspaceProvider.notifier).setNodes([
        node('1', groupId: 'g'),
        node('2'),
      ]);
      await c
          .read(workspaceProvider.notifier)
          .sendCommandToGroup('g', 'POF', source: _bar);
      expect(fake.sentCommands, [('10.0.0.1', 'POF')]);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('sendCommandToNodes reaches those ids and logs the source', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2'), node('3')]);
      const web = CommandSource.web(ip: '10.0.0.5', role: 'operator');
      await ws.sendCommandToNodes(['1', '3'], 'OOS:1', source: web);
      expect(fake.sentCommands, [('10.0.0.1', 'OOS:1'), ('10.0.0.3', 'OOS:1')]);
      final summary = c.read(eventLogProvider).first;
      expect(summary.source!.label, 'from Web, 10.0.0.5 (operator)');
      expect(summary.batch!.source.kind, CommandSourceKind.web);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('retryFailed sends to the failed ids still there', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      // '2' changed its IP since the batch, '9' was removed.
      ws.setNodes([
        node('1'),
        node('2').copyWith(ipAddress: '10.0.0.22'),
        node('3'),
      ]);
      await ws.retryFailed(['2', '9'], 'OSH:1');
      expect(fake.sentCommands, [('10.0.0.22', 'OSH:1')]);
      final row = c.read(eventLogProvider).single;
      expect(row.source, CommandSource.retry);
      expect(row.nodeId, '2');
      c.dispose();
    });

    testWidgets('PON shows turningOn, then settles on the real state', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1')]);
      fake.rawResponses.addAll({
        'QVX:POWI1': 'POWI1=+00002',
        'QSH': '0',
        'QVX:NSGS1': 'NSGS1=1080/60p',
      });

      await ws.sendCommandToAll('PON', source: _bar);
      expect(
        c.read(workspaceProvider).single.powerStatus,
        PowerStatus.turningOn,
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        c.read(workspaceProvider).single.powerStatus,
        PowerStatus.turningOn,
      );

      fake.rawResponses['QVX:POWI1'] = 'POWI1=+00003';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final n = c.read(workspaceProvider).single;
      expect(n.powerStatus, PowerStatus.on);
      expect(n.shutterStatus, ShutterStatus.open);
      expect(n.signal, '1080/60p');
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('PON that never took reverts to what the projector reports', (
      tester,
    ) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1')]);
      fake.rawResponses['QVX:POWI1'] = 'POWI1=+00001';

      await ws.sendCommandToAll('PON', source: _bar);
      expect(
        c.read(workspaceProvider).single.powerStatus,
        PowerStatus.turningOn,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(c.read(workspaceProvider).single.powerStatus, PowerStatus.standby);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('POF shows cooling until standby', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1').copyWith(powerStatus: PowerStatus.on)]);
      fake.rawResponses['QVX:POWI1'] = 'POWI1=+00001';
      await ws.sendCommandToAll('POF', source: _bar);
      expect(c.read(workspaceProvider).single.powerStatus, PowerStatus.cooling);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(c.read(workspaceProvider).single.powerStatus, PowerStatus.standby);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });
  });

  group('polling', () {
    test('telemetry is parsed into the node', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (ProbeResult.unprotected, telemetry());
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      final n = c.read(workspaceProvider).single;
      expect(n.connectionStatus, ConnectionStatus.unprotected);
      expect(n.name, 'PT-RQ25K');
      expect(n.serialNumber, 'SN123');
      expect(n.powerStatus, PowerStatus.on);
      expect(n.shutterStatus, ShutterStatus.open);
      expect(n.input, 'HDMI 1');
      expect(n.signal, '1080/60p');
      expect(n.runtime, '2,185H');
      expect(n.lightRuntime, '1,577H');
      expect(n.intakeTemp, '30°C');
      expect(n.exhaustTemp, '41°C');
      expect(n.acVoltage, '230V');
      expect(n.errors, 'NO ERRORS');
    });

    test('a field whose query failed keeps its last known value', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      fake.pollResults['10.0.0.1'] = (
        ProbeResult.online,
        telemetry(power: null, runtime: null, intakeTemp: null, signal: null),
      );
      await ws.refreshAll();
      final n = c.read(workspaceProvider).single;
      expect(n.powerStatus, PowerStatus.on);
      expect(n.runtime, '2,185H');
      expect(n.intakeTemp, '30°C');
      expect(n.signal, '1080/60p');
    });

    test('ER401 on signal/runtime is data, not a failure', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (
        ProbeResult.online,
        telemetry(signal: 'ER401', runtime: 'ER401'),
      );
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      final n = c.read(workspaceProvider).single;
      expect(n.signal, 'NO SIGNAL');
      expect(n.runtime, '-');
    });

    test('"Went offline" is logged once, not on every poll', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      expect(
        c.read(workspaceProvider).single.connectionStatus,
        ConnectionStatus.offline,
      );
      await ws.refreshAll();
      await ws.refreshAll();
      expect(logMessages(c).where((m) => m == 'Went offline'), hasLength(1));
      // The Offline rule is on by default: the line carries its red.
      expect(c.read(eventLogProvider).first.severity, LogSeverity.error);
    });

    test('a projector offline at its first poll logs "Went offline"', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      await ws.refreshAll();
      expect(logMessages(c), ['Went offline']);
      await ws.refreshAll();
      expect(logMessages(c), ['Went offline']);
    });

    group('lastSeen', () {
      test(
        'set when a projector goes offline, cleared when it answers',
        () async {
          final c = makeContainer(fake);
          final ws = c.read(workspaceProvider.notifier);
          fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
          ws.setNodes([node('1')]);
          final before = DateTime.now();
          await ws.refreshAll();
          final after = DateTime.now();
          expect(c.read(workspaceProvider).single.lastSeen, isNull);

          fake.pollResults.remove('10.0.0.1');
          await ws.refreshAll();
          final seen = c.read(workspaceProvider).single.lastSeen;
          expect(seen, isNotNull);
          expect(seen!.isBefore(before), isFalse);
          expect(seen.isAfter(after), isFalse);

          // Later offline polls keep the time it was last seen.
          await ws.refreshAll();
          expect(c.read(workspaceProvider).single.lastSeen, seen);

          // An offline node is checked with checkConnection first.
          fake.reachable['10.0.0.1'] = true;
          fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
          await ws.refreshAll();
          expect(
            c.read(workspaceProvider).single.connectionStatus,
            ConnectionStatus.connected,
          );
          expect(c.read(workspaceProvider).single.lastSeen, isNull);
        },
      );

      test('an unchanged poll leaves the node list untouched', () async {
        final c = makeContainer(fake);
        final ws = c.read(workspaceProvider.notifier);
        fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
        ws.setNodes([node('1')]);
        await ws.refreshAll();
        final list = c.read(workspaceProvider);
        await ws.refreshAll();
        expect(identical(c.read(workspaceProvider), list), isTrue);
      });

      test('never seen this session: null; a new address forgets it', () async {
        final c = makeContainer(fake);
        final ws = c.read(workspaceProvider.notifier);
        ws.setNodes([node('1')]);
        await ws.refreshAll();
        expect(c.read(workspaceProvider).single.lastSeen, isNull);

        fake.reachable['10.0.0.1'] = true;
        fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
        await ws.refreshAll();
        fake.pollResults.remove('10.0.0.1');
        await ws.refreshAll();
        expect(c.read(workspaceProvider).single.lastSeen, isNotNull);

        ws.updateNode('1', '10.0.0.9', 1024, 'admin1', 'panasonic');
        await ws.refreshAll();
        expect(c.read(workspaceProvider).single.lastSeen, isNull);
      });

      test('an undo keeps the live value', () async {
        final c = makeContainer(fake);
        final ws = c.read(workspaceProvider.notifier);
        fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
        ws.setNodes([node('1', x: 40)]);
        await ws.refreshAll();
        drag(c, '1', const Offset(100, 0));
        fake.pollResults.remove('10.0.0.1');
        await ws.refreshAll();
        final seen = c.read(workspaceProvider).single.lastSeen;
        expect(seen, isNotNull);

        ws.undo();
        final n = c.read(workspaceProvider).single;
        expect(n.x, 40);
        expect(n.lastSeen, seen);
      });
    });

    test('a loaded offline node counts as polled only after a check', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      expect(c.read(workspaceProvider).single.polled, isFalse);
      await ws.refreshAll();
      expect(c.read(workspaceProvider).single.polled, isTrue);

      ws.updateNode('1', '10.0.0.9', 1024, 'admin1', 'panasonic');
      expect(c.read(workspaceProvider).single.polled, isFalse);
    });

    test('"Authentication failed" is logged once', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (ProbeResult.unauthorized, null);
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      await ws.refreshAll();
      expect(
        c.read(workspaceProvider).single.connectionStatus,
        ConnectionStatus.unauthorized,
      );
      expect(logMessages(c), ['Authentication failed']);
    });

    test('"Came online" is logged once when auth is fixed', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.unauthorized)]);
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      await ws.refreshAll();
      await ws.refreshAll();
      expect(logMessages(c).where((m) => m == 'Came online'), hasLength(1));
    });

    test('"Came online" is logged when an offline projector returns', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      fake.reachable['10.0.0.1'] = true;
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      await ws.refreshAll();
      expect(
        c.read(workspaceProvider).single.connectionStatus,
        ConnectionStatus.connected,
      );
      await ws.refreshAll();
      expect(logMessages(c).where((m) => m == 'Came online'), hasLength(1));
    });

    test('adding a reachable projector does not log "Came online"', () async {
      final c = makeContainer(fake);
      fake.reachable['10.0.0.1'] = true;
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      c.read(workspaceProvider.notifier).addProjectors([
        {'ip': '10.0.0.1', 'name': 'A'},
      ]);
      await pumpEventQueue();
      expect(
        c.read(workspaceProvider).single.connectionStatus,
        ConnectionStatus.connected,
      );
      expect(logMessages(c), isNot(contains('Came online')));
    });

    test('an added projector that comes up later does log it', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.addProjectors([
        {'ip': '10.0.0.1', 'name': 'A'},
      ]);
      await pumpEventQueue();
      fake.reachable['10.0.0.1'] = true;
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      await ws.refreshAll();
      expect(logMessages(c).where((m) => m == 'Came online'), hasLength(1));
    });

    test('re-checking after an edit logs "Came online"', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      fake.reachable['10.0.0.9'] = true;
      fake.pollResults['10.0.0.9'] = (ProbeResult.online, telemetry());
      ws.updateNode('1', '10.0.0.9', 1024, 'admin1', 'panasonic');
      await pumpEventQueue();
      expect(logMessages(c).where((m) => m == 'Came online'), hasLength(1));
    });

    test(
      'a new error code is left to its alert, not logged by the poll',
      () async {
        final c = makeContainer(fake);
        final ws = c.read(workspaceProvider.notifier);
        fake.pollResults['10.0.0.1'] = (
          ProbeResult.online,
          telemetry(errors: 'ERRS2=000100000000'),
        );
        ws.setNodes([node('1')]);
        await ws.refreshAll();
        await ws.refreshAll();
        expect(logMessages(c), isEmpty);
      },
    );

    test('concurrent refreshes do not poll twice', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
      ws.setNodes([node('1')]);
      await Future.wait([ws.refreshAll(), ws.refreshAll()]);
      expect(fake.pollCount, 1);
    });
  });

  group('test pattern', () {
    test('polled from QTS and updated optimistically on OTS', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (
        ProbeResult.online,
        telemetry(testPattern: '70'),
      );
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      expect(c.read(workspaceProvider).single.testPattern, 'OTS:70');

      c.read(selectionProvider.notifier).set({'1'});
      await ws.sendCommandToSelected('OTS:00', source: _bar);
      expect(c.read(workspaceProvider).single.testPattern, 'OTS:00');
    });
  });
}
