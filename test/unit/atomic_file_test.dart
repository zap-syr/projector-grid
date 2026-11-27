import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/core/services/atomic_file.dart';
import 'package:projector_grid/core/services/window_prefs_service.dart';

import '../helpers/test_config_dir.dart';

void main() {
  final configDir = useTempConfigDir();

  final logged = <String>[];
  setUp(() {
    logged.clear();
    AppLog.debugOnError = (source, error, stack) =>
        logged.add('$source: $error');
  });
  tearDown(() => AppLog.debugOnError = null);

  String path(String name) =>
      '${configDir().path}${Platform.pathSeparator}$name';

  List<String> names() => [
    for (final e in configDir().listSync())
      e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ]..sort();

  List<File> badCopies(String name) => [
    for (final e in configDir().listSync())
      if (e is File && e.path.contains('$name.bad-')) e,
  ];

  group('writeFileAtomicSync', () {
    test('writes a new file and creates its folder', () {
      final target = path('sub${Platform.pathSeparator}new.json');
      writeFileAtomicSync(target, '{"a":1}');
      expect(File(target).readAsStringSync(), '{"a":1}');
      expect(File('$target.tmp').existsSync(), isFalse);
    });

    test('replaces an existing file (rename over an existing target)', () {
      final target = path('a.json');
      File(target).writeAsStringSync('old contents, longer than the new');
      writeFileAtomicSync(target, 'new');
      expect(File(target).readAsStringSync(), 'new');
      expect(names(), ['a.json']);
    });

    test('a stale .tmp from an earlier crash does not break the save', () {
      final target = path('a.json');
      File('$target.tmp')
          .writeAsStringSync('half-written garbage from a crash');
      writeFileAtomicSync(target, 'fresh');
      expect(File(target).readAsStringSync(), 'fresh');
      expect(File('$target.tmp').existsSync(), isFalse);
    });

    test('target is a directory: throws, nothing changes, no .tmp left', () {
      final target = path('dir');
      Directory(target).createSync();
      File('$target${Platform.pathSeparator}keep.txt').writeAsStringSync('x');

      expect(
        () => writeFileAtomicSync(target, 'data'),
        throwsA(isA<FileSystemException>()),
      );
      expect(Directory(target).existsSync(), isTrue);
      expect(
        File('$target${Platform.pathSeparator}keep.txt').existsSync(),
        isTrue,
      );
      expect(File('$target.tmp').existsSync(), isFalse);
    });

    test('parent path is a file: throws and creates nothing', () {
      final blocker = path('blocker');
      File(blocker).writeAsStringSync('i am a file');
      expect(
        () => writeFileAtomicSync(
          '$blocker${Platform.pathSeparator}x.json',
          'data',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(blocker).readAsStringSync(), 'i am a file');
      expect(names(), ['blocker']);
    });
  });

  group('writeFileAtomic', () {
    test('writes, replaces and ignores a stale .tmp', () async {
      final target = path('a.json');
      File('$target.tmp').writeAsStringSync('garbage');
      await writeFileAtomic(target, 'one');
      expect(File(target).readAsStringSync(), 'one');
      await writeFileAtomic(target, 'two');
      expect(File(target).readAsStringSync(), 'two');
      expect(names(), ['a.json']);
    });

    test('target is a directory: throws, no .tmp left', () async {
      final target = path('dir');
      Directory(target).createSync();
      await expectLater(
        writeFileAtomic(target, 'data'),
        throwsA(isA<FileSystemException>()),
      );
      expect(Directory(target).existsSync(), isTrue);
      expect(File('$target.tmp').existsSync(), isFalse);
    });

    test('keeps the old file when the temp file cannot be created', () async {
      final target = path('a.json');
      File(target).writeAsStringSync('precious');
      // A directory in the temp file's place makes the write fail for real.
      Directory('$target.tmp').createSync();
      await expectLater(
        writeFileAtomic(target, 'new'),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(target).readAsStringSync(), 'precious');
    });
  });

  group('saveConfigFileSync', () {
    test('an unwritable path logs the error and does not throw', () {
      final blocker = path('blocker');
      File(blocker).writeAsStringSync('i am a file');
      final target = '$blocker${Platform.pathSeparator}settings.json';

      expect(
        () => saveConfigFileSync(target, 'App settings', '{}'),
        returnsNormally,
      );
      expect(logged, hasLength(1));
      expect(logged.single, startsWith('App settings save: '));
    });

    test('a good path writes the file and logs nothing', () {
      saveConfigFileSync(path('s.json'), 'App settings', '{"x":2}');
      expect(File(path('s.json')).readAsStringSync(), '{"x":2}');
      expect(logged, isEmpty);
    });
  });

  group('readJsonConfigOrQuarantine', () {
    Map<String, dynamic> asMap(Object? json) => json as Map<String, dynamic>;

    test('a missing file is a first run: null, nothing logged or created', () {
      final result = readJsonConfigOrQuarantine(
        path('none.json'),
        'App settings',
        asMap,
      );
      expect(result, isNull);
      expect(logged, isEmpty);
      expect(names(), isEmpty);
    });

    test('a valid file is parsed and left alone', () {
      File(path('ok.json')).writeAsStringSync('{"a":1}');
      final result = readJsonConfigOrQuarantine(
        path('ok.json'),
        'App settings',
        asMap,
      );
      expect(result, {'a': 1});
      expect(logged, isEmpty);
      expect(names(), ['ok.json']);
    });

    test('a truncated file is renamed to .bad-<timestamp> with its bytes', () {
      const truncated = '{"pollingIntervalSeconds": 6';
      File(path('app_settings.json')).writeAsStringSync(truncated);

      final result = readJsonConfigOrQuarantine(
        path('app_settings.json'),
        'App settings',
        asMap,
      );

      expect(result, isNull);
      expect(File(path('app_settings.json')).existsSync(), isFalse);
      final bad = badCopies('app_settings.json');
      expect(bad, hasLength(1));
      expect(
        bad.single.uri.pathSegments.last,
        matches(RegExp(r'^app_settings\.json\.bad-\d{8}-\d{6}$')),
      );
      expect(bad.single.readAsStringSync(), truncated);
    });

    test('the log names the file, the reason and the .bad copy', () {
      File(path('app_settings.json')).writeAsStringSync('{"x":');
      readJsonConfigOrQuarantine(
        path('app_settings.json'),
        'App settings',
        asMap,
      );

      expect(logged, hasLength(1));
      final line = logged.single;
      expect(line, startsWith('App settings load: '));
      expect(line, contains(path('app_settings.json')));
      expect(line, contains('FormatException'));
      expect(line, contains(badCopies('app_settings.json').single.path));
    });

    test('a wrong shape that throws in parse counts as a failed load', () {
      File(path('list.json')).writeAsStringSync('[1, 2, 3]');
      final result = readJsonConfigOrQuarantine(
        path('list.json'),
        'Thing',
        asMap,
      );
      expect(result, isNull);
      expect(badCopies('list.json'), hasLength(1));
      expect(logged, hasLength(1));
    });

    test('bytes that are not UTF-8 count as a failed load', () {
      File(path('bin.json')).writeAsBytesSync([0x7b, 0x22, 0xff, 0xfe, 0x00]);
      final result = readJsonConfigOrQuarantine(
        path('bin.json'),
        'Thing',
        asMap,
      );
      expect(result, isNull);
      expect(badCopies('bin.json').single.readAsBytesSync(), [
        0x7b,
        0x22,
        0xff,
        0xfe,
        0x00,
      ]);
    });

    test('a parse that returns normally is trusted, even with null', () {
      File(path('p.json')).writeAsStringSync('{"a":1}');
      final result = readJsonConfigOrQuarantine<String?>(
        path('p.json'),
        'Thing',
        (_) => null,
      );
      expect(result, isNull);
      expect(names(), ['p.json']);
      expect(logged, isEmpty);
    });

    test('two bad copies in the same second do not overwrite each other', () {
      for (final body in ['{"first":', '{"second":']) {
        File(path('c.json')).writeAsStringSync(body);
        readJsonConfigOrQuarantine(path('c.json'), 'Thing', asMap);
      }
      final bodies = badCopies(
        'c.json',
      ).map((f) => f.readAsStringSync()).toList()..sort();
      expect(bodies, ['{"first":', '{"second":']);
    });
  });

  group('WindowPrefsService', () {
    test('a truncated file is kept as .bad and load returns null', () {
      File(path('window_prefs.json')).writeAsStringSync('{"width": 12');
      expect(WindowPrefsService.load(), isNull);
      expect(badCopies('window_prefs.json'), hasLength(1));
      expect(logged.single, startsWith('Window prefs load: '));
    });

    test('values out of range are not a failed load', () {
      File(path('window_prefs.json')).writeAsStringSync(
        jsonEncode({'width': 10, 'height': 10, 'x': 0, 'y': 0}),
      );
      expect(WindowPrefsService.load(), isNull);
      expect(badCopies('window_prefs.json'), isEmpty);
      expect(logged, isEmpty);
    });

    test('save then load round-trips', () {
      const prefs = WindowPrefs(
        width: 1200,
        height: 800,
        x: 10,
        y: 20,
        isMaximized: true,
      );
      WindowPrefsService.save(prefs);
      final loaded = WindowPrefsService.load();
      expect(loaded?.width, 1200);
      expect(loaded?.isMaximized, isTrue);
      expect(names(), ['window_prefs.json']);
    });
  });
}
