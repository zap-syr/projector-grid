import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/event_log_rows.dart';
import 'package:projector_grid/features/workspace/domain/event_log_view.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';

LogEvent _e(
  LogEventType type,
  LogSeverity severity, {
  String message = 'msg',
  String? ip,
  String? model,
  DateTime? at,
}) => LogEvent(
  type: type,
  severity: severity,
  message: message,
  projectorIp: ip,
  projectorName: model,
  timestamp: at ?? DateTime(2026, 10, 20, 21, 4, 12),
);

void main() {
  final now = DateTime(2026, 10, 20, 22);

  group('filters', () {
    final cmdOk = _e(LogEventType.command, LogSeverity.success);
    final cmdFail = _e(LogEventType.command, LogSeverity.error);
    final connWarn = _e(LogEventType.connectivity, LogSeverity.warning);
    final alertInfo = _e(LogEventType.alert, LogSeverity.info);
    final alertError = _e(LogEventType.alert, LogSeverity.error);
    final oscInfo = _e(LogEventType.osc, LogSeverity.info);
    final webInfo = _e(LogEventType.web, LogSeverity.info);
    final webCmd = LogEvent(
      type: LogEventType.command,
      severity: LogSeverity.info,
      message: 'Shutter Close',
      source: const CommandSource.web(ip: '10.0.0.5', role: 'operator'),
    );
    final all = [
      cmdOk,
      cmdFail,
      connWarn,
      alertInfo,
      alertError,
      oscInfo,
      webInfo,
      webCmd,
    ];
    List<LogEvent> shown(EventLogFilter f) => [
      for (final r in visibleRows(buildLogRows(all), f, ''))
        (r as SingleLogRow).event,
    ];

    test('Alerts takes errors and warnings of any type and every alert', () {
      expect(shown(EventLogFilter.alerts), [
        cmdFail,
        connWarn,
        alertInfo,
        alertError,
      ]);
    });

    test('each type chip takes its type, Web also the Web page commands', () {
      expect(shown(EventLogFilter.commands), [cmdOk, cmdFail, webCmd]);
      expect(shown(EventLogFilter.connection), [connWarn]);
      expect(shown(EventLogFilter.osc), [oscInfo]);
      expect(shown(EventLogFilter.web), [webInfo, webCmd]);
      expect(shown(EventLogFilter.all), all);
    });

    test('counts per chip ignore the search', () {
      final counts = rowFilterCounts(buildLogRows(all));
      expect(counts[EventLogFilter.all], 8);
      expect(counts[EventLogFilter.alerts], 4);
      expect(counts[EventLogFilter.commands], 3);
      expect(counts[EventLogFilter.web], 2);
      expect(rowFilterCounts(buildLogRows([cmdOk]))[EventLogFilter.web], 0);
    });
  });

  test('search looks in IP, model and message, any case', () {
    final a = _e(
      LogEventType.command,
      LogSeverity.info,
      ip: '10.0.1.33',
      model: 'PT-RZ120',
      message: 'Shutter Close',
    );
    expect(eventMatchesSearch(a, '.33'), isTrue);
    expect(eventMatchesSearch(a, 'rz120'), isTrue);
    expect(eventMatchesSearch(a, 'shutter'), isTrue);
    expect(eventMatchesSearch(a, 'hdmi'), isFalse);
    expect(eventMatchesSearch(a, ''), isTrue);
  });

  test('match ranges find every occurrence, any case', () {
    expect(searchMatchRanges('Abc abc', 'ab'), [(0, 2), (4, 6)]);
    expect(searchMatchRanges('abc', ''), isEmpty);
    expect(searchMatchRanges('abc', 'x'), isEmpty);
  });

  test('time: today time only, an earlier day with its date', () {
    expect(formatLogTime(DateTime(2026, 10, 20, 21, 4, 12), now), '21:04:12');
    expect(
      formatLogTime(DateTime(2026, 10, 19, 23, 58, 4), now),
      '19 Oct 23:58:04',
    );
    expect(formatLogTime(DateTime(2026, 9, 5, 1, 2, 3), now), '5 Sep 01:02:03');
  });

  group('copy', () {
    test('one line per row in the plan format', () {
      final e = _e(
        LogEventType.alert,
        LogSeverity.error,
        ip: '10.0.1.33',
        model: 'PT-RZ120',
        message: 'Projector error: F305',
      );
      expect(
        logCopyLine(e, now),
        '21:04:12  error  10.0.1.33 PT-RZ120  Alert  Projector error: F305',
      );
    });

    test('App without a projector, the date for an earlier day', () {
      final e = _e(
        LogEventType.web,
        LogSeverity.info,
        message: 'Web server started',
        at: DateTime(2026, 10, 19, 23, 58, 4),
      );
      expect(
        logCopyLine(e, now),
        '19 Oct 23:58:04  info  App  Web  Web server started',
      );
    });

    test('rows joined by newlines', () {
      final a = _e(LogEventType.osc, LogSeverity.info, message: 'a');
      final b = _e(LogEventType.osc, LogSeverity.info, message: 'b');
      expect(logCopyText(buildLogRows([a, b]), now).split('\n'), hasLength(2));
    });
  });

  test('no match line names the filter and the search', () {
    expect(
      noMatchDescription(EventLogFilter.osc, '10.0.9.99'),
      'OSC, search "10.0.9.99"',
    );
    expect(noMatchDescription(EventLogFilter.all, 'x'), 'Search "x"');
    expect(noMatchDescription(EventLogFilter.alerts, ''), 'Alerts');
  });

  test('narrow header with hysteresis', () {
    expect(eventLogNarrow(800), isTrue);
    expect(eventLogNarrow(1600), isFalse);
    const mid = (eventLogNarrowBelow + eventLogFullAbove) / 2;
    expect(eventLogNarrow(mid + 1, wasNarrow: true), isTrue);
    expect(eventLogNarrow(mid - 1, wasNarrow: false), isFalse);
  });

  test('panel height: the saved value within min and max', () {
    expect(eventLogPanelHeight(400, min: 120, max: 800), 400);
    expect(eventLogPanelHeight(400, min: 120, max: 300), 300);
    expect(eventLogPanelHeight(50, min: 120, max: 300), 120);
    expect(eventLogPanelHeight(400, min: 120, max: 100), 120);
  });
}
