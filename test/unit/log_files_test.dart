import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/core/services/log_files.dart';

import '../helpers/test_config_dir.dart';

void main() {
  group('logFileName', () {
    test('prefix and zero-padded date', () {
      expect(
        logFileName('events', DateTime(2026, 3, 5)),
        'events-2026-03-05.log',
      );
      expect(logFileName('app', DateTime(2026, 10, 23)), 'app-2026-10-23.log');
    });
  });

  group('logFilesToPrune', () {
    final today = DateTime(2026, 10, 23, 18, 30);

    test('keeps today and the 13 days before it', () {
      expect(
        logFilesToPrune([
          'events-2026-10-23.log',
          'app-2026-10-10.log',
          'events-2026-10-09.log',
          'app-2025-12-31.log',
        ], today),
        ['events-2026-10-09.log', 'app-2025-12-31.log'],
      );
    });

    test('across a month boundary', () {
      expect(
        logFilesToPrune([
          'app-2026-02-18.log',
          'app-2026-02-17.log',
        ], DateTime(2026, 3, 3)),
        ['app-2026-02-17.log'],
      );
    });

    test('leaves other files alone', () {
      expect(
        logFilesToPrune([
          'notes-2020-01-01.log',
          'events-2020-01-01.txt',
          'events-old.log',
          'app-2020-01-01.log.bak',
        ], today),
        isEmpty,
      );
    });
  });

  group('logEntry', () {
    final at = DateTime(2026, 10, 23, 9, 4, 5, 7);

    test('time, padded level and text', () {
      expect(logEntry(at, 'INFO', 'Hello'), '09:04:05.007  INFO     Hello');
    });

    test('further lines and the stack are indented', () {
      expect(
        logEntry(at, 'ERROR', 'Bad state\nmore', detail: '#0 a\n#1 b\n'),
        '09:04:05.007  ERROR    Bad state\n'
        '    more\n'
        '    #0 a\n'
        '    #1 b',
      );
    });

    test('an empty stack adds nothing', () {
      expect(
        logEntry(at, 'ERROR', 'x', detail: ''),
        '09:04:05.007  ERROR    x',
      );
    });
  });

  group('ErrorRepeatGate', () {
    final t0 = DateTime(2026, 10, 23, 12);

    test('once a minute per key, with the repeats held back', () {
      final gate = ErrorRepeatGate();
      expect(gate.admit('a', t0), 0);
      expect(gate.admit('a', t0.add(const Duration(seconds: 1))), isNull);
      expect(gate.admit('a', t0.add(const Duration(seconds: 30))), isNull);
      expect(gate.admit('b', t0.add(const Duration(seconds: 30))), 0);
      expect(gate.heldBack(), {'a': 2});
      expect(gate.admit('a', t0.add(const Duration(minutes: 1))), 2);
      expect(gate.heldBack(), isEmpty);
    });

    test('the key is the first line and the first frame', () {
      final a = errorRepeatKey(StateError('x\nmore'), '#0 f (a.dart:1)\n#1 g');
      final b = errorRepeatKey(StateError('x\nother'), '#0 f (a.dart:1)\n#2 h');
      final c = errorRepeatKey(StateError('x'), '#0 f (a.dart:2)');
      expect(a, b);
      expect(a, isNot(c));
      expect(errorRepeatKey('x', null), 'x @ ');
    });
  });

  group('DailyLogFile', () {
    final configDir = useTempConfigDir();

    String read(DailyLogFile f, DateTime day) =>
        File(f.pathFor(day)).readAsStringSync();

    test('appends on flush, one file per day of the entry', () {
      final f = DailyLogFile('${configDir().path}/logs', 'events');
      final d1 = DateTime(2026, 10, 23, 23, 59);
      final d2 = DateTime(2026, 10, 24, 0, 1);
      f.write(d1, 'one');
      f.write(d2, 'two');
      f.flush();
      f.write(d2, 'three');
      f.flush();
      expect(read(f, d1), 'one\n');
      expect(read(f, d2), 'two\nthree\n');
    });

    test('past the cap only errors go in, after one note', () {
      final f = DailyLogFile('${configDir().path}/logs', 'app', maxBytes: 10);
      final at = DateTime(2026, 10, 23, 12);
      f.write(at, '0123456789');
      f.write(at, 'info dropped');
      f.write(at, 'error 1', isError: true);
      f.write(at, 'error 2', isError: true);
      f.flush();
      final lines = read(f, at).trimRight().split('\n');
      expect(lines, hasLength(4));
      expect(lines[1], contains('only errors are written'));
      expect(lines.sublist(2), ['error 1', 'error 2']);
    });

    test('the cap counts what a file already holds', () {
      final dir = '${configDir().path}/logs';
      final at = DateTime(2026, 10, 23, 12);
      final first = DailyLogFile(dir, 'app', maxBytes: 10)
        ..write(at, '0123456789')
        ..flush();
      // A second session the same day.
      DailyLogFile(dir, 'app', maxBytes: 10)
        ..write(at, 'info dropped')
        ..write(at, 'error kept', isError: true)
        ..flush();
      final text = read(first, at);
      expect(text, isNot(contains('info dropped')));
      expect(text, contains('only errors are written'));
      expect(text, endsWith('error kept\n'));
    });
  });

  group('AppLog', () {
    final configDir = useTempConfigDir();
    tearDown(AppLog.stop);

    File logFile(String prefix) => File(
      '${configDir().path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}${logFileName(prefix, DateTime.now())}',
    );

    test('writes nothing before start', () {
      AppLog.event(DateTime.now(), 'x');
      AppLog.error('Test', StateError('x'), StackTrace.current);
      AppLog.stop();
      expect(Directory('${configDir().path}/logs').existsSync(), isFalse);
    });

    test('events and errors go to their own files', () {
      AppLog.start(appVersion: '9.9.9+1', os: 'testos');
      AppLog.event(DateTime.now(), 'an event line');
      AppLog.info('a diagnostic');
      AppLog.error('Test', StateError('broken'), StackTrace.current);
      AppLog.note('Project opened: show.pgrid');
      AppLog.stop();

      final events = logFile('events').readAsStringSync();
      final app = logFile('app').readAsStringSync();
      expect(events, contains('Projector Grid 9.9.9+1 started on testos'));
      expect(events, contains('an event line'));
      expect(events, contains('Project opened: show.pgrid'));
      expect(events, isNot(contains('broken')));
      expect(events, contains('Projector Grid stopped'));

      expect(app, contains('a diagnostic'));
      expect(app, contains('ERROR    Test: Bad state: broken'));
      expect(app, contains('log_files_test.dart'), reason: 'the stack');
      expect(app, contains('Project opened: show.pgrid'));
      expect(app, isNot(contains('an event line')));
    });

    test('a repeated error is written once, its repeats at the end', () {
      AppLog.start(appVersion: '1', os: 'x');
      for (var i = 0; i < 5; i++) {
        AppLog.error('Test', StateError('again'), '#0 same frame');
      }
      AppLog.stop();
      final app = logFile('app').readAsStringSync();
      expect('Bad state: again'.allMatches(app), hasLength(2));
      expect(app, contains('Repeated 4 more times: Bad state: again'));
    });

    test('start prunes files past 14 days', () {
      final logs = Directory('${configDir().path}/logs')..createSync();
      final old = File('${logs.path}/app-2000-01-01.log')
        ..writeAsStringSync('');
      final other = File('${logs.path}/readme.txt')..writeAsStringSync('');
      AppLog.start(appVersion: '1', os: 'x');
      expect(old.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });
  });
}
