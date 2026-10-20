import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/status_bar_view.dart';

ProjectorNode _node(
  String ip, {
  String model = 'PT-RQ35K',
  String? group,
  ConnectionStatus status = ConnectionStatus.offline,
}) => ProjectorNode(
  id: ip,
  name: model,
  ipAddress: ip,
  x: 0,
  y: 0,
  connectionStatus: status,
  groupId: group,
);

const _stage = ProjectorGroup(id: 'stage', name: 'Stage', color: 0xFF4C8DF6);
const _main = ProjectorGroup(id: 'main', name: 'Main', color: 0xFF4C8DF6);

void main() {
  group('offlineTooltip', () {
    test('lists the offline ones in Monitoring order: group, then IP', () {
      final tip = offlineTooltip(
        [
          _node('10.0.1.50', model: 'PT-RZ570'),
          _node('10.0.1.13', group: 'main'),
          _node('10.0.1.10', group: 'stage'),
          _node('10.0.1.9', group: 'stage'),
          _node('10.0.1.11', group: 'main', status: ConnectionStatus.connected),
          _node('10.0.1.12', group: 'gone'),
        ],
        // The project's group order, not alphabetical.
        [_stage, _main],
      );
      expect(tip.title, '5 offline');
      expect(tip.rows.map((r) => r.ip), [
        '10.0.1.9',
        '10.0.1.10',
        '10.0.1.13',
        // Ungrouped last, with a node whose group is gone.
        '10.0.1.12',
        '10.0.1.50',
      ]);
      expect(tip.rows.last.model, 'PT-RZ570');
      expect(tip.more, isNull);
      expect(tip.note, isNull);
    });

    test('5 rows at most, then "and N more"', () {
      final tip = offlineTooltip([
        for (var i = 1; i <= 17; i++) _node('10.0.1.$i'),
        _node('10.0.2.1', status: ConnectionStatus.connected),
      ], const []);
      expect(tip.title, '17 offline');
      expect(tip.rows, hasLength(OfflineTooltip.maxRows));
      expect(tip.rows.map((r) => r.ip).first, '10.0.1.1');
      expect(tip.rows.map((r) => r.ip).last, '10.0.1.5');
      expect(tip.more, 'and 12 more');
    });

    test('every projector offline: no list, check the network', () {
      final tip = offlineTooltip([
        for (var i = 1; i <= 18; i++) _node('10.0.1.$i'),
      ], const []);
      expect(tip.title, 'All 18 offline');
      expect(tip.rows, isEmpty);
      expect(tip.more, isNull);
      expect(tip.note, 'Check the network connection');
    });

    test('a wrong login is not offline', () {
      final tip = offlineTooltip([
        _node('10.0.1.1'),
        _node('10.0.1.2', status: ConnectionStatus.unauthorized),
      ], const []);
      expect(tip.title, '1 offline');
      expect(tip.rows.single.ip, '10.0.1.1');
    });

    test('value equality', () {
      List<ProjectorNode> nodes() => [_node('10.0.1.1'), _node('10.0.1.2')];
      expect(
        offlineTooltip(nodes(), const []),
        offlineTooltip(nodes(), const []),
      );
    });
  });

  group('statusBarNarrow', () {
    test('full while the current values fit with the gap', () {
      expect(statusBarNarrow(1238, fullWidth: 920), isFalse);
      expect(statusBarNarrow(936, fullWidth: 920), isFalse);
      expect(statusBarNarrow(935, fullWidth: 920), isTrue);
      expect(statusBarNarrow(1210, fullWidth: 1203), isTrue);
      expect(statusBarNarrow(1238, fullWidth: 1203), isFalse);
    });

    test('a narrow bar waits for the hysteresis before it is full again', () {
      const full = 920.0;
      final edge = full + statusBarGap;
      expect(statusBarNarrow(edge + 10, fullWidth: full), isFalse);
      expect(
        statusBarNarrow(edge + 10, fullWidth: full, wasNarrow: true),
        isTrue,
      );
      expect(
        statusBarNarrow(
          edge + statusBarHysteresis,
          fullWidth: full,
          wasNarrow: true,
        ),
        isFalse,
      );
    });
  });
}
