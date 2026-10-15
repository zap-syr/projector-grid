import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

ScheduledTask _task(String id, {String? groupId}) => ScheduledTask(
  id: id,
  name: 'Task $id',
  command: 'OSH:1',
  commandLabel: 'Shutter close',
  target: groupId == null ? ScheduleTarget.all : ScheduleTarget.group,
  targetGroupId: groupId,
  scheduleType: ScheduleType.daily,
  timeOfDay: '22:30',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  test('deleting a group pauses the tasks aimed at it', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    ws.addGroup(const ProjectorGroup(id: 'h', name: 'Right', color: 0));
    c.read(scheduledTasksProvider.notifier).loadTasks([
      _task('1', groupId: 'g'),
      _task('2', groupId: 'h'),
      _task('3'),
    ]);

    ws.deleteGroup('g');

    final tasks = c.read(scheduledTasksProvider);
    expect(tasks[0].targetGroupId, isNull);
    expect(tasks[0].enabled, isFalse);
    expect(tasks[1].targetGroupId, 'h');
    expect(tasks[1].enabled, isTrue);
    expect(tasks[2].enabled, isTrue);
  });

  test('a task left without a group cannot be switched back on', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    final tasks = c.read(scheduledTasksProvider.notifier);
    tasks.loadTasks([_task('1', groupId: 'g')]);
    ws.deleteGroup('g');

    tasks.toggleEnabled('1');

    expect(c.read(scheduledTasksProvider).single.enabled, isFalse);
  });

  test('redo of a group delete detaches a task re-aimed after the undo', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    final tasks = c.read(scheduledTasksProvider.notifier);
    tasks.loadTasks([_task('1', groupId: 'g')]);
    ws.deleteGroup('g');
    ws.undo();
    tasks.update(_task('1', groupId: 'g'));

    ws.redo();

    final task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupId, isNull);
    expect(task.enabled, isFalse);
  });

  test('a delete that touches no task leaves the task list as it was', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    c.read(scheduledTasksProvider.notifier).loadTasks([_task('1')]);
    final before = c.read(scheduledTasksProvider);

    ws.deleteGroup('g');

    expect(identical(c.read(scheduledTasksProvider), before), isTrue);
  });
}
