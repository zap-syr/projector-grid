import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task.dart';
import 'package:projector_grid/features/workspace/domain/scheduled_task_json.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'id': 't1',
  'name': 'Shutter close, 22:30',
  'command': 'OSH:1',
  'commandLabel': 'Shutter close',
  'target': 'group',
  'scheduleType': 'daily',
  'timeOfDay': '22:30',
  'enabled': true,
  ...extra,
};

void main() {
  group('targetGroupId to targetGroupIds', () {
    test('an old file with one targetGroupId reads as a one-item list', () {
      final task = scheduledTaskFromJson(_json({'targetGroupId': 'g1'}));
      expect(task.targetGroupIds, ['g1']);
    });

    test('targetGroupIds wins over the old field', () {
      final task = scheduledTaskFromJson(
        _json({
          'targetGroupId': 'g1',
          'targetGroupIds': ['g1', 'g2'],
        }),
      );
      expect(task.targetGroupIds, ['g1', 'g2']);
    });

    test('neither field: no groups', () {
      expect(scheduledTaskFromJson(_json()).targetGroupIds, isEmpty);
    });

    test('writes the list and the first id for older apps', () {
      final json = scheduledTaskToJson(
        scheduledTaskFromJson(
          _json({
            'targetGroupIds': ['g2', 'g1'],
          }),
        ),
      );
      expect(json['targetGroupIds'], ['g2', 'g1']);
      expect(json['targetGroupId'], 'g2');
    });

    test('an all-projectors task writes neither', () {
      final json = scheduledTaskToJson(
        scheduledTaskFromJson(_json({'target': 'all'})),
      );
      expect(json.containsKey('targetGroupIds'), isFalse);
      expect(json.containsKey('targetGroupId'), isFalse);
    });
  });

  test('round-trips every field', () {
    final task = ScheduledTask(
      id: 't2',
      name: 'Power on, 18:00',
      command: 'PON',
      commandLabel: 'Power on',
      target: ScheduleTarget.group,
      targetGroupIds: const ['a', 'b'],
      scheduleType: ScheduleType.once,
      oneTimeAt: DateTime(2026, 10, 18, 18),
      enabled: false,
      lastRunAt: DateTime(2026, 10, 18, 18, 0, 3),
    );
    expect(scheduledTaskFromJson(scheduledTaskToJson(task)), task);
  });
}
