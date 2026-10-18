import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/status_thresholds.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_format.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_layout.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_status.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_table_columns.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_view_settings.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';

ProjectorNode _n(
  String id, {
  String? group,
  ConnectionStatus status = ConnectionStatus.connected,
  bool polled = true,
  String runtime = '-',
  String errors = 'NO ERRORS',
  PowerStatus power = PowerStatus.on,
  DateTime? lastSeen,
}) => ProjectorNode(
  id: id,
  name: 'RZ34K',
  ipAddress: '10.0.0.$id',
  x: 0,
  y: 0,
  groupId: group,
  connectionStatus: status,
  polled: polled,
  runtime: runtime,
  errors: errors,
  powerStatus: power,
  lastSeen: lastSeen,
);

const _stage = ProjectorGroup(id: 'g1', name: 'Main stage', color: 0xFF3B82F6);
const _left = ProjectorGroup(id: 'g2', name: 'Left wall', color: 0xFFF97316);

void main() {
  group('table columns', () {
    test('empty or unknown saved lists give the nine default columns', () {
      expect(resolveMonitoringTableColumns(const []), [
        ...kMonitoringTableDefaultColumns,
      ]);
      expect(resolveMonitoringTableColumns(['nope']), [
        ...kMonitoringTableDefaultColumns,
      ]);
      expect(resolveMonitoringTableColumns(['serial', 'nope']), ['serial']);
    });

    test('a shown column goes back to its canonical place', () {
      expect(toggleMonitoringTableColumn(['projector', 'errors'], 'power'), [
        'projector',
        'power',
        'errors',
      ]);
      expect(toggleMonitoringTableColumn(['projector', 'errors'], 'errors'), [
        'projector',
      ]);
      expect(toggleMonitoringTableColumn(['projector'], 'projector'), isNull);
    });

    test('reorder lands after the target rightwards, before it leftwards', () {
      const ids = ['a', 'b', 'c'];
      expect(reorderMonitoringTableColumn(ids, 'a', 'b'), ['b', 'a', 'c']);
      expect(reorderMonitoringTableColumn(ids, 'c', 'a'), ['c', 'a', 'b']);
      expect(reorderMonitoringTableColumn(ids, 'x', 'a'), ids);
    });
  });

  group('layout', () {
    final nodes = [
      _n('3', group: 'g2'),
      _n('1'),
      _n('2', group: 'g1'),
      _n('4', group: 'gone'),
    ];

    test('grouped: project group order, then Ungrouped with orphans', () {
      final layout = monitoringLayout(
        nodes,
        [_stage, _left],
        columnId: 'projector',
        ascending: true,
        byGroup: true,
      );
      expect(
        [for (final s in layout.sections) s.group?.name],
        ['Main stage', 'Left wall', null],
      );
      expect(layout.sections.last.nodeIds, ['1', '4']);
      expect(layout.sections.last.key, kUngroupedSectionKey);
    });

    test('Group by none: one flat section in sort order', () {
      final layout = monitoringLayout(
        nodes,
        [_stage, _left],
        columnId: 'projector',
        ascending: false,
        byGroup: false,
      );
      expect(layout.sections, hasLength(1));
      expect(layout.sections.single.flat, isTrue);
      expect(layout.sections.single.nodeIds, ['4', '3', '2', '1']);
    });

    test('runtimes sort by the number with thousands separators', () {
      final sorted = sortMonitoringNodes(
        [_n('1', runtime: '1,644H'), _n('2', runtime: '999H')],
        'runtimes',
        true,
        const {},
      );
      expect([for (final n in sorted) n.id], ['2', '1']);
    });

    test('equal layouts compare equal, so a poll rebuilds nothing', () {
      MonitoringLayout build() => monitoringLayout(
        nodes,
        [_stage],
        columnId: 'projector',
        ascending: true,
        byGroup: true,
      );
      expect(build(), build());
    });
  });

  group('status', () {
    const settings = AlertSettings();

    test('offline after a poll: Offline alone; not polled yet: nothing', () {
      final off = monitoringStatusOf(
        _n('1', status: ConnectionStatus.offline, errors: 'F305'),
        const [],
        settings,
      );
      expect(off.level, ProblemLevel.offline);
      expect([for (final p in off.problems) p.badge], ['Offline']);
      final fresh = monitoringStatusOf(
        _n('1', status: ConnectionStatus.offline, polled: false),
        const [],
        settings,
      );
      expect(fresh.level, ProblemLevel.none);
    });

    test('a projector error is an error with its code', () {
      final s = monitoringStatusOf(_n('1', errors: 'F305'), const [], settings);
      expect(s.level, ProblemLevel.error);
      expect(s.problems.single.badge, 'Error F305');
      expect(s.problems.single.flag, 'F305');
      expect(s.problems.single.kind, ProblemKind.projectorError);
    });

    test('an amber code is a Warning, not an Error', () {
      final s = monitoringStatusOf(_n('1', errors: 'H001'), const [], settings);
      expect(s.level, ProblemLevel.warning);
      expect(s.problems.single.badge, 'Warning H001');
    });

    test('Signal lost and a hot reading are not projector errors', () {
      final s = monitoringStatusOf(_n('1', errors: 'F305'), [
        ActiveAlert(
          nodeId: '1',
          rule: AlertRule.signalLost,
          severity: AlertSeverity.critical,
          value: 'No signal on HDMI 1',
          since: DateTime(2026),
        ),
        ActiveAlert(
          nodeId: '1',
          rule: AlertRule.intakeTemp,
          severity: AlertSeverity.critical,
          value: '52 °C',
          since: DateTime(2026),
        ),
      ], settings);
      expect(
        s.problems.map((p) => p.kind),
        unorderedEquals([
          ProblemKind.projectorError,
          ProblemKind.temperature,
          ProblemKind.signal,
        ]),
      );
      expect(projectorErrorsOf(s).map((p) => p.badge), ['Error F305']);
    });

    test('a hot exhaust needs attention, with value and threshold', () {
      final since = DateTime(2026, 10, 17, 16, 38);
      final s = monitoringStatusOf(_n('1'), [
        ActiveAlert(
          nodeId: '1',
          rule: AlertRule.exhaustTemp,
          severity: AlertSeverity.warning,
          value: '58 °C',
          since: since,
        ),
      ], settings);
      expect(s.level, ProblemLevel.warning);
      expect(s.exhaust, AlertSeverity.warning);
      final p = s.problems.single;
      expect(p.badge, 'Exhaust hot');
      expect(p.value, '58 °C, above 55 °C');
      expect(p.flag, '58 °C');
      expect(p.since, since);
    });

    test('a recovered Signal lost is not a problem; errors sort first', () {
      final s = monitoringStatusOf(
        _n('1', status: ConnectionStatus.unauthorized, errors: 'F305'),
        [
          ActiveAlert(
            nodeId: '1',
            rule: AlertRule.signalLost,
            severity: AlertSeverity.critical,
            value: 'HDMI 1',
            since: DateTime(2026),
            restoredAt: DateTime(2026, 1, 2),
          ),
        ],
        settings,
      );
      expect(
        [for (final p in s.problems) p.badge],
        ['Error F305', 'Wrong login'],
      );
    });

    test('group summary names only what there is', () {
      expect(
        monitoringGroupSummary([
          const MonitoringStatus(online: true),
          const MonitoringStatus(online: true, level: ProblemLevel.warning),
          const MonitoringStatus(level: ProblemLevel.offline),
        ]),
        '3 projectors, 2 online, 1 needs attention, 1 offline',
      );
      expect(
        monitoringGroupSummary([
          const MonitoringStatus(online: true, standby: true),
        ]),
        '1 projector, 1 online, 1 in standby',
      );
    });
  });

  group('format', () {
    test('units get a space, hours lower case', () {
      expect(withUnit('1,644H'), '1,644 h');
      expect(withUnit('25°C'), '25 °C');
      expect(withUnit('230V'), '230 V');
      expect(withUnit('-'), '-');
    });

    test('last seen only while offline', () {
      final now = DateTime(2026, 10, 17, 17);
      final seen = DateTime(2026, 10, 17, 16, 41);
      expect(
        lastSeenLabel(
          _n('1', status: ConnectionStatus.offline, lastSeen: seen),
          now,
        ),
        'last seen 16:41',
      );
      expect(lastSeenLabel(_n('1', lastSeen: seen), now), isNull);
    });

    test('the threshold mark sits inside the bar', () {
      const t = kDefaultIntakeTempThreshold;
      expect(thresholdFraction(t), closeTo(40 / 56.25, 1e-9));
      expect(temperatureFraction('-', t), isNull);
      expect(temperatureFraction('99°C', t), 1);
    });
  });

  test('view settings survive a JSON round trip', () {
    const s = MonitoringViewSettings(
      mode: MonitoringViewMode.cards,
      cardDensity: MonitoringCardDensity.compact,
      groupByGroup: false,
      columns: ['projector', 'serial'],
      columnWidths: {'serial': 200},
      sortColumnId: 'serial',
      sortAscending: false,
      collapsed: {'g1', kUngroupedSectionKey},
    );
    final back = MonitoringViewSettings.fromJson(s.toJson());
    expect(back.mode, s.mode);
    expect(back.cardDensity, s.cardDensity);
    expect(back.groupByGroup, isFalse);
    expect(back.columns, s.columns);
    expect(back.columnWidths, s.columnWidths);
    expect(back.sortColumnId, 'serial');
    expect(back.sortAscending, isFalse);
    expect(back.collapsed, s.collapsed);
    expect(MonitoringViewSettings.fromJson(const {}).groupByGroup, isTrue);
  });
}
