import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/warp_backup_store.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_backup_store_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_edit_session_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _ip = '10.0.0.1';

final WarpModelCaps _caps = lookupWarpModelCaps('001c_00_26')!;

class _MemoryBackups extends WarpBackupStore {
  _MemoryBackups() : super(Directory('unused'));

  @override
  Future<WarpBackup?> load(String projectorKey, WarpSlot slot) async => null;

  @override
  Future<void> save(WarpBackup backup) async {}
}

/// Remembers when the overlay-off frames went out, to tell whether the window
/// was destroyed by then.
class _Fake extends FakeProtocolService {
  late bool Function() destroyed;
  final List<bool> offFramesAfterDestroy = [];

  @override
  Future<Uint8List> sendBinaryCommand(
    String ip,
    int port,
    String login,
    String password,
    Uint8List frame,
  ) {
    if (frame.length > 4 && frame[2] == 0xAB && frame[4] == 0) {
      offFramesAfterDestroy.add(destroyed());
    }
    return super.sendBinaryCommand(ip, port, login, password, frame);
  }
}

WarpTable _gridTable() {
  final grid = WarpControlGrid.identity(
    columns: 3,
    rows: 3,
    panelWidth: _caps.panelWidth,
    panelHeight: _caps.panelHeight,
  );
  return tableFromControlGrid(grid, _caps.geometry);
}

/// Closing the app window while a free grid session has something to settle:
/// `onWindowClose` waits for it before it destroys the window.
void main() {
  useTempConfigDir();

  late _Fake fake;

  setUp(() {
    fake = _Fake()
      ..rawResponses['QVX:MIDS1'] = 'MIDS1=0028:00:26'
      ..rawResponses['QID'] = 'PT-RQ25K';
    final table = _gridTable();
    final e = encodeTable(table, WarpEncoding.triple, _caps.bits);
    fake
        .warpFor(_ip)
        .setBlock(
          warpTypeCode(_caps.fullBase, WarpSlot.pc1),
          Uint8List.fromList([...e.head, ...e.points]),
        );
    fake.warpFor(_ip).mode = 3;
  });

  Future<ProviderContainer> start(
    WidgetTester tester,
    List<String> calls,
  ) async {
    final list = await pumpApp(
      tester,
      fake,
      overrides: [warpBackupStoreProvider.overrideWithValue(_MemoryBackups())],
    );
    calls
      ..clear()
      ..addAll(list);
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setNodes([node('1')]);
    await tester.pumpAndSettle();
    return c;
  }

  /// Opens a session on projector 1 and keeps it, as an open dialog does.
  Future<WarpEditSession> openSession(
    WidgetTester tester,
    ProviderContainer c,
  ) async {
    final provider = warpEditSessionProvider('1');
    c.listen(provider, (_, _) {});
    final session = c.read(provider.notifier);
    unawaited(session.open());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (c.read(provider).phase == WarpSessionPhase.ready) break;
    }
    expect(c.read(provider).phase, WarpSessionPhase.ready);
    return session;
  }

  /// The window's close, answering the unsaved-changes question (the nodes
  /// these tests add make the project dirty) with Discard.
  Future<void> closeWindow(WidgetTester tester) async {
    await sendWindowEvent(tester, 'close');
    if (find.text('Discard').evaluate().isNotEmpty) {
      await tester.tap(find.text('Discard'));
      await tester.pump();
    }
  }

  testWidgets('with no session open it closes at once', (tester) async {
    final calls = await pumpApp(tester, fake);
    await closeWindow(tester);
    expect(calls, contains('destroy'));
    expect(fake.sentBinary, isEmpty);
  });

  testWidgets('with a session that has nothing to settle it closes at once', (
    tester,
  ) async {
    final calls = <String>[];
    final c = await start(tester, calls);
    await openSession(tester, c);
    final mark = fake.sentBinary.length;
    await closeWindow(tester);
    expect(fake.sentBinary.length, mark);
  });

  testWidgets('the overlay goes off before the window is destroyed', (
    tester,
  ) async {
    final calls = <String>[];
    final list = await pumpApp(
      tester,
      fake,
      overrides: [warpBackupStoreProvider.overrideWithValue(_MemoryBackups())],
    );
    fake.destroyed = () => list.contains('destroy');
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setNodes([node('1')]);
    await tester.pumpAndSettle();
    final session = await openSession(tester, c);
    await session.showGridOverlay(on: true, columns: 3, rows: 3, rgb: 7);
    await session.showCursor(on: true, x: 1, y: 1);
    calls.addAll(list);
    expect(list, isNot(contains('destroy')));

    await closeWindow(tester);
    for (var i = 0; i < 60 && !list.contains('destroy'); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(list, contains('destroy'));
    expect(
      fake.offFramesAfterDestroy,
      isNotEmpty,
      reason: 'the overlay off was sent',
    );
    expect(
      fake.offFramesAfterDestroy,
      everyElement(isFalse),
      reason: 'before the window was destroyed',
    );
    expect(session.overlayMayBeOn(), isFalse);
  });

  testWidgets('a write that runs is waited for, then the window goes', (
    tester,
  ) async {
    final list = await pumpApp(
      tester,
      fake,
      overrides: [warpBackupStoreProvider.overrideWithValue(_MemoryBackups())],
    );
    fake.destroyed = () => list.contains('destroy');
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setNodes([node('1')]);
    await tester.pumpAndSettle();
    final session = await openSession(tester, c);
    await session.showGridOverlay(on: true, columns: 3, rows: 3, rgb: 7);

    final held = Completer<void>();
    fake.holdBinary[_ip] = held;
    unawaited(session.resetToNeutral(gridColumns: 3, gridRows: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      c.read(warpEditSessionProvider('1')).phase,
      WarpSessionPhase.storing,
    );

    await closeWindow(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(list, isNot(contains('destroy')), reason: 'the write still runs');

    fake.holdBinary.remove(_ip)!.complete();
    for (var i = 0; i < 40 && !list.contains('destroy'); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(list, contains('destroy'));
    expect(
      fake.warpFor(_ip).saves,
      isNotEmpty,
      reason: 'the write was not cut: SAVE went out',
    );
    expect(fake.offFramesAfterDestroy, everyElement(isFalse));
    expect(fake.offFramesAfterDestroy, isNotEmpty);
  });

  testWidgets('a write that never ends does not hold the window for ever', (
    tester,
  ) async {
    final list = await pumpApp(
      tester,
      fake,
      overrides: [warpBackupStoreProvider.overrideWithValue(_MemoryBackups())],
    );
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setNodes([node('1')]);
    await tester.pumpAndSettle();
    final session = await openSession(tester, c);
    final held = Completer<void>();
    fake.holdBinary[_ip] = held;
    unawaited(session.resetToNeutral(gridColumns: 3, gridRows: 3));
    await tester.pump(const Duration(milliseconds: 100));

    await closeWindow(tester);
    for (var i = 0; i < 110 && !list.contains('destroy'); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(list, contains('destroy'), reason: 'after about 10 s');
    held.complete();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
