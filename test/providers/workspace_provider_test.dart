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

      await ws.sendCommandToSelected('OSH:0');
      expect(c.read(workspaceProvider).map((n) => n.shutterStatus), [
        ShutterStatus.open,
        ShutterStatus.closed,
      ]);
      await ws.sendCommandToSelected('OSH:1');
      expect(
        c.read(workspaceProvider).first.shutterStatus,
        ShutterStatus.closed,
      );
      expect(logMessages(c).first, 'Sent: Shutter Close');
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
      await ws.sendCommandToAll('OSH:0');
      expect(
        c.read(workspaceProvider).single.shutterStatus,
        ShutterStatus.closed,
      );
      expect(logMessages(c).single, 'Failed: Shutter Open');
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
      await c.read(workspaceProvider.notifier).sendCommandToAll('OOS:1');
      expect(fake.sentCommands.map((s) => s.$1), ['10.0.0.1', '10.0.0.4']);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('multi-projector commands log a summary line', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.commandSucceeds['10.0.0.2'] = false;
      ws.setNodes([
        node('1'),
        node('2'),
        node('3', status: ConnectionStatus.offline),
      ]);
      final result = await ws.sendCommandToAll('OOS:1');
      expect(result.ok, 1);
      expect(result.failed.map((n) => n.id), ['2']);
      expect(result.skipped.map((n) => n.id), ['3']);

      final summary = c.read(eventLogProvider).first;
      expect(summary.severity, LogSeverity.warning);
      expect(summary.projectorIp, isNull);
      expect(
        summary.message,
        'OSD On — 1/3 OK · 1 failed · 1 skipped. '
        'Failed: Proj 2. Skipped: Proj 3',
      );
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('single-projector commands log no summary', (tester) async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2')]);
      c.read(selectionProvider.notifier).set({'1'});
      await ws.sendCommandToSelected('OOS:1');
      expect(logMessages(c), ['Sent: OSD On']);
      // Cancels the poll/power-transition timers before the pending-timer check.
      c.dispose();
    });

    testWidgets('group commands only reach that group', (tester) async {
      final c = makeContainer(fake);
      c.read(workspaceProvider.notifier).setNodes([
        node('1', groupId: 'g'),
        node('2'),
      ]);
      await c.read(workspaceProvider.notifier).sendCommandToGroup('g', 'POF');
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
      await ws.sendCommandToNodes(['1', '3'], 'OOS:1', source: 'Web · x');
      expect(fake.sentCommands, [('10.0.0.1', 'OOS:1'), ('10.0.0.3', 'OOS:1')]);
      expect(logMessages(c), [
        'OSD On — 2/2 OK (Web · x)',
        'Sent: OSD On (Web · x)',
        'Sent: OSD On (Web · x)',
      ]);
      // Cancels the poll/power-transition timers before the pending-timer check.
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

      await ws.sendCommandToAll('PON');
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

      await ws.sendCommandToAll('PON');
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
      await ws.sendCommandToAll('POF');
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
    });

    test('a loaded offline node counts as polled only after a check', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1', status: ConnectionStatus.offline)]);
      expect(c.read(workspaceProvider).single.polled, isFalse);
      await ws.refreshAll();
      expect(c.read(workspaceProvider).single.polled, isTrue);

      ws.updateNode('1', '10.0.0.9', 'admin1', 'panasonic');
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
      ws.updateNode('1', '10.0.0.9', 'admin1', 'panasonic');
      await pumpEventQueue();
      expect(logMessages(c).where((m) => m == 'Came online'), hasLength(1));
    });

    test('a new hardware error is logged once', () async {
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      fake.pollResults['10.0.0.1'] = (
        ProbeResult.online,
        telemetry(errors: 'ERRS2=000100000000'),
      );
      ws.setNodes([node('1')]);
      await ws.refreshAll();
      await ws.refreshAll();
      expect(logMessages(c), ['Hardware error: 000100000000']);
    });

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
      await ws.sendCommandToSelected('OTS:00');
      expect(c.read(workspaceProvider).single.testPattern, 'OTS:00');
    });
  });
}
