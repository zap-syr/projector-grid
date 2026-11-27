import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/core/services/log_files.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_view_settings.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/custom_commands_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_view_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/project_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

/// A settings file that cannot be parsed is kept as `<name>.bad-*` and the
/// provider starts from defaults; a missing file is just a first run; a save
/// that cannot write is logged, never thrown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  final logged = <String>[];
  final stacks = <Object?>[];
  setUp(() {
    logged.clear();
    stacks.clear();
    AppLog.debugOnError = (source, error, stack) {
      logged.add('$source: $error');
      stacks.add(stack);
    };
  });
  tearDown(() => AppLog.debugOnError = null);

  File file(String name) =>
      File('${configDir().path}${Platform.pathSeparator}$name');

  List<File> badCopies(String name) => [
    for (final e in configDir().listSync())
      if (e is File && e.path.contains('$name.bad-')) e,
  ];

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  /// Shared by every kind: [read] reads a value from a fresh provider, [save]
  /// makes it write, [checkSaved] checks what a later launch reads back.
  void recoveryTests({
    required String name,
    required String fileName,
    required String truncated,
    required Object? Function(ProviderContainer) read,
    required Object? defaults,
    required void Function(ProviderContainer) save,
    required void Function(Object? valueAfterSave) checkSaved,
  }) {
    group(name, () {
      test('a truncated file is kept as .bad and defaults are used', () {
        file(fileName).writeAsStringSync(truncated);
        final c = container();

        expect(read(c), defaults);
        final bad = badCopies(fileName);
        expect(bad, hasLength(1));
        expect(bad.single.readAsStringSync(), truncated);
        expect(file(fileName).existsSync(), isFalse);
        expect(logged, hasLength(1));
        expect(logged.single, contains(file(fileName).path));
        expect(logged.single, contains(bad.single.path));
        expect(stacks.single, isNull);

        // The next save writes a fresh valid file; the bad copy stays.
        save(c);
        jsonDecode(file(fileName).readAsStringSync());
        checkSaved(read(container()));
        expect(badCopies(fileName).single.readAsStringSync(), truncated);
      });

      test('a missing file gives defaults, no .bad copy and no error', () {
        final c = container();
        expect(read(c), defaults);
        expect(badCopies(fileName), isEmpty);
        expect(logged, isEmpty);
      });
    });
  }

  recoveryTests(
    name: 'app settings',
    fileName: 'app_settings.json',
    truncated: '{"pollingIntervalSeconds": 45, "themeMode": "li',
    read: (c) => c.read(appSettingsProvider).themeMode,
    defaults: ThemeMode.dark,
    save: (c) =>
        c.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.light),
    checkSaved: (v) => expect(v, ThemeMode.light),
  );

  recoveryTests(
    name: 'custom commands',
    fileName: 'custom_commands.json',
    truncated: '[{"id":"1","name":"Dyn","command":"OAD:1"},{"id":"2","na',
    read: (c) => c.read(customCommandsProvider).length,
    defaults: 0,
    save: (c) => c.read(customCommandsProvider.notifier).add('Dyn', 'OAD:1'),
    checkSaved: (v) => expect(v, 1),
  );

  recoveryTests(
    name: 'monitoring view',
    fileName: 'monitoring_view.json',
    truncated: '{"mode": "car',
    read: (c) => c.read(monitoringViewProvider).mode,
    defaults: MonitoringViewMode.table,
    save: (c) => c
        .read(monitoringViewProvider.notifier)
        .setMode(MonitoringViewMode.cards),
    checkSaved: (v) => expect(v, MonitoringViewMode.cards),
  );

  group('custom commands with one bad entry', () {
    test('only that entry is dropped and the file is not quarantined', () {
      file('custom_commands.json').writeAsStringSync(
        jsonEncode([
          {'id': '1', 'name': 'Dyn', 'command': 'OAD:1'},
          'not a command',
        ]),
      );
      final c = container();
      expect(c.read(customCommandsProvider).map((e) => e.name), ['Dyn']);
      expect(badCopies('custom_commands.json'), isEmpty);
      expect(logged, hasLength(1));
    });

    test('each dropped entry is logged with path, position and raw JSON', () {
      const good = {'id': '2', 'name': 'Dyn', 'command': 'OAD:1'};
      const bad1 = {'id': '1', 'name': 'No command'};
      file('custom_commands.json')
          .writeAsStringSync(jsonEncode([bad1, good, 'not a command']));
      final c = container();

      expect(c.read(customCommandsProvider).map((e) => e.name), ['Dyn']);
      expect(badCopies('custom_commands.json'), isEmpty);
      expect(logged, hasLength(2));
      expect(stacks, everyElement(isNull));
      final path = file('custom_commands.json').path;
      expect(logged[0], startsWith('Custom commands load: '));
      expect(logged[0], contains(path));
      expect(logged[0], contains('entry 1 of 3'));
      expect(logged[0], contains(jsonEncode(bad1)));
      expect(logged[1], startsWith('Custom commands load: '));
      expect(logged[1], contains(path));
      expect(logged[1], contains('entry 3 of 3'));
      expect(logged[1], contains('"not a command"'));
    });

    test('a long raw entry is cut to 300 characters plus dots', () {
      final long = {'id': '1', 'name': 'x' * 500};
      file('custom_commands.json').writeAsStringSync(jsonEncode([long]));
      container().read(customCommandsProvider);

      final raw = jsonEncode(long);
      expect(logged, hasLength(1));
      expect(logged.single, endsWith('${raw.substring(0, 300)}...'));
      expect(logged.single, isNot(contains(raw.substring(0, 301))));
    });

    test('the repeat gate keeps both entries that fail the same way', () {
      final keys = <String>[];
      AppLog.debugOnError = (source, error, stack) =>
          keys.add(errorRepeatKey(error, stack));
      file('custom_commands.json').writeAsStringSync(jsonEncode(['a', 'a']));
      container().read(customCommandsProvider);

      expect(keys, hasLength(2));
      final gate = ErrorRepeatGate();
      final now = DateTime(2026, 11, 27);
      expect(keys.map((k) => gate.admit(k, now)), everyElement(isNotNull));
    });

    test('a fully valid file logs nothing', () {
      file('custom_commands.json').writeAsStringSync(
        jsonEncode([
          {'id': '1', 'name': 'Dyn', 'command': 'OAD:1'},
        ]),
      );
      expect(container().read(customCommandsProvider), hasLength(1));
      expect(logged, isEmpty);
    });
  });

  // Built per test, after the test has put its files in place: the provider
  // reads recent.json when it is created.
  ProviderContainer projectContainer() {
    final c = makeContainer(FakeProtocolService());
    c.listen(projectStateProvider, (_, _) {});
    return c;
  }

  group('recent projects', () {
    test(
      'a truncated recent.json is kept as .bad, the next save is valid',
      () async {
        const truncated = '["C:/shows/a.pgrid", "C:/sh';
        file('recent.json').writeAsStringSync(truncated);
        final c = projectContainer();

        expect(c.read(projectStateProvider).recentProjects, isEmpty);
        final bad = badCopies('recent.json');
        expect(bad, hasLength(1));
        expect(bad.single.readAsStringSync(), truncated);
        expect(logged.single, contains(file('recent.json').path));

        final project = file('a.pgrid')
          ..writeAsStringSync(jsonEncode({'version': 2, 'nodes': []}));
        await c.read(projectStateProvider.notifier).openProject(project.path);

        expect(jsonDecode(file('recent.json').readAsStringSync()), [
          project.path,
        ]);
        expect(badCopies('recent.json').single.readAsStringSync(), truncated);
      },
    );

    test('a missing recent.json is a first run', () {
      final c = projectContainer();
      expect(c.read(projectStateProvider).recentProjects, isEmpty);
      expect(badCopies('recent.json'), isEmpty);
      expect(logged, isEmpty);
    });
  });

  group('a save that cannot write', () {
    test('is logged and does not throw', () {
      // A directory where the file should go: the rename onto it fails for
      // real. (It is not a file, so the load treats it as a first run.)
      Directory(file('app_settings.json').path).createSync();
      final c = container();
      c.read(appSettingsProvider);
      expect(logged, isEmpty);

      expect(
        () =>
            c.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.light),
        returnsNormally,
      );
      expect(logged, isNotEmpty);
      expect(logged.last, startsWith('App settings save: '));
      expect(stacks.last, isNull);
    });
  });

  group('project save', () {
    test(
      'a failed save leaves the existing file whole and reports false',
      () async {
        final c = projectContainer();
        final project = file('show.pgrid')
          ..writeAsStringSync(jsonEncode({'version': 2, 'nodes': []}));
        final before = project.readAsBytesSync();
        final notifier = c.read(projectStateProvider.notifier);
        await notifier.openProject(project.path);

        // A directory in the temp file's place makes the write fail for real.
        Directory('${project.path}.tmp').createSync();
        logged.clear();

        expect(await notifier.saveProject(), isFalse);
        expect(project.readAsBytesSync(), before);
        expect(logged, hasLength(1));
        expect(
          logged.single,
          startsWith('Saving the project to ${project.path}'),
        );
        expect(c.read(projectStateProvider).currentFilePath, project.path);
      },
    );

    test('a good save replaces the file and leaves no .tmp', () async {
      final c = projectContainer();
      final project = file('show.pgrid')
        ..writeAsStringSync(jsonEncode({'version': 2, 'nodes': []}));
      final notifier = c.read(projectStateProvider.notifier);
      await notifier.openProject(project.path);
      expect(await notifier.saveProject(), isTrue);

      expect(file('show.pgrid.tmp').existsSync(), isFalse);
      expect((jsonDecode(project.readAsStringSync()) as Map)['version'], 2);
    });
  });
}
