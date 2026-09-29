import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/panasonic_protocol_service.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/presentation/providers/project_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/scheduled_tasks_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _projectV2 = {
  'version': 2,
  'groups': [
    {
      'id': 'g1',
      'name': 'Stage',
      'color': 4283215696,
      'oscAddress': '/group/stage',
    },
  ],
  'nodes': [
    {
      'id': 'n1',
      'name': 'Left',
      'ipAddress': '10.0.0.1',
      'port': 1024,
      'login': 'admin1',
      'password': 'panasonic',
      'x': 40.0,
      'y': 40.0,
      'groupId': 'g1',
    },
    {
      'id': 'n2',
      'name': 'Right',
      'ipAddress': '10.0.0.2',
      'port': 2048,
      'login': '',
      'password': '',
      'x': 180.0,
      'y': 60.0,
    },
  ],
  'scheduledTasks': [
    {
      'id': 't1',
      'name': 'Doors',
      'command': 'PON',
      'commandLabel': 'Power On',
      'target': 'group',
      'targetGroupId': 'g1',
      'scheduleType': 'weekly',
      'timeOfDay': '18:30',
      'weekdays': [1, 3, 5],
      'enabled': true,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  late FakeProtocolService fake;
  late ProviderContainer c;

  setUp(() {
    fake = FakeProtocolService();
    c = makeContainer(fake);
    c.listen(projectStateProvider, (_, _) {});
  });

  File writeProject(String name, Object json) {
    final f = File('${configDir().path}${Platform.pathSeparator}$name');
    f.writeAsStringSync(jsonEncode(json));
    return f;
  }

  ProjectStateNotifier project() => c.read(projectStateProvider.notifier);

  test('open loads nodes, groups and tasks (v2)', () async {
    await project().openProject(writeProject('a.pgrid', _projectV2).path);

    final nodes = c.read(workspaceProvider);
    expect(nodes.map((n) => n.id), ['n1', 'n2']);
    expect(nodes.first.groupId, 'g1');
    expect(nodes.last.port, 2048);
    // Telemetry isn't persisted — nodes start offline until polled.
    expect(nodes.first.connectionStatus, ConnectionStatus.offline);

    final groups = c.read(workspaceProvider.notifier).groups;
    expect(groups.single.oscAddress, '/group/stage');

    final task = c.read(scheduledTasksProvider).single;
    expect(task.scheduleType, ScheduleType.weekly);
    expect(task.weekdays, [1, 3, 5]);
    expect(task.target, ScheduleTarget.group);

    final state = c.read(projectStateProvider);
    expect(state.isDirty, isFalse);
    expect(state.currentFilePath, endsWith('a.pgrid'));
  });

  test('save → load round-trips the file unchanged', () async {
    final file = writeProject('a.pgrid', _projectV2);
    await project().openProject(file.path);
    expect(await project().saveProject(), isTrue);

    expect(jsonDecode(file.readAsStringSync()), _projectV2);
  });

  test('live telemetry is never written to the project file', () async {
    final file = writeProject('a.pgrid', _projectV2);
    fake.reachable['10.0.0.1'] = true;
    fake.pollResults['10.0.0.1'] = (ProbeResult.online, telemetry());
    await project().openProject(file.path);
    await pumpEventQueue(); // openProject's own refresh
    expect(c.read(workspaceProvider).first.powerStatus, PowerStatus.on);
    await project().saveProject();

    final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final node = (saved['nodes'] as List).first as Map<String, dynamic>;
    expect(node.keys, isNot(contains('connectionStatus')));
    expect(node.keys, isNot(contains('intakeTemp')));
  });

  test('dirty flag: set by edits, not by telemetry, cleared by save', () async {
    bool dirty() => c.read(projectStateProvider).isDirty;
    // Polling replaces a node's name with its QID model name, which *is* a
    // persisted field — match it so only the telemetry changes here.
    fake.reachable['10.0.0.1'] = true;
    fake.pollResults['10.0.0.1'] = (
      ProbeResult.online,
      telemetry(modelName: 'Left'),
    );
    await project().openProject(writeProject('a.pgrid', _projectV2).path);
    await pumpEventQueue(); // openProject's own refresh
    expect(c.read(workspaceProvider).first.powerStatus, PowerStatus.on);
    expect(dirty(), isFalse, reason: 'telemetry alone is not an edit');

    drag(c, 'n1', const Offset(20, 0));
    expect(dirty(), isTrue);

    await project().saveProject();
    expect(dirty(), isFalse);

    c.read(scheduledTasksProvider.notifier).toggleEnabled('t1');
    expect(dirty(), isTrue, reason: 'task edits count too');
  });

  test('newProject clears everything and is clean', () async {
    await project().openProject(writeProject('a.pgrid', _projectV2).path);
    drag(c, 'n1', const Offset(20, 0));
    project().newProject();
    expect(c.read(workspaceProvider), isEmpty);
    expect(c.read(workspaceProvider.notifier).groups, isEmpty);
    expect(c.read(scheduledTasksProvider), isEmpty);
    expect(c.read(projectStateProvider).isDirty, isFalse);
    expect(c.read(projectStateProvider).currentFilePath, isNull);
  });

  test('recent projects: newest first, deduplicated, capped at 10', () async {
    final paths = [
      for (var i = 0; i < 12; i++) writeProject('p$i.pgrid', _projectV2).path,
    ];
    for (final p in paths) {
      await project().openProject(p);
    }
    await project().openProject(paths[5]);

    final recent = c.read(projectStateProvider).recentProjects;
    expect(recent, hasLength(10));
    expect(recent.first, paths[5]);
    expect(recent.where((p) => p == paths[5]), hasLength(1));
    expect(recent, isNot(contains(paths[0])));
  });

  test('recent projects persist and skip files that no longer exist', () async {
    final keep = writeProject('keep.pgrid', _projectV2);
    final gone = writeProject('gone.pgrid', _projectV2);
    await project().openProject(gone.path);
    await project().openProject(keep.path);
    gone.deleteSync();

    final fresh = makeContainer(FakeProtocolService());
    expect(fresh.read(projectStateProvider).recentProjects, [keep.path]);
  });

  test('opening a missing file drops it from recent', () async {
    final f = writeProject('a.pgrid', _projectV2);
    await project().openProject(f.path);
    f.deleteSync();
    await project().openProject(f.path);
    expect(c.read(projectStateProvider).recentProjects, isEmpty);
  });

  test(
    'a corrupt file is logged, not thrown, and leaves state alone',
    () async {
      await project().openProject(writeProject('a.pgrid', _projectV2).path);
      final bad = File('${configDir().path}${Platform.pathSeparator}bad.pgrid')
        ..writeAsStringSync('{not json');
      await project().openProject(bad.path);
      expect(c.read(workspaceProvider), hasLength(2));
      expect(c.read(projectStateProvider).currentFilePath, endsWith('a.pgrid'));
    },
  );

  test('more than 500 nodes is rejected', () async {
    final big = Map<String, dynamic>.of(_projectV2)
      ..['nodes'] = [
        for (var i = 0; i < 501; i++)
          {...(_projectV2['nodes'] as List).first as Map, 'id': 'n$i'},
      ];
    await project().openProject(writeProject('big.pgrid', big).path);
    expect(c.read(workspaceProvider), isEmpty);
  });
}
