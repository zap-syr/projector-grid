import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/command_source.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

ScheduledTask _task(String id, {List<String> groupIds = const []}) =>
    ScheduledTask(
      id: id,
      name: 'Task $id',
      command: 'OSH:1',
      commandLabel: 'Shutter close',
      target: groupIds.isEmpty ? ScheduleTarget.all : ScheduleTarget.group,
      targetGroupIds: groupIds,
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
      _task('1', groupIds: ['g']),
      _task('2', groupIds: ['h']),
      _task('3'),
    ]);

    ws.deleteGroup('g');

    final tasks = c.read(scheduledTasksProvider);
    expect(tasks[0].targetGroupIds, isEmpty);
    expect(tasks[0].enabled, isFalse);
    expect(tasks[1].targetGroupIds, ['h']);
    expect(tasks[1].enabled, isTrue);
    expect(tasks[2].enabled, isTrue);
  });

  test('a task that keeps another group only loses the deleted one', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    ws.addGroup(const ProjectorGroup(id: 'h', name: 'Right', color: 0));
    c.read(scheduledTasksProvider.notifier).loadTasks([
      _task('1', groupIds: ['g', 'h']),
    ]);

    ws.deleteGroup('g');
    var task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupIds, ['h']);
    expect(task.enabled, isTrue);

    ws.deleteGroup('h');
    task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupIds, isEmpty);
    expect(task.enabled, isFalse);
  });

  test('a task left without a group cannot be switched back on', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    final tasks = c.read(scheduledTasksProvider.notifier);
    tasks.loadTasks([
      _task('1', groupIds: ['g']),
    ]);
    ws.deleteGroup('g');

    tasks.toggleEnabled('1');

    expect(c.read(scheduledTasksProvider).single.enabled, isFalse);
  });

  test('redo of a group delete detaches a task re-aimed after the undo', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    final tasks = c.read(scheduledTasksProvider.notifier);
    tasks.loadTasks([
      _task('1', groupIds: ['g']),
    ]);
    ws.deleteGroup('g');
    ws.undo();
    tasks.update(_task('1', groupIds: ['g']));

    ws.redo();

    final task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupIds, isEmpty);
    expect(task.enabled, isFalse);
  });

  test('undoing a group delete re-aims and resumes its tasks', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    ws.addGroup(const ProjectorGroup(id: 'h', name: 'Right', color: 0));
    c.read(scheduledTasksProvider.notifier).loadTasks([
      _task('1', groupIds: ['g']),
      _task('2', groupIds: ['h', 'g']),
    ]);

    ws.deleteGroup('g');
    ws.undo();

    final tasks = c.read(scheduledTasksProvider);
    expect(tasks[0].targetGroupIds, ['g']);
    expect(tasks[0].enabled, isTrue);
    expect(tasks[1].targetGroupIds, ['h', 'g']);
  });

  test('stepping back past a group and forward again keeps its tasks', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.setNodes([node('1')]);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    c.read(scheduledTasksProvider.notifier).add(_task('1', groupIds: ['g']));
    drag(c, '1', const Offset(20, 0));

    ws.undo();
    ws.undo();
    expect(c.read(scheduledTasksProvider).single.enabled, isFalse);
    ws.redo();
    ws.redo();

    final task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupIds, ['g']);
    expect(task.enabled, isTrue);
  });

  test('a task switched off by hand after the delete stays off', () {
    final c = makeContainer(FakeProtocolService());
    final ws = c.read(workspaceProvider.notifier);
    ws.addGroup(const ProjectorGroup(id: 'g', name: 'Left', color: 0));
    ws.addGroup(const ProjectorGroup(id: 'h', name: 'Right', color: 0));
    final tasks = c.read(scheduledTasksProvider.notifier);
    tasks.loadTasks([
      _task('1', groupIds: ['g']),
    ]);
    ws.deleteGroup('g');
    tasks.update(_task('1', groupIds: ['h']).copyWith(enabled: false));

    ws.undo();

    final task = c.read(scheduledTasksProvider).single;
    expect(task.targetGroupIds, ['h', 'g']);
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

  test(
    'a task aimed at several groups sends to all their projectors',
    () async {
      final fake = FakeProtocolService();
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setGroups(const [
        ProjectorGroup(id: 'g', name: 'Left', color: 0),
        ProjectorGroup(id: 'h', name: 'Right', color: 0),
        ProjectorGroup(id: 'k', name: 'Back', color: 0),
      ]);
      ws.setNodes([
        node('1', groupId: 'g'),
        node('2', groupId: 'h'),
        node('3', groupId: 'k'),
      ]);

      await ws.sendCommandToGroups(
        {'g', 'h'},
        'OSH:1',
        source: const CommandSource.schedule('Evening'),
      );

      expect(fake.sentCommands.map((s) => s.$1).toSet(), {
        '10.0.0.1',
        '10.0.0.2',
      });
    },
  );
}
