import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_config_dir.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/core/services/launch_args.dart';

void main() {
  final sep = Platform.pathSeparator;
  final abs = Platform.isWindows ? r'C:\a b\c' : '/a b/c';

  group('configDirFromArgs', () {
    test('returns the path of --config-dir, spaces kept', () {
      expect(configDirFromArgs(['--config-dir=$abs']), abs);
    });

    test('no argument gives null', () {
      expect(configDirFromArgs([]), isNull);
    });

    test('an empty value counts as not given', () {
      expect(configDirFromArgs(['--config-dir=']), isNull);
    });

    test('other arguments are ignored', () {
      expect(
        configDirFromArgs([
          '-NSDocumentRevisionsDebugMode',
          'YES',
          '--config-dir=$abs',
          '--other=1',
        ]),
        abs,
      );
      expect(configDirFromArgs(['-NSDocumentRevisionsDebugMode', 'YES']), null);
    });

    test('only the exact --config-dir= form counts', () {
      expect(configDirFromArgs(['--config-dir', abs]), isNull);
      expect(configDirFromArgs(['--config-dirs=$abs']), isNull);
    });

    test('the last one wins', () {
      expect(
        configDirFromArgs(['--config-dir=$abs/1', '--config-dir=$abs/2']),
        '$abs/2',
      );
    });

    test('a later empty value overrides an earlier one', () {
      expect(configDirFromArgs(['--config-dir=$abs', '--config-dir=']), isNull);
    });

    test('a relative path becomes absolute', () {
      final result = configDirFromArgs(['--config-dir=profile${sep}x'])!;
      expect(result, Directory('profile${sep}x').absolute.path);
      expect(Directory(result).isAbsolute, isTrue);
      expect(result, startsWith(Directory.current.path));
    });

    test('non-Latin characters are kept as is', () {
      // Escapes keep the source ASCII: "Projects" in Russian, plus Japanese.
      const name = '\u041F\u0440\u043E\u0435\u043A\u0442\u044B \u65E5\u672C';
      final path = Platform.isWindows ? 'C:\\$name\\x y' : '/$name/x y';
      expect(configDirFromArgs(['--config-dir=$path']), path);
    });
  });

  group('config dir override', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('pgrid_args_');
    });
    tearDown(() {
      appConfigDirOverride = null;
      debugAppConfigDirOverride = null;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('per-user files and the logs folder land in the override', () {
      appConfigDirOverride = temp.path;
      expect(
        appConfigFilePath('app_settings.json'),
        '${temp.path}${sep}app_settings.json',
      );
      expect(
        appConfigFilePath('window_prefs.json'),
        '${temp.path}${sep}window_prefs.json',
      );
      expect(logsFolderPath, '${temp.path}${sep}logs');
      expect(appConfigDirPath, temp.path);
    });

    test('the test override still wins when both are set', () {
      appConfigDirOverride = '${temp.path}${sep}runtime';
      debugAppConfigDirOverride = '${temp.path}${sep}test';
      expect(
        appConfigFilePath('app_settings.json'),
        '${temp.path}${sep}test${sep}app_settings.json',
      );
    });

    test('ensureConfigDir creates a missing nested folder', () {
      final nested = '${temp.path}${sep}a${sep}b c${sep}d';
      ensureConfigDir(nested);
      expect(Directory(nested).existsSync(), isTrue);
      ensureConfigDir(nested);
    });

    test('ensureConfigDir lets a failure propagate', () {
      final file = File('${temp.path}${sep}file')..writeAsStringSync('x');
      expect(
        () => ensureConfigDir('${file.path}${sep}sub'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('applyLaunchArgs sets the override before the log can start', () {
      final dir = '${temp.path}${sep}profile';
      final result = applyLaunchArgs(['--config-dir=$dir']);
      expect(result.fromArg, isTrue);
      expect(result.path, dir);
      expect(Directory(dir).existsSync(), isTrue);
      expect(logsFolderPath, '$dir${sep}logs');
    });

    test('applyLaunchArgs without the argument changes nothing', () {
      debugAppConfigDirOverride = temp.path;
      final result = applyLaunchArgs(['-NSDocumentRevisionsDebugMode', 'YES']);
      expect(result.fromArg, isFalse);
      expect(result.path, temp.path);
      expect(appConfigDirOverride, isNull);
    });

    test('applyLaunchArgs fails without falling back to the default', () {
      final file = File('${temp.path}${sep}file')..writeAsStringSync('x');
      expect(
        () => applyLaunchArgs(['--config-dir=${file.path}${sep}sub']),
        throwsA(isA<FileSystemException>()),
      );
      expect(appConfigDirOverride, isNull);
    });
  });
}
