import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/event_log_rows.dart';
import 'package:projector_grid/features/workspace/domain/event_log_view.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';

final _t0 = DateTime(2026, 10, 20, 21, 0, 0);
final _now = DateTime(2026, 10, 20, 22);

DateTime _at(int ms) => _t0.add(Duration(milliseconds: ms));

/// The rows of [chronological] events, oldest first as written here; the
/// provider keeps them newest first.
List<LogRow> _rows(List<LogEvent> chronological) =>
    buildLogRows(chronological.reversed.toList());

LogEvent _plain(String id, String message, {int ms = 0}) => LogEvent(
  severity: LogSeverity.warning,
  type: LogEventType.connectivity,
  message: message,
  projectorIp: '10.0.1.$id',
  nodeId: id,
  timestamp: _at(ms),
);

LogEvent _conn(String id, LogGroupKind kind, {int ms = 0, String? group}) =>
    LogEvent(
      severity: kind == LogGroupKind.online
          ? LogSeverity.success
          : LogSeverity.error,
      type: LogEventType.connectivity,
      message: kind.title,
      projectorIp: '10.0.1.$id',
      projectorName: 'PT-RZ120',
      nodeId: id,
      groupKind: kind,
      projectorGroup: group,
      timestamp: _at(ms),
    );

LogEvent _back(String id, int seconds, {int ms = 0}) => LogEvent(
  severity: LogSeverity.success,
  type: LogEventType.alert,
  message: 'Signal lost: Back after $seconds s',
  projectorIp: '10.0.1.$id',
  nodeId: id,
  groupKind: alertLogGroupKind(AlertRule.signalLost, AlertChange.recovered),
  groupDetail: 'Back after $seconds s',
  projectorGroup: 'Stage',
  timestamp: _at(ms),
);

const _up = 'VXX:LNSI3=+00100';
const _right = 'VXX:LNSI2=+00100';

LogEvent _step(
  String id, {
  int ms = 0,
  String cmd = _up,
  CommandSource source = CommandSource.controlBar,
  CommandOutcome outcome = CommandOutcome.sent,
}) => LogEvent(
  severity: outcome == CommandOutcome.failed
      ? LogSeverity.error
      : LogSeverity.info,
  type: LogEventType.command,
  message: commandLabel(cmd),
  projectorIp: '10.0.1.$id',
  nodeId: id,
  source: source,
  outcome: outcome,
  command: cmd,
  timestamp: _at(ms),
);

/// A lens step to several projectors: its lines, then the summary.
List<LogEvent> _batchStep(
  String id,
  List<String> nodeIds, {
  int ms = 0,
  CommandSource source = CommandSource.controlBar,
  Set<String> failed = const {},
}) {
  final batch = CommandBatch(
    id: id,
    command: _up,
    source: source,
    target: '${nodeIds.length} projectors',
    nodeIds: nodeIds,
  );
  return [
    for (final n in nodeIds)
      LogEvent(
        severity: failed.contains(n) ? LogSeverity.error : LogSeverity.success,
        type: LogEventType.command,
        message: failed.contains(n) ? 'Failed: no answer or refused' : 'Sent',
        projectorIp: '10.0.1.$n',
        nodeId: n,
        batch: batch,
        outcome: failed.contains(n)
            ? CommandOutcome.failed
            : CommandOutcome.sent,
        timestamp: _at(ms),
      ),
    LogEvent(
      severity: failed.isEmpty ? LogSeverity.info : LogSeverity.warning,
      type: LogEventType.command,
      message: 'Lens Shift V',
      source: source,
      batch: batch,
      timestamp: _at(ms + 50),
    ),
  ];
}

LogEvent _osc(String address, String sender, {int ms = 0}) => LogEvent(
  severity: LogSeverity.info,
  type: LogEventType.osc,
  message: address,
  command: _up,
  oscSender: sender,
  timestamp: _at(ms),
);

void main() {
  group('repeats', () {
    test('other projectors in between do not break the run', () {
      final rows = _rows([
        _plain('1', 'Connection lost', ms: 0),
        _plain('2', 'Lamp hours high', ms: 100),
        _plain('1', 'Connection lost', ms: 200),
        _plain('3', 'Lamp hours high', ms: 300),
        _plain('1', 'Connection lost', ms: 400),
      ]);
      expect(rows, hasLength(3));
      final repeat = rows.first as RepeatLogRow;
      expect(repeat.count, 3);
      expect(repeat.latest.timestamp, _at(400));
      expect(repeatCountText(repeat, _now), '3 times, last 21:00:00');
      expect(rowFilterCounts(rows)[EventLogFilter.all], 3);
    });

    test('another event from the same projector ends the run', () {
      final rows = _rows([
        _plain('1', 'Connection lost', ms: 0),
        _plain('1', 'Lamp hours high', ms: 100),
        _plain('1', 'Connection lost', ms: 200),
      ]);
      expect(rows, hasLength(3));
      expect(rows.every((r) => r is SingleLogRow), isTrue);
    });

    test('copy names the count', () {
      final rows = _rows([
        _plain('1', 'Connection lost', ms: 0),
        _plain('1', 'Connection lost', ms: 1000),
      ]);
      expect(
        logCopyText(rows, _now),
        '21:00:01  warning  10.0.1.1  Connection  '
        'Connection lost, 2 times, last 21:00:01',
      );
    });
  });

  group('groups across projectors', () {
    test('the same kind with different text folds into one row', () {
      final rows = _rows([
        _back('1', 3, ms: 0),
        _back('2', 4, ms: 300),
        _back('3', 3, ms: 600),
      ]);
      final group = rows.single as GroupLogRow;
      expect(group.members.map((e) => e.nodeId), ['1', '2', '3']);
      expect(group.kind.title, 'Signal back');
      expect(group.target, 'Stage, 3 projectors');
      expect(group.members.map((e) => e.groupDetail), [
        'Back after 3 s',
        'Back after 4 s',
        'Back after 3 s',
      ]);
      expect(group.severity, LogSeverity.success);
    });

    test('opened, the lines go by IP, not by reply order', () {
      final rows = _rows([
        _conn('4', LogGroupKind.offline),
        _conn('11', LogGroupKind.offline, ms: 10),
        _conn('1', LogGroupKind.offline, ms: 20),
        _conn('2', LogGroupKind.offline, ms: 30),
      ]);
      final group = rows.single as GroupLogRow;
      expect(group.lines.map((e) => e.nodeId), ['1', '2', '4', '11']);
    });

    test('N projectors when they are not all in one group', () {
      final rows = _rows([
        _conn('1', LogGroupKind.online, group: 'Stage'),
        _conn('2', LogGroupKind.online, ms: 10),
      ]);
      expect((rows.single as GroupLogRow).target, '2 projectors');
    });

    test('only within 2 s of the first event', () {
      final rows = _rows([
        _conn('1', LogGroupKind.offline, ms: 0),
        _conn('2', LogGroupKind.offline, ms: 1500),
        _conn('3', LogGroupKind.offline, ms: 2500),
      ]);
      expect(rows, hasLength(2));
      expect((rows.first as SingleLogRow).event.nodeId, '3');
      expect((rows.last as GroupLogRow).members, hasLength(2));
    });

    test('another kind from those projectors in between splits it', () {
      final rows = _rows([
        _conn('1', LogGroupKind.online, ms: 0),
        _conn('1', LogGroupKind.offline, ms: 200),
        _conn('2', LogGroupKind.online, ms: 400),
      ]);
      expect(rows, hasLength(3));
      expect(rows.every((r) => r is SingleLogRow), isTrue);
    });

    test('another kind from another projector does not', () {
      final rows = _rows([
        _conn('1', LogGroupKind.online, ms: 0),
        _conn('3', LogGroupKind.offline, ms: 100),
        _conn('2', LogGroupKind.online, ms: 200),
      ]);
      expect(rows, hasLength(2));
      expect((rows.first as GroupLogRow).members, hasLength(2));
      expect((rows.last as SingleLogRow).event.nodeId, '3');
    });

    test('a group of one is a plain row', () {
      final rows = _rows([_conn('1', LogGroupKind.online)]);
      expect(rows.single, isA<SingleLogRow>());
    });

    test('a search for an IP finds and opens it, its title only finds', () {
      final rows = _rows([
        _conn('1', LogGroupKind.online),
        _conn('2', LogGroupKind.online, ms: 10),
      ]);
      final group = rows.single;
      expect(visibleRows(rows, EventLogFilter.all, '10.0.1.2'), [group]);
      expect(rowOpenedBySearch(group, '10.0.1.2'), isTrue);
      expect(visibleRows(rows, EventLogFilter.all, 'came online'), [group]);
      expect(rowOpenedBySearch(group, 'came online'), isFalse);
      expect(visibleRows(rows, EventLogFilter.all, '10.0.1.9'), isEmpty);
    });

    test('the cap counts a group as one row and keeps it whole', () {
      final events = [
        _plain('8', 'older', ms: 0),
        _plain('9', 'old', ms: 100),
        _conn('1', LogGroupKind.online, ms: 1000),
        _conn('2', LogGroupKind.online, ms: 1010),
        _conn('3', LogGroupKind.online, ms: 1020),
      ].reversed.toList();
      expect(buildLogRows(events), hasLength(3));
      expect(capLogRows(events, 3), same(events));
      final one = capLogRows(events, 1);
      expect(one.map((e) => e.nodeId), ['3', '2', '1']);
    });

    test('copy writes the group line and its projector lines', () {
      final rows = _rows([
        _conn('1', LogGroupKind.offline, group: 'Stage'),
        _conn('2', LogGroupKind.offline, ms: 1000, group: 'Stage'),
      ]);
      expect(logCopyText(rows, _now).split('\n'), [
        '21:00:01  error  Stage, 2 projectors  Connection  Went offline',
        '  21:00:00  error  10.0.1.1 PT-RZ120  Connection  Went offline',
        '  21:00:01  error  10.0.1.2 PT-RZ120  Connection  Went offline',
      ]);
    });
  });

  group('lens nudges', () {
    test('one projector folds from the second step', () {
      var events = [_step('1', ms: 0)];
      expect(_rows(events).single, isA<SingleLogRow>());

      events = [...events, _step('1', ms: 800, cmd: _right)];
      var run = _rows(events).single as LensRunLogRow;
      expect(run.stepCount, 2);
      expect(lensRunCountText(run, _now), '2 steps, last 21:00:00');

      events = [...events, _step('1', ms: 2700)];
      run = _rows(events).single as LensRunLogRow;
      expect(run.stepCount, 3);
      expect(run.single!.projectorIp, '10.0.1.1');
      expect(lensRunPills(run), isEmpty, reason: 'every step got through');
      expect(run.severity, LogSeverity.info);
    });

    test('a failed step shows in the pills and the severity', () {
      final run =
          _rows([
                _step('1', ms: 0),
                _step('1', ms: 500, outcome: CommandOutcome.failed),
              ]).single
              as LensRunLogRow;
      expect(lensRunPills(run).map((p) => p.$2), ['1 sent', '1 failed']);
      expect(run.severity, LogSeverity.warning);
    });

    test('a batch to the same projectors folds, pills sum up', () {
      final rows = _rows([
        ..._batchStep('a', ['1', '2'], ms: 0),
        ..._batchStep('b', ['2', '1'], ms: 1000, failed: {'2'}),
        ..._batchStep('c', ['1', '2'], ms: 2000),
      ]);
      final run = rows.single as LensRunLogRow;
      expect(run.isBatch, isTrue);
      expect(run.stepCount, 3);
      expect(run.batchTarget, '2 projectors');
      expect(lensRunPills(run).map((p) => p.$2), ['5 sent', '1 failed']);
      expect(run.totals.map((t) => (t.latest.nodeId, lensTotalText(t))), [
        ('1', '3 sent'),
        ('2', '2 sent, 1 failed'),
      ]);
      expect(rowOpens(run), isTrue);
      expect(rowOpenedBySearch(run, '10.0.1.2'), isTrue);
    });

    test('another set of projectors starts its own run', () {
      final rows = _rows([
        ..._batchStep('a', ['1', '2'], ms: 0),
        ..._batchStep('b', ['1', '2', '3'], ms: 500),
      ]);
      expect(rows, hasLength(2));
      expect(rows.every((r) => r is BatchLogRow), isTrue);
    });

    test('a 3 s gap starts a new row', () {
      final rows = _rows([
        _step('1', ms: 0),
        _step('1', ms: 1000),
        _step('1', ms: 4000),
      ]);
      expect(rows, hasLength(2));
      expect(rows.first, isA<SingleLogRow>());
      expect((rows.last as LensRunLogRow).stepCount, 2);
    });

    test('another source starts a new row', () {
      final rows = _rows([
        _step('1', ms: 0),
        _step('1', ms: 500, source: CommandSource.shortcut),
        _step('1', ms: 1000, source: CommandSource.shortcut),
        _step('1', ms: 1500, source: const CommandSource.oscFrom('10.0.0.20')),
        _step('1', ms: 2000, source: const CommandSource.oscFrom('10.0.0.21')),
      ]);
      expect(rows, hasLength(4));
      expect((rows[2] as LensRunLogRow).source, CommandSource.shortcut);
    });

    test('another command or event for the projector ends the run', () {
      final rows = _rows([
        _step('1', ms: 0),
        _step('1', ms: 200, cmd: 'OSH:0'),
        _step('1', ms: 400),
        _conn('1', LogGroupKind.online, ms: 600),
        _step('1', ms: 800),
      ]);
      expect(rows, hasLength(5));
      expect(rows.whereType<LensRunLogRow>(), isEmpty);
    });

    test('another projector in between does not end it', () {
      final rows = _rows([
        _step('1', ms: 0),
        _conn('2', LogGroupKind.online, ms: 300),
        _step('1', ms: 600),
      ]);
      expect(rows, hasLength(2));
      expect((rows.first as LensRunLogRow).stepCount, 2);
    });

    test('OSC address lines fold by address and sender', () {
      const up = '/pgrid/all/lens/shift/up/normal';
      const down = '/pgrid/all/lens/shift/down/normal';
      final rows = _rows([
        _osc(up, '10.0.0.20', ms: 0),
        _osc(up, '10.0.0.20', ms: 500),
        _osc(up, '10.0.0.21', ms: 700),
        _osc(up, '10.0.0.20', ms: 1000),
        _osc(down, '10.0.0.20', ms: 1500),
        _osc(up, '10.0.0.20', ms: 2000),
      ]);
      expect(rows, hasLength(4));
      final folded = rows[2] as RepeatLogRow;
      expect(folded.count, 3);
      expect(folded.latest.oscSender, '10.0.0.20');
      expect(
        logRowCopyText(folded, _now),
        '21:00:01  info  App  OSC  $up from 10.0.0.20, '
        '3 times, last 21:00:01',
      );
      expect((rows[1] as SingleLogRow).event.message, down);
      expect((rows[3] as SingleLogRow).event.oscSender, '10.0.0.21');
    });

    test('copy writes the run and each projector total', () {
      final rows = _rows([
        ..._batchStep('a', ['1', '2'], ms: 0),
        ..._batchStep('b', ['1', '2'], ms: 1000, failed: {'2'}),
      ]);
      expect(logCopyText(rows, _now).split('\n'), [
        '21:00:01  warning  2 projectors  Command  '
            'Lens Shift from the control bar, 2 steps, last 21:00:01, '
            '3 sent, 1 failed',
        '  21:00:01  success  10.0.1.1  Command  2 sent',
        '  21:00:01  error  10.0.1.2  Command  1 sent, 1 failed',
      ]);
    });
  });

  test('no dashes or middle dots in folded text', () {
    final texts = [
      repeatCountText(
        _rows([_plain('1', 'x'), _plain('1', 'x', ms: 10)]).single
            as RepeatLogRow,
        _now,
      ),
      for (final c in AlertChange.values)
        alertLogGroupKind(AlertRule.signalLost, c).title,
      const CommandSource.oscFrom('10.0.0.20').label,
    ];
    for (final t in texts) {
      expect(t, isNot(matches(RegExp('[·—–−]'))));
    }
  });
}
