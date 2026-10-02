import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/custom_commands_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/status_summary_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  group('statusSummaryProvider', () {
    test('counts online and offline', () {
      final c = makeContainer(FakeProtocolService());
      c.read(workspaceProvider.notifier).setNodes([
        node('1'),
        node('2', status: ConnectionStatus.unprotected),
        node('3', status: ConnectionStatus.offline),
        node('4', status: ConnectionStatus.unauthorized),
        node('5').copyWith(errors: 'U200'),
      ]);
      expect(c.read(statusSummaryProvider), (total: 5, online: 3, offline: 1));
    });

    test('does not notify when the counts are unchanged', () {
      final c = makeContainer(FakeProtocolService());
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2', status: ConnectionStatus.offline)]);

      var notifications = 0;
      c.listen(statusSummaryProvider, (_, _) => notifications++);

      // A telemetry-style change that leaves every count the same.
      ws.setNodes([
        node('1').copyWith(intakeTemp: '31°C', powerStatus: PowerStatus.on),
        node('2', status: ConnectionStatus.offline),
      ]);
      c.read(statusSummaryProvider);
      expect(notifications, 0);

      ws.setNodes([node('1'), node('2')]);
      c.read(statusSummaryProvider);
      expect(notifications, 1);
    });
  });

  group('eventLogProvider', () {
    LogEvent event(int i) => LogEvent(
      severity: LogSeverity.info,
      type: LogEventType.command,
      message: 'e$i',
    );

    test('newest first, capped at 500', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final log = c.read(eventLogProvider.notifier);
      for (var i = 0; i < 510; i++) {
        log.log(event(i));
      }
      final events = c.read(eventLogProvider);
      expect(events, hasLength(500));
      expect(events.first.message, 'e509');
      expect(events.last.message, 'e10');
    });

    test('clear empties it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(eventLogProvider.notifier)
        ..log(event(1))
        ..clear();
      expect(c.read(eventLogProvider), isEmpty);
    });
  });

  group('customCommandsProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(customCommandsProvider, (_, _) {});
      return c;
    }

    test('rejects a name whose slug is already taken', () {
      final c = container();
      final cmds = c.read(customCommandsProvider.notifier);
      expect(cmds.add('Dynamic Contrast', 'VXX:DCNI0=+00001'), isTrue);
      expect(cmds.add('dynamic contrast!', 'OSH:1'), isFalse);
      expect(cmds.add('Dynamic-Contrast', 'OSH:1'), isFalse);
      expect(cmds.add('Dynamic Contrast 2', 'OSH:1'), isTrue);
      expect(c.read(customCommandsProvider), hasLength(2));
    });

    test('update may keep its own slug but not take another', () {
      final c = container();
      final cmds = c.read(customCommandsProvider.notifier);
      cmds.add('Alpha', 'A');
      // Ids are microsecondsSinceEpoch; Windows' clock is coarse enough that
      // back-to-back adds would otherwise share one.
      sleep(const Duration(milliseconds: 5));
      cmds.add('Beta', 'B');
      final alpha = c.read(customCommandsProvider).first;
      expect(cmds.update(alpha.id, 'ALPHA', 'A2'), isTrue);
      expect(cmds.update(alpha.id, 'beta', 'A3'), isFalse);
      expect(c.read(customCommandsProvider).first.command, 'A2');
    });

    test('resolveBySlug', () {
      final c = container();
      final cmds = c.read(customCommandsProvider.notifier);
      cmds.add('House Lights', 'OSH:1');
      expect(cmds.resolveBySlug('house-lights'), 'OSH:1');
      expect(cmds.resolveBySlug('nope'), isNull);
    });

    test('persists and reloads; a malformed entry is dropped alone', () {
      final c = container();
      c.read(customCommandsProvider.notifier)
        ..add('One', '1')
        ..add('Two', '2');

      final file = File(
        '${configDir().path}${Platform.pathSeparator}custom_commands.json',
      );
      final text = file.readAsStringSync();
      file.writeAsStringSync(text.replaceFirst(']', ',{"id":1}]'));

      final reloaded = container();
      expect(reloaded.read(customCommandsProvider).map((c) => c.name), [
        'One',
        'Two',
      ]);
    });
  });
}
