import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/command_log.dart';
import 'package:projector_grid/features/workspace/domain/event_log_rows.dart';
import 'package:projector_grid/features/workspace/domain/event_log_view.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';

import '../helpers/provider_harness.dart';

final _at = DateTime(2026, 10, 20, 20, 41, 4);
final _now = DateTime(2026, 10, 20, 22);

CommandBatch _batch(String id, List<String> nodeIds) => CommandBatch(
  id: id,
  command: 'OSH:0',
  source: CommandSource.controlBar,
  target: 'Stage, ${nodeIds.length} projectors',
  nodeIds: nodeIds,
);

LogEvent _line(CommandBatch b, String nodeId, CommandOutcome o) => LogEvent(
  severity: switch (o) {
    CommandOutcome.sent => LogSeverity.success,
    CommandOutcome.failed => LogSeverity.error,
    CommandOutcome.skipped => LogSeverity.info,
  },
  type: LogEventType.command,
  message: batchLineMessage(
    o,
    reason: switch (o) {
      CommandOutcome.sent => null,
      CommandOutcome.failed => commandFailedReason,
      CommandOutcome.skipped => 'offline',
    },
  ),
  projectorIp: '10.0.1.$nodeId',
  projectorName: 'PT-RZ120',
  batch: b,
  outcome: o,
  nodeId: nodeId,
  timestamp: _at,
);

LogEvent _summary(CommandBatch b, {bool allOk = true}) => LogEvent(
  severity: allOk ? LogSeverity.info : LogSeverity.warning,
  type: LogEventType.command,
  message: 'Shutter Open',
  source: b.source,
  batch: b,
  timestamp: _at,
);

LogEvent _single(String message) => LogEvent(
  severity: LogSeverity.info,
  type: LogEventType.connectivity,
  message: message,
  timestamp: _at,
);

void main() {
  group('batch grouping', () {
    final b = _batch('b1', ['31', '32', '33']);

    test('a batch is one row in its newest event place, lines in order', () {
      // Newest first, a poll line between the replies.
      final events = [
        _summary(b, allOk: false),
        _line(b, '33', CommandOutcome.failed),
        _single('poll'),
        _line(b, '31', CommandOutcome.sent),
        _line(b, '32', CommandOutcome.sent),
        _single('older'),
      ];
      final rows = buildLogRows(events);
      expect(rows, hasLength(3));
      final row = rows.first as BatchLogRow;
      expect(row.done, isTrue);
      expect(row.lines.map((l) => l.nodeId), ['31', '32', '33']);
      expect((rows[1] as SingleLogRow).event.message, 'poll');
      expect((rows[2] as SingleLogRow).event.message, 'older');
    });

    test(
      'in flight: the row is there from the first reply, pills count up',
      () {
        var events = [_line(b, '32', CommandOutcome.sent)];
        var row = buildLogRows(events).single as BatchLogRow;
        expect(row.done, isFalse);
        expect(batchPills(row).map((p) => p.$2), ['1 sent']);

        events = [_line(b, '33', CommandOutcome.failed), ...events];
        row = buildLogRows(events).single as BatchLogRow;
        expect(batchPills(row).map((p) => p.$2), ['1 sent', '1 failed']);

        events = [
          _summary(b, allOk: false),
          _line(b, '31', CommandOutcome.skipped),
          ...events,
        ];
        row = buildLogRows(events).single as BatchLogRow;
        expect(row.done, isTrue);
        expect(batchPills(row).map((p) => p.$2), [
          '1 sent',
          '1 failed',
          '1 skipped',
        ]);
      },
    );

    test('severity: info when all sent, warning on a failure or skip', () {
      BatchLogRow rowOf(List<CommandOutcome> outcomes) =>
          buildLogRows([
                for (final (i, o) in outcomes.indexed) _line(b, '3${i + 1}', o),
              ]).single
              as BatchLogRow;
      expect(
        rowOf([CommandOutcome.sent, CommandOutcome.sent]).severity,
        LogSeverity.info,
      );
      expect(
        rowOf([CommandOutcome.sent, CommandOutcome.failed]).severity,
        LogSeverity.warning,
      );
      expect(
        rowOf([CommandOutcome.sent, CommandOutcome.skipped]).severity,
        LogSeverity.warning,
      );
      // So a batch with a failure shows under Alerts, an all-sent one not.
      expect(
        rowMatchesFilter(rowOf([CommandOutcome.failed]), EventLogFilter.alerts),
        isTrue,
      );
      expect(
        rowMatchesFilter(rowOf([CommandOutcome.sent]), EventLogFilter.alerts),
        isFalse,
      );
    });

    test('a batch counts once per chip, its lines not at all', () {
      final counts = rowFilterCounts(
        buildLogRows([
          _summary(b, allOk: false),
          _line(b, '31', CommandOutcome.failed),
          _line(b, '32', CommandOutcome.failed),
        ]),
      );
      expect(counts[EventLogFilter.all], 1);
      expect(counts[EventLogFilter.alerts], 1);
      expect(counts[EventLogFilter.commands], 1);
    });
  });

  group('500-row cap', () {
    test('a batch is one row and is dropped whole', () {
      final b = _batch('b', ['1', '2', '3']);
      // Oldest is the batch, its lines interleaved with newer singles.
      final events = [
        _single('newest'),
        _summary(b),
        _single('mid'),
        _line(b, '1', CommandOutcome.sent),
        _line(b, '2', CommandOutcome.sent),
        _line(b, '3', CommandOutcome.sent),
        _single('oldest'),
      ];
      // 4 rows: newest, batch, mid, oldest.
      expect(capLogRows(events, 4), same(events));
      final three = capLogRows(events, 3);
      expect(three, hasLength(6), reason: 'only the oldest single goes');
      final two = capLogRows(events, 2);
      expect(two.map((e) => e.message), [
        'newest',
        'Shutter Open',
        'Sent',
        'Sent',
        'Sent',
      ]);
      final one = capLogRows(events, 1);
      expect(one.map((e) => e.message), ['newest'], reason: 'batch whole');
    });

    test('a 100-projector batch takes one of 500 places', () {
      final b = _batch('big', [for (var i = 0; i < 100; i++) '$i']);
      final events = [
        _summary(b),
        for (var i = 0; i < 100; i++) _line(b, '$i', CommandOutcome.sent),
        for (var i = 0; i < 600; i++) _single('e$i'),
      ];
      final kept = capLogRows(events, 500);
      expect(buildLogRows(kept), hasLength(500));
      expect(kept.where((e) => e.batch != null), hasLength(101));
    });
  });

  test('Retry targets the failed ids still in the workspace', () {
    final b = _batch('r', ['1', '2', '3']);
    final row =
        buildLogRows([
              _summary(b, allOk: false),
              _line(b, '1', CommandOutcome.failed),
              _line(b, '2', CommandOutcome.sent),
              _line(b, '3', CommandOutcome.failed),
            ]).single
            as BatchLogRow;
    expect(row.failedNodeIds, ['1', '3']);
    expect(retryTargets(row.failedNodeIds, ['1', '2']), ['1']);
  });

  test('source labels', () {
    expect(CommandSource.controlBar.label, 'from the control bar');
    expect(CommandSource.osc.label, 'from OSC');
    expect(CommandSource.retry.label, 'from retry');
    expect(
      const CommandSource.schedule('Evening shutdown').label,
      'from scheduled task "Evening shutdown"',
    );
    const web = CommandSource.web(ip: '10.0.0.5', role: 'operator');
    expect(web.label, 'from Web, 10.0.0.5 (operator)');
    expect(web.kind, CommandSourceKind.web);
    for (final s in [
      CommandSource.controlBar,
      CommandSource.shortcut,
      CommandSource.osc,
      CommandSource.retry,
      web,
    ]) {
      expect(s.label, isNot(matches(RegExp('[·—–−]'))));
    }
  });

  test('target label: the group, or N projectors', () {
    const groups = [
      ProjectorGroup(id: 'g', name: 'Stage', color: 0),
      ProjectorGroup(id: 'h', name: 'Back', color: 0),
    ];
    expect(
      batchTargetLabel([
        node('1', groupId: 'g'),
        node('2', groupId: 'g'),
      ], groups),
      'Stage, 2 projectors',
    );
    expect(
      batchTargetLabel([
        node('1', groupId: 'g'),
        node('2', groupId: 'h'),
      ], groups),
      '2 projectors',
    );
    expect(
      batchTargetLabel([node('1', groupId: 'g'), node('2')], groups),
      '2 projectors',
    );
  });

  group('search in a batch', () {
    final b = _batch('s', ['31', '33']);
    final rows = buildLogRows([
      _summary(b),
      _line(b, '33', CommandOutcome.sent),
      _line(b, '31', CommandOutcome.sent),
    ]);
    final row = rows.single as BatchLogRow;

    test('an IP inside the batch finds it and opens it', () {
      expect(visibleRows(rows, EventLogFilter.all, '10.0.1.33'), [row]);
      expect(batchOpenedBySearch(row, '10.0.1.33'), isTrue);
    });

    test('the command or the target finds it without opening it', () {
      expect(visibleRows(rows, EventLogFilter.all, 'shutter'), [row]);
      expect(visibleRows(rows, EventLogFilter.all, 'stage'), [row]);
      expect(batchOpenedBySearch(row, 'stage'), isFalse);
      expect(visibleRows(rows, EventLogFilter.all, '10.0.9.9'), isEmpty);
    });
  });

  test('Copy writes the summary and its projector lines', () {
    final b = _batch('c', ['31', '33']);
    final rows = buildLogRows([
      _summary(b, allOk: false),
      _line(b, '33', CommandOutcome.failed),
      _line(b, '31', CommandOutcome.sent),
    ]);
    expect(logCopyText(rows, _now).split('\n'), [
      '20:41:04  warning  Stage, 2 projectors  Command  '
          'Shutter Open from the control bar, 1 sent, 1 failed',
      '  20:41:04  success  10.0.1.31 PT-RZ120  Command  Sent',
      '  20:41:04  error  10.0.1.33 PT-RZ120  Command  '
          'Failed: no answer or refused',
    ]);
  });
}
