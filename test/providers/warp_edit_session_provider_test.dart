import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/warp_backup_store.dart';
import 'package:projector_grid/core/services/warp_transfer.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_backup_store_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_edit_session_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/fake_warp_projector.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _id = '1';
const _ip = '10.0.0.1';

// A 4K model that skips the inverse table, with 3-byte tables.
final WarpModelCaps _caps = lookupWarpModelCaps('001c_00_26')!;

// A model whose memories can be missing: its first read says whether it has
// them (isNoInverse is false).
final WarpModelCaps _capsWithInverse = lookupWarpModelCaps('000a_00_26')!;

const _mids = 'MIDS1=0028:00:26';
const _midsWithInverse = 'MIDS1=0010:00:26';

/// A 3 x 3 grid table with the centre point [dx] px right of its place.
WarpTable _gridTable(WarpModelCaps caps, {double dx = 0}) {
  final grid = setControlPosition(
    WarpControlGrid.identity(
      columns: 3,
      rows: 3,
      panelWidth: caps.panelWidth,
      panelHeight: caps.panelHeight,
    ),
    {4},
    x: caps.panelWidth / 2 + dx,
    rangeX: caps.movableRangeX,
    rangeY: caps.movableRangeY,
  );
  return tableFromControlGrid(grid, caps.geometry);
}

/// A table whose rows end a quarter of the way down the panel, so no 3 x 3
/// grid can be fitted to it (the bottom control points get no node).
WarpTable _shortTable(WarpModelCaps caps) {
  final rows = caps.tableRows ~/ 4;
  return WarpTable(
    columns: caps.tableColumns,
    rows: rows,
    header: defaultWarpHeader(1),
    planes: [
      WarpPlane.generate(
        name: 'W',
        columns: caps.tableColumns,
        rows: rows,
        point: (c, r) =>
            ((c * caps.stepX).toDouble(), (r * caps.stepY).toDouble()),
      ),
    ],
  );
}

Uint8List _blockOf(WarpTable table, WarpModelCaps caps) {
  final e = encodeTable(table, WarpEncoding.triple, caps.bits);
  return Uint8List.fromList([...e.head, ...e.points]);
}

bool _isWrite(Uint8List f) => f.length > 9 && f[2] == 0xA9 && f[3] == 0xC0;
bool _isSave(Uint8List f) => f.length >= 4 && f[2] == 0xAA;
bool _isRead(Uint8List f) => f.length >= 4 && f[2] == 0xA8;

/// A backup store that cannot save.
class _FailingBackups extends WarpBackupStore {
  _FailingBackups(super.root);

  @override
  Future<void> save(WarpBackup backup) =>
      Future<void>.error(const FileSystemException('disk full'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  late FakeProtocolService fake;
  late WarpBackupStore backups;
  late List<ProviderContainer> containers;

  setUp(() {
    fake = FakeProtocolService()..rawResponses['QVX:MIDS1'] = _mids;
    fake.warpFor(_ip);
    backups = WarpBackupStore(
      Directory('${configDir().path}${Platform.pathSeparator}warp_backups'),
    );
    containers = [];
  });

  FakeWarpProjector projector() => fake.warpFor(_ip);

  void seed(WarpSlot slot, WarpTable table, WarpModelCaps caps) => projector()
      .setBlock(warpTypeCode(caps.fullBase, slot), _blockOf(table, caps));

  ProviderContainer newContainer({WarpBackupStore? store}) {
    final c = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        warpBackupStoreProvider.overrideWithValue(store ?? backups),
      ],
    );
    addTearDown(c.dispose);
    c.read(workspaceProvider.notifier).setNodes([node(_id)]);
    containers.add(c);
    return c;
  }

  // The session is not keepAlive: a listener keeps it for the test.
  ProviderSubscription<WarpSessionState> keep(ProviderContainer c) =>
      c.listen(warpEditSessionProvider(_id), (_, _) {});

  WarpEditSession session(ProviderContainer c) =>
      c.read(warpEditSessionProvider(_id).notifier);

  WarpSessionState stateOf(ProviderContainer c) =>
      c.read(warpEditSessionProvider(_id));

  Future<ProviderContainer> opened({WarpBackupStore? store}) async {
    final c = newContainer(store: store);
    keep(c);
    await session(c).open();
    return c;
  }

  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  List<Uint8List> frames() => [for (final (_, f) in fake.sentBinary) f];
  List<Uint8List> writeFrames() => frames().where(_isWrite).toList();
  bool isBusy(ProviderContainer c) =>
      c.read(workspaceProvider.notifier).isNodeBusy(_id);

  List<LogEvent> logRows(ProviderContainer c) => [
    for (final e in c.read(eventLogProvider))
      if (e.nodeId == _id) e,
  ];

  Future<WarpBackup?> storedBackup(WarpSlot slot) =>
      backups.load('$_ip|${_caps.id}', slot);

  group('open', () {
    test('no reply to MIDS1: unsupported, no model', () async {
      fake.rawResponses.remove('QVX:MIDS1');
      final c = await opened();
      expect(stateOf(c).phase, WarpSessionPhase.unsupported);
      expect(stateOf(c).unsupportedReason, WarpUnsupportedReason.noModel);
      expect(frames(), isEmpty);
      expect(isBusy(c), isFalse);
    });

    test('a model that is not in the table: unsupported, no model', () async {
      fake.rawResponses['QVX:MIDS1'] = 'MIDS1=0027:00:26';
      final c = await opened();
      expect(stateOf(c).phase, WarpSessionPhase.unsupported);
      expect(stateOf(c).unsupportedReason, WarpUnsupportedReason.noModel);
    });

    test('an RQ25K-like reply loads PC-1', () async {
      final table = _gridTable(_caps, dx: 40);
      seed(WarpSlot.pc1, table, _caps);
      projector().storedTimes[1] = '20260101120000';
      projector().gridCounts[1] = '5:5';
      final c = await opened();
      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.caps!.id, '001c_00_26');
      expect(s.slot, WarpSlot.pc1);
      expect(s.storedAt, DateTime.utc(2026, 1, 1, 12));
      expect(s.gridCounts, (columns: 5, rows: 5));
      expect(s.gridCountsDefaulted, isFalse);
      expect(s.rawBlock, _blockOf(table, _caps));
      expect(s.readHeader, table.header);
      expect(s.controlGrid, isNotNull);
      expect(s.readOnly, isFalse);
      expect(s.backupTakenAt, isNull);
      expect(isBusy(c), isFalse, reason: 'the claim is given back');
    });

    test('GMMI0 +00004 loads PC-2', () async {
      projector().mode = 4;
      seed(WarpSlot.pc2, _gridTable(_caps, dx: 20), _caps);
      final c = await opened();
      expect(stateOf(c).slot, WarpSlot.pc2);
      expect(stateOf(c).rawBlock, isNotNull);
      expect(fake.sentCommands, isEmpty);
    });

    test('GMMI0 +00000 loads PC-1 and changes nothing', () async {
      projector().mode = 0;
      seed(WarpSlot.pc1, _gridTable(_caps), _caps);
      final c = await opened();
      expect(stateOf(c).slot, WarpSlot.pc1);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(projector().mode, 0);
      expect([
        for (final (_, cmd) in fake.sentRaw)
          if (cmd.startsWith('VXX:GMMI0')) cmd,
      ], isEmpty);
      expect(fake.sentCommands, isEmpty);
      expect(writeFrames(), isEmpty);
    });

    test('an unreadable memory fails and Reload reads it again', () async {
      seed(WarpSlot.pc1, _gridTable(_caps), _caps);
      // The mode and the model are asked first; fail the first READ.
      final c = newContainer();
      keep(c);
      projector().failFrame(0, 0x8C);
      await session(c).open();
      expect(stateOf(c).phase, WarpSessionPhase.failed);
      expect(stateOf(c).failureMessage, contains('PC-1'));
      expect(stateOf(c).table, isNull);
      expect(isBusy(c), isFalse);

      await session(c).reload();
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(stateOf(c).table, isNotNull);
    });

    test('a memory with a colour plane per colour is read-only', () async {
      projector().setBlock(
        warpTypeCode(_caps.fullBase, WarpSlot.pc1) + 1,
        _blockOf(identityWarpTable(_caps.geometry, planes: 3), _caps),
      );
      final c = await opened();
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(stateOf(c).readOnlyReason, WarpReadOnlyReason.colourPlanes);
      expect(stateOf(c).controlGrid, isNull);
      expect(stateOf(c).table!.planes, hasLength(3));
    });
  });

  group('memories that are not there (rule A)', () {
    test(
      'a model with the inverse table, first read FF 8B: unsupported',
      () async {
        fake.rawResponses['QVX:MIDS1'] = _midsWithInverse;
        final c = await opened();
        expect(_capsWithInverse.isNoInverse, isFalse);
        expect(stateOf(c).phase, WarpSessionPhase.unsupported);
        expect(
          stateOf(c).unsupportedReason,
          WarpUnsupportedReason.notAvailable,
        );
        await expectLater(
          session(c).store(
            identityWarpTable(_capsWithInverse.geometry),
            gridColumns: 3,
            gridRows: 3,
          ),
          throwsStateError,
        );
        expect(writeFrames(), isEmpty);
      },
    );

    test(
      'a model without the inverse table, FF 8B: a neutral memory',
      () async {
        expect(_caps.isNoInverse, isTrue);
        final c = await opened();
        final s = stateOf(c);
        expect(s.phase, WarpSessionPhase.ready);
        expect(s.rawBlock, isNull);
        expect(s.readHeader, isNull);
        expect(s.readOnly, isFalse);
        expect(
          s.table!.planes.single.points,
          identityWarpTable(_caps.geometry).planes.single.points,
        );
        expect(s.controlGrid, isNotNull);
        expect(s.residual, 0);
        expect(s.undescribedDetail, isFalse);
        expect(s.gridCountsDefaulted, isTrue);
        expect(s.gridCounts, (columns: 3, rows: 3));
      },
    );

    test('FF 8B after a first good read is a neutral memory', () async {
      fake.rawResponses['QVX:MIDS1'] = _midsWithInverse;
      seed(
        WarpSlot.pc1,
        _gridTable(_capsWithInverse, dx: 10),
        _capsWithInverse,
      );
      final c = await opened();
      expect(stateOf(c).phase, WarpSessionPhase.ready);

      await session(c).selectMemory(WarpSlot.pc2);
      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.slot, WarpSlot.pc2);
      expect(s.rawBlock, isNull);
      expect(s.controlGrid, isNotNull);
    });
  });

  group('a table that does not fit a grid (rule B)', () {
    test('opens read-only and refuses to store', () async {
      seed(WarpSlot.pc1, _shortTable(_caps), _caps);
      final c = await opened();
      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.readOnly, isTrue);
      expect(s.readOnlyReason, WarpReadOnlyReason.fit);
      expect(s.table, isNotNull);
      expect(s.controlGrid, isNull);
      expect(s.residual, isNull);

      await expectLater(
        session(c).store(s.table!, gridColumns: 3, gridRows: 3),
        throwsStateError,
      );
      expect(writeFrames(), isEmpty);
    });
  });

  group('selectMemory', () {
    test('switches the projector to the memory, then reads it', () async {
      seed(WarpSlot.pc3, _gridTable(_caps, dx: 30), _caps);
      final c = await opened();
      fake.sentBinary.clear();
      await session(c).selectMemory(WarpSlot.pc3);

      expect(fake.sentCommands, [(_ip, 'VXX:GMMI0=+00005')]);
      expect(projector().mode, 5);
      expect(stateOf(c).slot, WarpSlot.pc3);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(stateOf(c).rawBlock, isNotNull);
      expect(frames().where(_isRead).map((f) => f[4]).toSet(), {0x76});
    });

    test(
      'a refused switch leaves nothing of the old memory to write',
      () async {
        seed(WarpSlot.pc1, _gridTable(_caps), _caps);
        final c = await opened();
        fake.commandSucceeds[_ip] = false;
        await session(c).selectMemory(WarpSlot.pc2);
        expect(stateOf(c).phase, WarpSessionPhase.failed);
        expect(stateOf(c).slot, WarpSlot.pc2);
        expect(stateOf(c).table, isNull);
        await expectLater(
          session(c).store(_gridTable(_caps), gridColumns: 3, gridRows: 3),
          throwsStateError,
        );
      },
    );
  });

  group('store', () {
    late WarpTable original;
    late Uint8List originalBlock;

    setUp(() {
      original = _gridTable(_caps, dx: 40);
      originalBlock = _blockOf(original, _caps);
      seed(WarpSlot.pc1, original, _caps);
      projector().storedTimes[1] = '20260101120000';
      projector().gridCounts[1] = '5:5';
    });

    test('the backup is on disk before the first frame', () async {
      final c = await opened();
      final gate = Completer<void>();
      fake.holdBinary[_ip] = gate;
      final done = session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      await until(() => writeFrames().isNotEmpty);

      final backup = await storedBackup(WarpSlot.pc1);
      expect(backup, isNotNull, reason: 'saved while the first frame waits');
      expect(backup!.block, originalBlock);
      expect(backup.type, 0x72);
      expect(backup.method, 0);
      expect(backup.modelId, '001c_00_26');
      expect(backup.gridColumns, 5);
      expect(backup.gridRows, 5);
      expect(backup.storedAt, DateTime.utc(2026, 1, 1, 12));
      expect(stateOf(c).phase, WarpSessionPhase.storing);
      expect(isBusy(c), isTrue, reason: 'the poll stays off during a transfer');

      gate.complete();
      await done;
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(stateOf(c).backupTakenAt, backup.takenAt);
      expect(isBusy(c), isFalse);
    });

    test('a store sends the frames, SAVE and both values', () async {
      final c = await opened();
      final next = _gridTable(_caps, dx: -60);
      final before = DateTime.now().toUtc();
      await session(c).store(next, gridColumns: 4, gridRows: 3);

      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.table, same(next));
      expect(s.gridCounts, (columns: 4, rows: 3));
      expect(s.gridCountsDefaulted, isFalse);
      expect(s.lastStoreIncomplete, isFalse);
      expect(s.storedAt!.isBefore(before), isFalse);
      expect(projector().saves, [0xE1]);
      expect(projector().gridCounts[1], '4:3');
      expect(projector().blockOf(0x72), _blockOf(next, _caps));
      expect(projector().blockOf(0x82), isNotNull);
    });

    test('progress runs to the total', () async {
      final c = await opened();
      final seen = <(int, int)>[];
      c.listen(warpEditSessionProvider(_id), (_, next) {
        if (next.phase == WarpSessionPhase.storing) {
          seen.add((next.progressDone, next.progressTotal));
        }
      });
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      expect(seen.last.$2, greaterThan(3));
      expect(seen.last.$1, seen.last.$2);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i].$1, greaterThanOrEqualTo(seen[i - 1].$1));
      }
      expect(stateOf(c).progressDone, 0);
    });

    test('a second store of the session keeps the first backup', () async {
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final first = (await storedBackup(WarpSlot.pc1))!;
      await session(c)
          .store(_gridTable(_caps, dx: 90), gridColumns: 4, gridRows: 3);
      final second = (await storedBackup(WarpSlot.pc1))!;
      expect(second.takenAt, first.takenAt);
      expect(second.block, originalBlock);
    });

    test('a Reload does not make the next store take a new backup', () async {
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final first = (await storedBackup(WarpSlot.pc1))!;
      await session(c).reload();
      await session(c)
          .store(_gridTable(_caps, dx: 90), gridColumns: 4, gridRows: 3);
      expect((await storedBackup(WarpSlot.pc1))!.takenAt, first.takenAt);
    });

    test('the first store of a new session replaces the backup', () async {
      final c1 = await opened();
      final firstTable = _gridTable(_caps, dx: -60);
      await session(c1).store(firstTable, gridColumns: 4, gridRows: 3);
      final first = (await storedBackup(WarpSlot.pc1))!;

      final c2 = await opened();
      expect(stateOf(c2).backupTakenAt, first.takenAt);
      await session(c2)
          .store(_gridTable(_caps, dx: 90), gridColumns: 4, gridRows: 3);
      final second = (await storedBackup(WarpSlot.pc1))!;
      expect(second.takenAt, isNot(first.takenAt));
      expect(second.block, _blockOf(firstTable, _caps));
      expect(second.gridColumns, 4);
      expect(second.gridRows, 3);
    });

    test('each memory gets its backup at its first write', () async {
      seed(WarpSlot.pc2, _gridTable(_caps, dx: 10), _caps);
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 3, gridRows: 3);
      await session(c).selectMemory(WarpSlot.pc2);
      expect(stateOf(c).backupTakenAt, isNull);
      await session(c)
          .store(_gridTable(_caps, dx: 50), gridColumns: 3, gridRows: 3);
      expect((await storedBackup(WarpSlot.pc2))!.block, isNotEmpty);
      expect(stateOf(c).backupTakenAt, isNotNull);
    });

    test('an empty memory is backed up as the neutral table', () async {
      projector().blocks.clear();
      projector().gridCounts.clear();
      projector().storedTimes.clear();
      final c = await opened();
      expect(stateOf(c).rawBlock, isNull);
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final backup = (await storedBackup(WarpSlot.pc1))!;
      expect(backup.block, _blockOf(identityWarpTable(_caps.geometry), _caps));
      expect(backup.type, 0x72);
      expect(backup.method, warpMethodFull);
      expect(backup.gridColumns, isNull);
      expect(backup.storedAt, isNull);
    });

    test('a backup that cannot be saved stops everything', () async {
      final c = await opened(store: _FailingBackups(backups.root));
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      expect(stateOf(c).phase, WarpSessionPhase.failed);
      expect(stateOf(c).failureMessage, contains('backup'));
      expect(stateOf(c).failureMessage, contains('Nothing was sent'));
      expect(writeFrames(), isEmpty);
      expect(frames().where(_isSave), isEmpty);
      expect(isBusy(c), isFalse);
      expect(logRows(c).first.severity, LogSeverity.error);
      expect(logRows(c).first.message, contains('nothing was sent'));
    });

    test('a projector that stays busy for 3 s fails the store', () async {
      final c = await opened();
      final workspace = c.read(workspaceProvider.notifier);
      expect(workspace.claimNodeForExternalPoll(_id), isTrue);
      fakeAsync((async) {
        final done = session(c)
            .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
        async.elapse(const Duration(seconds: 2));
        expect(stateOf(c).phase, WarpSessionPhase.storing);
        async.elapse(const Duration(seconds: 2));
        unawaited(done);
        expect(stateOf(c).phase, WarpSessionPhase.failed);
        expect(
          stateOf(c).failureMessage,
          'Storing PC-1 failed: Projector '
          'busy, try again. Nothing was sent.',
        );
      });
      expect(writeFrames(), isEmpty);
      expect(await storedBackup(WarpSlot.pc1), isNull);
      workspace.releaseNodeFromExternalPoll(_id);
      expect(isBusy(c), isFalse);
    });

    test('FF on the third frame: failed, no SAVE, claim released', () async {
      final c = await opened();
      projector().failFrame(projector().frames.length + 2, 0x8B);
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.failed);
      expect(s.failureMessage, contains('step 3 of'));
      expect(s.failureMessage, contains('Reload'));
      expect(frames().where(_isSave), isEmpty);
      expect(projector().saves, isEmpty);
      expect(projector().gridCounts[1], '5:5');
      expect(isBusy(c), isFalse);
      expect(s.table, same(stateOf(c).table));
      expect(s.backupTakenAt, isNotNull, reason: 'the backup was taken');

      final row = logRows(c).first;
      expect(row.severity, LogSeverity.error);
      expect(
        row.message,
        startsWith('Free grid PC-1 store failed at step 3 of'),
      );
      expect(row.projectorIp, _ip);

      await session(c).reload();
      expect(stateOf(c).phase, WarpSessionPhase.ready);
    });

    test('a node out of range sends nothing and keeps the backup', () async {
      final c = await opened();
      final plane = _gridTable(_caps).planes.single;
      final points = Float64List.fromList(plane.points)..[0] = 9000;
      final bad = WarpTable(
        columns: plane.columns,
        rows: plane.rows,
        header: original.header,
        planes: [
          WarpPlane(
            name: 'W',
            columns: plane.columns,
            rows: plane.rows,
            points: points,
          ),
        ],
      );
      await session(c).store(bad, gridColumns: 3, gridRows: 3);

      expect(stateOf(c).phase, WarpSessionPhase.failed);
      expect(stateOf(c).failureMessage, contains('out of range'));
      expect(stateOf(c).failureMessage, contains('Nothing was sent'));
      expect(writeFrames(), isEmpty);
      expect(await storedBackup(WarpSlot.pc1), isNull);
      expect(isBusy(c), isFalse);
    });

    test('a failed time write is a stored table, flagged incomplete', () async {
      projector().droppedAscii.add('VXX:GDTS1');
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.lastStoreIncomplete, isTrue);
      expect(
        s.storedAt,
        DateTime.utc(2026, 1, 1, 12),
        reason: 'the time in the projector is still the old one',
      );
      expect(s.gridCounts, (columns: 4, rows: 3));
      expect(projector().saves, [0xE1]);
      expect(logRows(c).first.severity, LogSeverity.warning);

      await session(c).reload();
      expect(stateOf(c).lastStoreIncomplete, isFalse);
    });

    test('a second transfer is refused while one runs', () async {
      final c = await opened();
      fake.holdBinary[_ip] = Completer<void>();
      final done = session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      await expectLater(
        session(c).store(_gridTable(_caps), gridColumns: 3, gridRows: 3),
        throwsStateError,
      );
      fake.holdBinary[_ip]!.complete();
      await done;
    });

    test(
      'closing the editor mid-transfer finishes it without a state write',
      () async {
        final c = newContainer();
        final sub = keep(c);
        await session(c).open();
        final gate = Completer<void>();
        fake.holdBinary[_ip] = gate;
        final done = session(c)
            .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
        await until(() => writeFrames().isNotEmpty);
        sub.close();
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        await done;

        expect(projector().saves, [
          0xE1,
        ], reason: 'the memory is not left half written');
        expect(isBusy(c), isFalse);
        expect(logRows(c).single.message, 'Free grid PC-1 stored');
      },
    );

    test('a successful store is one row in the event log', () async {
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final rows = logRows(c);
      expect(rows, hasLength(1));
      expect(rows.single.severity, LogSeverity.success);
      expect(rows.single.message, 'Free grid PC-1 stored');
      expect(rows.single.projectorIp, _ip);
      expect(rows.single.projectorName, 'Proj 1');
      expect(rows.single.type, LogEventType.command);
    });
  });

  // The neutral table of these rows is out of range for their own bits (the
  // outer nodes reach 3840 px, a table of 4 bits holds up to 3072), so the
  // format is not understood and the models are left alone.
  group('a model whose neutral table the format cannot hold', () {
    const unsupportedIds = {
      '0018_00_30': 'MIDS1=0024:00:30',
      '0018_01_30': 'MIDS1=0024:01:30',
      '0018_02_30': 'MIDS1=0024:02:30',
      '001b_00_24': 'MIDS1=0027:00:24',
      '001b_01_24': 'MIDS1=0027:01:24',
    };

    for (final MapEntry(key: id, value: mids) in unsupportedIds.entries) {
      test('$id is unsupported and gets no read', () async {
        fake.rawResponses['QVX:MIDS1'] = mids;
        final c = await opened();
        expect(stateOf(c).caps!.id, id);
        expect(stateOf(c).phase, WarpSessionPhase.unsupported);
        expect(stateOf(c).unsupportedReason, WarpUnsupportedReason.format);
        expect(fake.sentBinary, isEmpty);
        expect(fake.sentRaw.map((r) => r.$2), ['QVX:MIDS1']);
        expect(isBusy(c), isFalse);
        await expectLater(
          session(c).resetToNeutral(gridColumns: 3, gridRows: 3),
          throwsStateError,
        );
      });
    }

    test('the RQ25K and the RZ34KE rows are still supported', () async {
      for (final (mids, id) in [
        ('MIDS1=0028:00:26', '001c_00_26'),
        ('MIDS1=0022:00:26', '0016_00_26'),
      ]) {
        fake.rawResponses['QVX:MIDS1'] = mids;
        final c = await opened();
        expect(stateOf(c).caps!.id, id);
        expect(stateOf(c).phase, WarpSessionPhase.ready);
      }
    });

    test('exactly these rows of the table are unsupported', () {
      expect({
        for (final caps in warpModelCapsTable.values)
          if (!warpModelSupported(caps)) caps.id,
      }, unsupportedIds.keys.toSet());
    });
  });

  group('restoreBackup', () {
    late WarpTable original;

    setUp(() {
      original = _gridTable(_caps, dx: 40);
      seed(WarpSlot.pc1, original, _caps);
      projector().storedTimes[1] = '20260101120000';
      projector().gridCounts[1] = '5:5';
    });

    test('writes the backup through the store sequence', () async {
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      final backup = (await storedBackup(WarpSlot.pc1))!;
      final mark = fake.sentBinary.length;
      fake.sentRaw.clear();

      await session(c).restoreBackup();

      final sent = [for (final (_, f) in fake.sentBinary.skip(mark)) f];
      final writes = sent.where(_isWrite).toList();
      expect(writes.first[6], 0x82, reason: 'the FPGA table goes first');
      expect(writes.map((f) => f[6]).toSet(), {0x82, 0x72});
      expect(sent.where(_isSave), hasLength(1));
      expect(projector().blockOf(0x72), backup.block);
      expect(projector().storedTimes[1], '20260101120000');
      expect(projector().gridCounts[1], '5:5');
      expect(
        fake.sentRaw.map((r) => r.$2),
        contains('QVX:GMMI0'),
        reason: 'the memory is read again',
      );

      final s = stateOf(c);
      expect(s.phase, WarpSessionPhase.ready);
      expect(s.rawBlock, backup.block);
      expect(s.storedAt, DateTime.utc(2026, 1, 1, 12));
      expect(s.gridCounts, (columns: 5, rows: 5));
      expect(s.lastStoreIncomplete, isFalse);
      expect(isBusy(c), isFalse);

      final after = (await storedBackup(WarpSlot.pc1))!;
      expect(after.takenAt, backup.takenAt, reason: 'no new backup');
      expect(after.block, backup.block);

      final row = logRows(c).first;
      expect(row.severity, LogSeverity.success);
      expect(row.message, 'Free grid PC-1 restored from backup');
    });

    test('the default 3 x 3 stands in for unknown counts', () async {
      projector().gridCounts.clear();
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      expect((await storedBackup(WarpSlot.pc1))!.gridColumns, isNull);
      await session(c).restoreBackup();
      expect(projector().gridCounts[1], '3:3');
    });

    test('is refused without a backup', () async {
      final c = await opened();
      await expectLater(session(c).restoreBackup(), throwsStateError);
      expect(writeFrames(), isEmpty);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
    });

    test('a failure is a row with its step', () async {
      final c = await opened();
      await session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      projector().failFrame(projector().frames.length + 1, 0x8C);
      await session(c).restoreBackup();
      expect(stateOf(c).phase, WarpSessionPhase.failed);
      expect(stateOf(c).failureMessage, contains('Restoring PC-1 failed'));
      final row = logRows(c).first;
      expect(row.severity, LogSeverity.error);
      expect(
        row.message,
        startsWith('Free grid PC-1 restore failed at step 2'),
      );
    });
  });

  group('resetToNeutral', () {
    test('writes a neutral table, backed up like any first write', () async {
      final original = _gridTable(_caps, dx: 40);
      seed(WarpSlot.pc1, original, _caps);
      final c = await opened();
      await session(c).resetToNeutral(gridColumns: 3, gridRows: 3);

      final written = decodeTable(
        projector().blockOf(0x72)!,
        WarpEncoding.triple,
        _caps.bits,
      );
      expect(
        written.planes.single.points,
        identityWarpTable(_caps.geometry).planes.single.points,
      );
      expect(projector().saves, [0xE1]);
      expect(
        (await storedBackup(WarpSlot.pc1))!.block,
        _blockOf(original, _caps),
      );
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(logRows(c).first.message, 'Free grid PC-1 reset to neutral');
    });

    test('is allowed for a read-only memory', () async {
      seed(WarpSlot.pc1, _shortTable(_caps), _caps);
      final c = await opened();
      expect(stateOf(c).readOnly, isTrue);
      await session(c).resetToNeutral(gridColumns: 3, gridRows: 3);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(projector().saves, [0xE1]);
    });

    test('a failed reset is a row with its step', () async {
      seed(WarpSlot.pc1, _gridTable(_caps, dx: 40), _caps);
      final c = await opened();
      projector().failFrame(projector().frames.length + 1, 0x8B);
      await session(c).resetToNeutral(gridColumns: 3, gridRows: 3);
      expect(stateOf(c).phase, WarpSessionPhase.failed);
      expect(
        logRows(c).first.message,
        startsWith('Free grid PC-1 reset failed at step 2 of'),
      );
    });
  });

  group('preview', () {
    late List<WarpTable> tables;

    setUp(() {
      seed(WarpSlot.pc1, _gridTable(_caps, dx: 40), _caps);
      tables = [for (var i = 1; i <= 5; i++) _gridTable(_caps, dx: i * 3.0)];
    });

    // First frames of the writes into the live RAM (type 0x80).
    int previewSets() => writeFrames()
        .where((f) => f[6] == 0x80 && (f[8] == 1 || f[8] == 3))
        .length;

    test('five calls in a burst send two sets, the last the latest', () async {
      final c = await opened();
      for (final t in tables) {
        session(c).preview(t);
      }
      await until(() => previewSets() == 2);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(previewSets(), 2);

      final baseline = MemoryWarpLink();
      await writeWarpPreview(baseline, caps: _caps, full: tables.last);
      expect(projector().blockOf(0x80), baseline.projector.blockOf(0x80));
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(stateOf(c).previewError, isNull);
      expect(isBusy(c), isFalse);
    });

    test('is dropped while a store runs', () async {
      final c = await opened();
      final gate = Completer<void>();
      fake.holdBinary[_ip] = gate;
      final done = session(c)
          .store(_gridTable(_caps, dx: -60), gridColumns: 4, gridRows: 3);
      session(c).preview(tables.first);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      gate.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(previewSets(), 0);
    });

    test('an error is shown and a later success clears it', () async {
      final c = await opened();
      projector().failFrame(projector().frames.length, 0x8C);
      session(c).preview(tables[0]);
      await until(() => stateOf(c).previewError != null);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      expect(isBusy(c), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      session(c).preview(tables[1]);
      await until(() => stateOf(c).previewError == null);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
    });

    test('a table out of range is an error, not a crash', () async {
      final c = await opened();
      final plane = tables[0].planes.single;
      final points = Float64List.fromList(plane.points)..[0] = 9000;
      session(c).preview(
        WarpTable(
          columns: plane.columns,
          rows: plane.rows,
          header: tables[0].header,
          planes: [
            WarpPlane(
              name: 'W',
              columns: plane.columns,
              rows: plane.rows,
              points: points,
            ),
          ],
        ),
      );
      await until(() => stateOf(c).previewError != null);
      expect(previewSets(), 0);
    });

    test(
      'a projector held by a poll keeps the latest table for later',
      () async {
        final c = await opened();
        final workspace = c.read(workspaceProvider.notifier);
        expect(workspace.claimNodeForExternalPoll(_id), isTrue);
        session(c).preview(tables[0]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(previewSets(), 0);

        workspace.releaseNodeFromExternalPoll(_id);
        await until(() => previewSets() == 1);
        expect(stateOf(c).previewError, isNull);
      },
    );

    test('closing the session cancels the waiting send', () async {
      final c = newContainer();
      final sub = keep(c);
      await session(c).open();
      session(c).preview(tables[0]);
      await until(() => previewSets() == 1);
      session(c).preview(tables[1]);
      sub.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(previewSets(), 1);
      expect(isBusy(c), isFalse);
    });
  });

  group('overlay', () {
    setUp(() => seed(WarpSlot.pc1, _gridTable(_caps), _caps));

    test('the cursor and the selection go out under the claim', () async {
      final c = await opened();
      final mark = fake.sentBinary.length;
      await session(c).showCursor(on: true, x: 1, y: 2);
      await session(c).sendSelection(x: 1, y: 2, marks: List.filled(9, 0));
      expect(fake.sentBinary.length - mark, 3);
      expect(stateOf(c).previewError, isNull);
      expect(isBusy(c), isFalse);
    });

    test('an error is shown and never changes the phase', () async {
      final c = await opened();
      projector().failFrame(projector().frames.length, 0x8C);
      await session(c).showGridOverlay(on: true, columns: 3, rows: 3, rgb: 7);
      expect(stateOf(c).previewError, isNotNull);
      expect(stateOf(c).phase, WarpSessionPhase.ready);
      await session(c).markPoints(List.filled(9, 1));
      expect(stateOf(c).previewError, isNull);
    });
  });
}
