import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/event_log_line.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';

void main() {
  final at = DateTime(2026, 10, 23, 21, 14, 5, 123);

  test('a projector event', () {
    expect(
      eventLogLine(
        LogEvent(
          severity: LogSeverity.error,
          type: LogEventType.connectivity,
          message: 'Went offline',
          projectorIp: '192.168.0.41',
          projectorName: 'RZ34K',
          timestamp: at,
        ),
      ),
      '21:14:05.123  ERROR    connectivity  '
      '${'192.168.0.41 (RZ34K)'.padRight(28)}  Went offline',
    );
  });

  test('the text starts in one column for short and long projectors', () {
    String line(String ip, String model) => eventLogLine(
      LogEvent(
        severity: LogSeverity.success,
        type: LogEventType.connectivity,
        message: 'Came online',
        projectorIp: ip,
        projectorName: model,
        timestamp: at,
      ),
    );
    final short = line('127.0.0.1', 'PT-RQ35K2');
    final long = line('192.168.100.200', 'PT-RQ35K2');
    expect(short.indexOf('Came online'), long.indexOf('Came online'));
  });

  test('a command to one projector names its source and code', () {
    expect(
      eventLogLine(
        LogEvent(
          severity: LogSeverity.info,
          type: LogEventType.command,
          message: 'Lens Shift H',
          projectorIp: '10.0.0.5',
          source: const CommandSource.schedule('Evening'),
          command: 'VXX:LNSI2=+00001',
          timestamp: at,
        ),
      ),
      endsWith(
        'Lens Shift H, from scheduled task "Evening"  [VXX:LNSI2=+00001]',
      ),
    );
  });

  group('a batch', () {
    const batch = CommandBatch(
      id: '1792756401454-7',
      command: 'OSH:1',
      source: CommandSource.web(ip: '10.0.0.90', role: 'operator'),
      target: 'Stage, 6 projectors',
      nodeIds: ['a', 'b'],
    );

    test('a projector line carries the command, its code and the batch', () {
      expect(
        eventLogLine(
          LogEvent(
            severity: LogSeverity.error,
            type: LogEventType.command,
            message: 'Failed: no answer or refused',
            projectorIp: '10.0.0.6',
            batch: batch,
            outcome: CommandOutcome.failed,
            timestamp: at,
          ),
        ),
        endsWith(
          'Shutter Close: Failed: no answer or refused  [OSH:1]  [batch 7]',
        ),
      );
    });

    LogEvent line(String ip, CommandOutcome outcome) => LogEvent(
      severity: LogSeverity.info,
      type: LogEventType.command,
      message: outcome.name,
      projectorIp: ip,
      batch: batch,
      outcome: outcome,
      timestamp: at,
    );

    test('the file gets only the lines that went wrong, and the counts', () {
      final lines = EventLogFileLines();
      expect(
        lines.lineFor(line('10.0.0.1', CommandOutcome.skipped)),
        isNotNull,
      );
      expect(lines.lineFor(line('10.0.0.2', CommandOutcome.sent)), isNull);
      expect(lines.lineFor(line('10.0.0.3', CommandOutcome.sent)), isNull);
      expect(lines.lineFor(line('10.0.0.4', CommandOutcome.failed)), isNotNull);
      final summary = lines.lineFor(
        LogEvent(
          severity: LogSeverity.warning,
          type: LogEventType.command,
          message: 'Shutter Close',
          source: batch.source,
          batch: batch,
          timestamp: at,
        ),
      );
      expect(
        summary,
        endsWith(
          'Shutter Close, from Web, 10.0.0.90 (operator), '
          '2 sent, 1 failed, 1 skipped  [OSH:1]  [batch 7]',
        ),
      );
    });

    test('a batch that all went out says only how many', () {
      final lines = EventLogFileLines();
      for (final ip in ['10.0.0.1', '10.0.0.2']) {
        expect(lines.lineFor(line(ip, CommandOutcome.sent)), isNull);
      }
      expect(
        lines.lineFor(
          LogEvent(
            severity: LogSeverity.info,
            type: LogEventType.command,
            message: 'Shutter Close',
            batch: batch,
            timestamp: at,
          ),
        ),
        endsWith('Shutter Close, 2 sent  [OSH:1]  [batch 7]'),
      );
    });

    test('events outside a batch pass through', () {
      final e = LogEvent(
        severity: LogSeverity.info,
        type: LogEventType.web,
        message: 'Web access on, port 8080',
        timestamp: at,
      );
      expect(EventLogFileLines().lineFor(e), eventLogLine(e));
    });

    test('the summary names the target and the source', () {
      expect(
        eventLogLine(
          LogEvent(
            severity: LogSeverity.warning,
            type: LogEventType.command,
            message: 'Shutter Close',
            source: batch.source,
            batch: batch,
            timestamp: at,
          ),
        ),
        '21:14:05.123  WARNING  command       '
        '${'Stage, 6 projectors'.padRight(28)}  '
        'Shutter Close, from Web, 10.0.0.90 (operator)  [OSH:1]  [batch 7]',
      );
    });
  });

  test('an OSC address line names the sender', () {
    expect(
      eventLogLine(
        LogEvent(
          severity: LogSeverity.info,
          type: LogEventType.osc,
          message: '/pgrid/all/shutter/close',
          oscSender: '10.0.0.20',
          command: 'OSH:1',
          timestamp: at,
        ),
      ),
      endsWith('/pgrid/all/shutter/close, from 10.0.0.20  [OSH:1]'),
    );
  });

  test('an event without a command has no code', () {
    expect(
      eventLogLine(
        LogEvent(
          severity: LogSeverity.info,
          type: LogEventType.web,
          message: 'Web access on, port 8080',
          timestamp: at,
        ),
      ),
      endsWith('Web access on, port 8080'),
    );
  });
}
