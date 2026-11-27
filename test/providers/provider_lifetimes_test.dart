import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/command_source.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/custom_commands_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/osc_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/poll_status_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/project_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/signal_watch_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/web_server_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart' show node;
import '../helpers/test_config_dir.dart';

/// Not [makeContainer]: no listeners and no teardown dispose, since these
/// tests are about what happens when nothing watches and when the container
/// goes away under a pending call.
ProviderContainer _container(FakeProtocolService fake) => ProviderContainer(
  overrides: [protocolServiceProvider.overrideWithValue(fake)],
);

/// Runs [body] and returns every error it leaked: an exception it threw, or an
/// async error nobody caught (a notifier's fire-and-forget future). Disposed
/// refs throw in Riverpod 3 on any `state` write or `ref` call, so a pending
/// call that finishes after disposal shows up here unless it checks
/// `ref.mounted`.
Future<List<Object>> _leakedErrors(Future<void> Function() body) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    try {
      await body();
    } catch (e, stack) {
      errors.add('$e\n$stack');
    }
    await pumpEventQueue();
  }, (e, stack) => errors.add('$e\n$stack'));
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  group('app-lifetime providers keep their state with no listener', () {
    late FakeProtocolService fake;
    late ProviderContainer c;
    setUp(() {
      fake = FakeProtocolService();
      c = _container(fake);
      addTearDown(c.dispose);
    });

    // Riverpod disposes an unlistened auto-dispose provider once the
    // container processes its pending disposals.
    Future<void> letDisposalsRun() async {
      await c.pump();
      await pumpEventQueue();
    }

    test('workspace: nodes, groups and the undo stack', () async {
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2')]);
      ws.addGroup(const ProjectorGroup(id: 'g1', name: 'Stage', color: 1));
      expect(ws.canUndo, isTrue);

      await letDisposalsRun();

      expect(c.read(workspaceProvider), hasLength(2));
      final again = c.read(workspaceProvider.notifier);
      expect(again, same(ws));
      expect(again.canUndo, isTrue);
      expect(again.groups.single.id, 'g1');
    });

    test('project state: the open file', () async {
      final file = File('${configDir().path}/a.pgrid')
        ..writeAsStringSync(
          jsonEncode({
            'version': 2,
            'groups': [],
            'nodes': [],
            'scheduledTasks': [],
          }),
        );
      await c.read(projectStateProvider.notifier).openProject(file.path);
      await pumpEventQueue();
      expect(c.read(projectStateProvider).currentFilePath, file.path);

      await letDisposalsRun();

      expect(c.read(projectStateProvider).currentFilePath, file.path);
    });

    test('app settings: a changed setting', () async {
      c.read(appSettingsProvider.notifier).setPollingInterval(45);

      await letDisposalsRun();

      expect(c.read(appSettingsProvider).pollingIntervalSeconds, 45);
    });

    test('selection: the selected ids', () async {
      c.read(selectionProvider.notifier).selectOnly('a');

      await letDisposalsRun();

      expect(c.read(selectionProvider), {'a'});
    });

    test('poll status: a cycle in flight', () async {
      c.read(pollStatusProvider.notifier).started();

      await letDisposalsRun();

      expect(c.read(pollStatusProvider).isPolling, isTrue);
    });

    test('custom commands: the list', () async {
      expect(
        c.read(customCommandsProvider.notifier).add('Lights', 'VXX:A'),
        isTrue,
      );

      await letDisposalsRun();

      expect(c.read(customCommandsProvider).single.name, 'Lights');
    });
  });

  group('a call that finishes after its container was disposed', () {
    test('workspace: a poll answer is dropped', () async {
      final fake = FakeProtocolService()
        ..pollResults['10.0.0.1'] = (ProbeResult.online, telemetry())
        ..holdPolls['10.0.0.1'] = Completer<void>();
      final errors = await _leakedErrors(() async {
        final c = _container(fake);
        final ws = c.read(workspaceProvider.notifier);
        ws.setNodes([node('1')]);
        final refreshing = ws.refreshAll();
        await pumpEventQueue();
        expect(fake.pollCount, 1);

        c.dispose();
        fake.holdPolls['10.0.0.1']!.complete();
        await refreshing;
      });
      expect(errors, isEmpty);
    });

    test('workspace: a command reply is neither logged nor applied', () async {
      final fake = FakeProtocolService()
        ..holdCommands['10.0.0.1'] = Completer<void>();
      final errors = await _leakedErrors(() async {
        final c = _container(fake);
        final ws = c.read(workspaceProvider.notifier);
        ws.setNodes([node('1'), node('2')]);
        final sending = ws.sendCommandToAll(
          'PON',
          source: CommandSource.controlBar,
        );
        await pumpEventQueue();
        expect(fake.sentCommands, isNotEmpty);

        c.dispose();
        fake.holdCommands['10.0.0.1']!.complete();
        // The batch still ends and reports, just without logging.
        expect((await sending).command, 'PON');
      });
      expect(errors, isEmpty);
    });

    test('project: opening a file', () async {
      final file = File('${configDir().path}/b.pgrid')
        ..writeAsStringSync(
          jsonEncode({
            'version': 2,
            'groups': [],
            'nodes': [],
            'scheduledTasks': [],
          }),
        );
      final errors = await _leakedErrors(() async {
        final c = _container(FakeProtocolService());
        final project = c.read(projectStateProvider.notifier);
        final opening = project.openProject(file.path);
        c.dispose();
        await opening;
      });
      expect(errors, isEmpty);
    });

    test('project: a save that completes still reports success', () async {
      final file = File('${configDir().path}/c.pgrid')
        ..writeAsStringSync(
          jsonEncode({
            'version': 2,
            'groups': [],
            'nodes': [],
            'scheduledTasks': [],
          }),
        );
      bool? saved;
      final errors = await _leakedErrors(() async {
        final c = _container(FakeProtocolService());
        final project = c.read(projectStateProvider.notifier);
        await project.openProject(file.path);
        await pumpEventQueue();
        file.deleteSync();

        final saving = project.saveProject();
        c.dispose();
        saved = await saving;
      });
      expect(errors, isEmpty);
      // On the file system it did succeed: the project is on disk.
      expect(saved, isTrue);
      expect(file.existsSync(), isTrue);
    });

    test('alignment: entering the mode', () async {
      final fake = FakeProtocolService()
        ..rawResponses.addAll({
          'QSH': '0',
          'QTS': '00',
          'QVX:SEFS1': 'SEFS1=0.0',
          'QVX:SEFS2': 'SEFS2=0.0',
        })
        ..holdRaw['10.0.0.1'] = Completer<void>();
      final errors = await _leakedErrors(() async {
        final c = _container(fake);
        c.read(workspaceProvider.notifier).setNodes([node('1')]);
        final entering = c.read(alignmentProvider.notifier).enter();
        await pumpEventQueue();
        expect(fake.sentRaw, isNotEmpty);

        c.dispose();
        fake.holdRaw['10.0.0.1']!.complete();
        await entering;
      });
      expect(errors, isEmpty);
    });

    test('alignment: a command of the sync loop', () async {
      final fake = FakeProtocolService()
        ..rawResponses.addAll({
          'QSH': '0',
          'QTS': '00',
          'QVX:SEFS1': 'SEFS1=0.0',
          'QVX:SEFS2': 'SEFS2=0.0',
        });
      final errors = await _leakedErrors(() async {
        final c = _container(fake);
        c.read(workspaceProvider.notifier).setNodes([
          node('1', x: 40),
          node('2', x: 180),
        ]);
        final alignment = c.read(alignmentProvider.notifier);
        await alignment.enter();
        await pumpEventQueue();

        // Stepping on opens projector 2: its command is held, then the
        // container goes away.
        fake.holdCommands['10.0.0.2'] = Completer<void>();
        final before = fake.sentCommands.length;
        alignment.next();
        await pumpEventQueue();
        expect(fake.sentCommands.length, greaterThan(before));

        c.dispose();
        fake.holdCommands['10.0.0.2']!.complete();
      });
      expect(errors, isEmpty);
    });

    test('osc: stop and restart', () async {
      final errors = await _leakedErrors(() async {
        final c = _container(FakeProtocolService());
        final osc = c.read(oscProvider.notifier);
        final stopping = osc.stop();
        final restarting = osc.restart();
        c.dispose();
        await stopping;
        await restarting;
      });
      expect(errors, isEmpty);
    });

    test('web server: stop, restart and start', () async {
      final errors = await _leakedErrors(() async {
        final c = _container(FakeProtocolService());
        c.read(appSettingsProvider.notifier).setWebPort(0);
        final web = c.read(webServerProvider.notifier);
        final stopping = web.stop();
        final restarting = web.restart();
        final starting = web.start();
        c.dispose();
        await stopping;
        await restarting;
        await starting;
      });
      expect(errors, isEmpty);
    });

    test('signal watch: a query answered late', () {
      final fake = FakeProtocolService()
        ..rawResponses['QVX:NSGS1'] = 'NSGS1=1080/60p'
        ..holdQueries['10.0.0.1'] = Completer<void>();
      fakeAsync((async) {
        final c = _container(fake);
        c.read(signalWatchProvider);
        c.read(workspaceProvider.notifier).setNodes([
          node('1').copyWith(powerStatus: PowerStatus.on),
        ]);
        async.flushMicrotasks();
        async.elapse(SignalWatchNotifier.period);
        expect(fake.sentQuick, isNotEmpty);

        c.dispose();
        fake.holdQueries['10.0.0.1']!.complete();
        // fake_async rethrows an error nobody caught.
        async.flushMicrotasks();
      });
    });
  });
}
