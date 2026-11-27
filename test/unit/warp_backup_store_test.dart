import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_config_dir.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/core/services/warp_backup_store.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

import '../helpers/test_config_dir.dart';

WarpBackup _backup({
  String key = '192.168.0.15|001c_00_26',
  WarpSlot slot = WarpSlot.pc1,
  int fill = 0,
}) => WarpBackup(
  projectorKey: key,
  modelId: '001c_00_26',
  slot: slot,
  takenAt: DateTime.utc(2026, 11, 28, 10, 30, 15, 123),
  type: 0x12,
  method: 3,
  gridColumns: 17,
  gridRows: 9,
  storedAt: DateTime.utc(2026, 11, 1, 8, 0, 0),
  block: Uint8List.fromList(List.generate(9 * 1024, (i) => (i + fill) & 0xff)),
);

void main() {
  late Directory root;
  late WarpBackupStore store;
  final logged = <String>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('pgrid_warp_backup_');
    store = WarpBackupStore(Directory('${root.path}/warp_backups'));
    logged.clear();
    AppLog.debugOnError = (source, error, stack) =>
        logged.add('$source: $error');
  });
  tearDown(() {
    AppLog.debugOnError = null;
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File fileFor(String name) => File('${root.path}/warp_backups/$name');

  test('save then load round-trips every field', () async {
    final original = _backup();
    await store.save(original);
    final loaded = await store.load(original.projectorKey, WarpSlot.pc1);

    expect(loaded, isNotNull);
    expect(loaded!.projectorKey, original.projectorKey);
    expect(loaded.modelId, original.modelId);
    expect(loaded.slot, WarpSlot.pc1);
    expect(loaded.takenAt, original.takenAt);
    expect(loaded.takenAt.isUtc, isTrue);
    expect(loaded.type, original.type);
    expect(loaded.method, original.method);
    expect(loaded.gridColumns, 17);
    expect(loaded.gridRows, 9);
    expect(loaded.storedAt, original.storedAt);
    expect(loaded.storedAt!.isUtc, isTrue);
    expect(loaded.block, original.block);
  });

  test('nullable fields round-trip as null', () async {
    final b = WarpBackup(
      projectorKey: 'k',
      modelId: 'm',
      slot: WarpSlot.pc3,
      takenAt: DateTime.utc(2026),
      type: 1,
      method: 2,
      block: Uint8List.fromList([1, 2, 3]),
    );
    await store.save(b);
    final loaded = await store.load('k', WarpSlot.pc3);
    expect(loaded!.gridColumns, isNull);
    expect(loaded.gridRows, isNull);
    expect(loaded.storedAt, isNull);
  });

  test('load with no file returns null and logs nothing', () async {
    expect(await store.load('k', WarpSlot.pc1), isNull);
    expect(logged, isEmpty);
  });

  test('save twice replaces the first backup', () async {
    await store.save(_backup(fill: 0));
    final second = _backup(fill: 7);
    await store.save(second);
    final loaded = await store.load(second.projectorKey, WarpSlot.pc1);
    expect(loaded!.block, second.block);
  });

  test('slots and keys are independent, delete removes one', () async {
    final a1 = _backup(slot: WarpSlot.pc1, fill: 1);
    final a2 = _backup(slot: WarpSlot.pc2, fill: 2);
    final b1 = _backup(key: 'other', slot: WarpSlot.pc1, fill: 3);
    await store.save(a1);
    await store.save(a2);
    await store.save(b1);

    expect((await store.load(a1.projectorKey, WarpSlot.pc1))!.block, a1.block);
    expect((await store.load(a1.projectorKey, WarpSlot.pc2))!.block, a2.block);
    expect((await store.load('other', WarpSlot.pc1))!.block, b1.block);

    await store.delete(a1.projectorKey, WarpSlot.pc1);
    expect(await store.load(a1.projectorKey, WarpSlot.pc1), isNull);
    expect(await store.load(a1.projectorKey, WarpSlot.pc2), isNotNull);
    await store.delete(a1.projectorKey, WarpSlot.pc1);
  });

  test('key is sanitised into a safe file name inside root', () async {
    await store.save(_backup());
    final names = Directory('${root.path}/warp_backups')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toList();
    expect(names, ['192.168.0.15_001c_00_26_pc1.json']);
  });

  test('a colliding key loads as null', () async {
    await store.save(_backup(key: 'a|b'));
    expect(await store.load('a|b', WarpSlot.pc1), isNotNull);
    expect(await store.load('a:b', WarpSlot.pc1), isNull);
    expect(logged, isEmpty);
  });

  group('unusable files', () {
    Future<void> expectKept(String name, String contents) async {
      fileFor(name).createSync(recursive: true);
      fileFor(name).writeAsStringSync(contents);
      expect(await store.load('k', WarpSlot.pc1), isNull);
      expect(fileFor(name).readAsStringSync(), contents);
      expect(logged, hasLength(1));
      expect(logged.single, contains(name));
    }

    Map<String, Object?> valid() => {
      'version': 1,
      'projectorKey': 'k',
      'modelId': 'm',
      'slot': 'pc1',
      'takenAt': '2026-01-01T00:00:00.000Z',
      'type': 1,
      'method': 2,
      'gridColumns': null,
      'gridRows': null,
      'storedAt': null,
      'block': base64Encode([1, 2]),
    };

    test('corrupt JSON', () => expectKept('k_pc1.json', '{not json'));

    test('wrong version', () {
      return expectKept('k_pc1.json', jsonEncode({...valid(), 'version': 2}));
    });

    test('missing field', () {
      final m = valid()..remove('block');
      return expectKept('k_pc1.json', jsonEncode(m));
    });
  });

  test('save with RAM is an ArgumentError', () {
    expect(() => store.save(_backup(slot: WarpSlot.ram)), throwsArgumentError);
  });

  group('inConfigDir', () {
    final configDir = useTempConfigDir();

    test('resolves under the config dir', () async {
      final s = WarpBackupStore.inConfigDir();
      await s.save(_backup());
      expect(debugAppConfigDirOverride, configDir().path);
      expect(
        File(
          '${configDir().path}${Platform.pathSeparator}warp_backups'
          '${Platform.pathSeparator}192.168.0.15_001c_00_26_pc1.json',
        ).existsSync(),
        isTrue,
      );
    });
  });
}
