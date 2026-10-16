import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/toolbar_counts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

ScheduledTask _task(String id, {bool enabled = true}) => ScheduledTask(
  id: id,
  name: 'Task $id',
  command: 'PON',
  commandLabel: 'Power on',
  target: ScheduleTarget.all,
  scheduleType: ScheduleType.daily,
  timeOfDay: '22:30',
  enabled: enabled,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  group('groupCountProvider', () {
    test('follows group edits, not polling ticks', () {
      final c = makeContainer(FakeProtocolService());
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1')]);

      var notifications = 0;
      c.listen(groupCountProvider, (_, _) => notifications++);
      expect(c.read(groupCountProvider), 0);

      ws.addGroup(
        const ProjectorGroup(id: 'g', name: 'Left', color: 0xFF4C8DF6),
      );
      expect(c.read(groupCountProvider), 1);
      expect(notifications, 1);

      // A telemetry-style change: the toolbar must not hear of it.
      ws.setNodes([
        node('1').copyWith(intakeTemp: '31°C', powerStatus: PowerStatus.on),
      ]);
      c.read(groupCountProvider);
      expect(notifications, 1);

      ws.deleteGroup('g');
      expect(c.read(groupCountProvider), 0);
      expect(notifications, 2);
    });
  });

  group('scheduledTasksSummaryProvider', () {
    test('counts enabled tasks and words the next run', () {
      final c = makeContainer(FakeProtocolService());
      c.listen(scheduledTasksSummaryProvider, (_, _) {});
      expect(c.read(scheduledTasksSummaryProvider), (active: 0, nextRun: null));

      c.read(scheduledTasksProvider.notifier).loadTasks([
        _task('a'),
        _task('b'),
        _task('c', enabled: false),
      ]);
      final s = c.read(scheduledTasksSummaryProvider);
      expect(s.active, 2);
      expect(s.nextRun, anyOf('at 22:30', 'tomorrow at 22:30'));
    });

    test('does not notify when a node changes', () {
      final c = makeContainer(FakeProtocolService());
      c.read(scheduledTasksProvider.notifier).loadTasks([_task('a')]);
      var notifications = 0;
      c.listen(scheduledTasksSummaryProvider, (_, _) => notifications++);
      c.read(workspaceProvider.notifier).setNodes([node('1'), node('2')]);
      c.read(scheduledTasksSummaryProvider);
      expect(notifications, 0);
    });
  });
}
