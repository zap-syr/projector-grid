// QA probes for the Free grid mode of the Geometry Correction dialog (W3a).
// Each test here shows a finding in projector-grid-notes/QA_FINDINGS.md; the
// id is in the test name. They fail until the finding is fixed.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projector_grid/core/services/warp_backup_store.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/free_grid_view.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_backup_store_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_edit_session_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/segmented_tabs.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry/free_grid/free_grid_painter.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_correction_dialog.dart';

import '../helpers/app_fonts.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

const _ip = '10.0.0.1';
const _mids = 'MIDS1=0028:00:26';

// An RQ25K: 3840 x 2400, movable range 1200, 3-byte tables.
final WarpModelCaps _caps = lookupWarpModelCaps('001c_00_26')!;

const _node = ProjectorNode(
  id: '1',
  name: 'PT-RQ25K',
  ipAddress: _ip,
  x: 0,
  y: 0,
);

class _MemoryBackups extends WarpBackupStore {
  _MemoryBackups() : super(Directory('unused'));

  final Map<(String, WarpSlot), WarpBackup> saved = {};

  @override
  Future<WarpBackup?> load(String projectorKey, WarpSlot slot) async =>
      saved[(projectorKey, slot)];

  @override
  Future<void> save(WarpBackup backup) async =>
      saved[(backup.projectorKey, backup.slot)] = backup;

  @override
  Future<void> delete(String projectorKey, WarpSlot slot) async =>
      saved.remove((projectorKey, slot));
}

/// A fake whose next binary call can fail the way the protocol worker does
/// when it dies: a [StateError], not a warp exception.
class _Fake extends FakeProtocolService {
  bool workerFailsNextBinary = false;

  @override
  Future<Uint8List> sendBinaryCommand(
    String ip,
    int port,
    String login,
    String password,
    Uint8List frame,
  ) async {
    if (workerFailsNextBinary) {
      workerFailsNextBinary = false;
      sentBinary.add((ip, frame));
      throw StateError('Protocol worker exited');
    }
    return super.sendBinaryCommand(ip, port, login, password, frame);
  }
}

WarpTable _gridTable({double dx = 0}) {
  final grid = setControlPosition(
    WarpControlGrid.identity(
      columns: 3,
      rows: 3,
      panelWidth: _caps.panelWidth,
      panelHeight: _caps.panelHeight,
    ),
    {4},
    x: _caps.panelWidth / 2 + dx,
    rangeX: _caps.movableRangeX,
    rangeY: _caps.movableRangeY,
  );
  return tableFromControlGrid(grid, _caps.geometry);
}

Uint8List _blockOf(WarpTable table) {
  final e = encodeTable(table, WarpEncoding.triple, _caps.bits);
  return Uint8List.fromList([...e.head, ...e.points]);
}

void _seed(FakeProtocolService fake, WarpSlot slot, WarpTable table) => fake
    .warpFor(_ip)
    .setBlock(warpTypeCode(_caps.fullBase, slot), _blockOf(table));

void main() {
  useTempConfigDir();
  setUpAll(loadAppFonts);

  late _Fake fake;
  late ProviderContainer container;

  setUp(() {
    fake = _Fake();
    fake.rawResponses['QID'] = 'PT-RQ25K';
    fake.rawResponses['QVX:MIDS1'] = _mids;
  });

  void dialogTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(
    WidgetTester tester, {
    int mode = 0,
    Size size = const Size(1920, 1080),
  }) async {
    fake.warpFor(_ip).mode = mode;
    container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        warpBackupStoreProvider.overrideWithValue(_MemoryBackups()),
      ],
    );
    container.read(workspaceProvider.notifier).setNodes([_node]);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const GeometryCorrectionDialog(node: _node),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder tileOf(String label) => find.byWidgetPredicate(
    (w) => w is ModeTile && w.label == label,
    description: 'tile $label',
  );

  String selectedTile(WidgetTester tester) => tester
      .widgetList<ModeTile>(find.byType(ModeTile))
      .singleWhere((t) => t.selected)
      .label;

  final reloadButton = find.byKey(const ValueKey('free-grid-reload'));
  final overlaySwitch = find.byKey(const ValueKey('free-grid-switch-overlay'));

  List<Uint8List> overlayFrames() => [
    for (final (_, f) in fake.sentBinary)
      if (f.length > 4 && f[2] == 0xAB && f[3] == 0x07) f,
  ];

  WarpSessionState session() =>
      container.read(warpEditSessionProvider(_node.id));

  WorkspaceNotifier workspace() => container.read(workspaceProvider.notifier);

  // ------------------------------------------------------------- QA-001

  group('QA-001 the overlay off is dropped once no memory is loaded', () {
    dialogTest('QA-001 leaving the mode after a failed Reload takes the '
        'overlay off', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(overlaySwitch);
      await settle(tester);
      expect(overlayFrames().last[4], 1);

      // The next read fails: the session forgets the table.
      fake.warpFor(_ip).corruptReadChecksum = true;
      await tester.tap(reloadButton);
      await settle(tester);
      expect(session().phase, WarpSessionPhase.failed);
      expect(session().table, isNull);

      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      expect(selectedTile(tester), 'Keystone');
      expect(
        overlayFrames().last[4],
        0,
        reason: 'the projector still shows the grid overlay',
      );
    });

    dialogTest('QA-001 closing the dialog after a failed memory switch takes '
        'the overlay off', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(overlaySwitch);
      await settle(tester);
      expect(overlayFrames().last[4], 1);

      // PC-2 is switched to but its read fails.
      _seed(fake, WarpSlot.pc2, _gridTable(dx: 40));
      fake.warpFor(_ip).corruptReadChecksum = true;
      await tester.tap(find.text('PC-2'));
      await settle(tester);
      expect(session().table, isNull);

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
      expect(
        overlayFrames().last[4],
        0,
        reason: 'the projector still shows the grid overlay',
      );
    });
  });

  // ------------------------------------------------------------- QA-002

  dialogTest('QA-002 closing the dialog while a poll holds the projector for '
      'over a second still takes the overlay off', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);
    expect(overlayFrames().last[4], 1);

    // A regular poll of a slow projector holds the node for 1.5 s.
    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    workspace().releaseNodeFromExternalPoll(_node.id);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(find.byType(GeometryCorrectionDialog), findsNothing);
    expect(
      overlayFrames().last[4],
      0,
      reason: 'the off command gave up after 1 s and was never retried',
    );
  });

  // ------------------------------------------------------------- QA-003

  group('QA-003 leaving the Free grid while a GMMI0 switch waits', () {
    dialogTest('QA-003 tile then Keystone while a poll runs: the projector '
        'ends in Keystone', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 0);

      // A poll is in flight: the session's switch waits for it.
      expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
      await tester.tap(tileOf('Free grid'));
      await tester.pump(const Duration(milliseconds: 50));
      // The other tiles wait while the session reads, so no GMMI0 of the
      // dialog can race the session's (this probe used to click Keystone
      // here and expect it to win; now the click is refused, and the
      // projector and the tiles agree once the session is done).
      expect(
        tester.widget<ModeTile>(tileOf('Keystone')).onTap,
        isNull,
        reason: 'the tile must be disabled while the session switches',
      );
      await tester.tap(tileOf('Keystone'));
      await tester.pump(const Duration(milliseconds: 50));
      workspace().releaseNodeFromExternalPoll(_node.id);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      expect(selectedTile(tester), 'Free grid');
      expect(
        fake.warpFor(_ip).mode,
        3,
        reason: 'the dialog and the projector agree',
      );

      // Once it is done the mode can be left, and the projector follows.
      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      expect(selectedTile(tester), 'Keystone');
      expect(fake.warpFor(_ip).mode, 1);
    });

    dialogTest('QA-003 PC-2 then Keystone while a poll runs: the projector '
        'ends in Keystone', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      _seed(fake, WarpSlot.pc2, _gridTable(dx: 40));
      await openDialog(tester, mode: 3);

      expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
      await tester.tap(find.text('PC-2'));
      await tester.pump(const Duration(milliseconds: 50));
      // As above: the other tiles and the memory segments wait, instead of
      // Keystone winning the race.
      expect(tester.widget<ModeTile>(tileOf('Keystone')).onTap, isNull);
      // The controls are a skeleton while it reads: no segment to click.
      expect(find.byType(SegmentedTabs<WarpSlot?>), findsNothing);
      await tester.tap(tileOf('Keystone'));
      await tester.pump(const Duration(milliseconds: 50));
      workspace().releaseNodeFromExternalPoll(_node.id);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      expect(selectedTile(tester), 'Free grid');
      expect(fake.warpFor(_ip).mode, 4);

      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      expect(selectedTile(tester), 'Keystone');
      expect(fake.warpFor(_ip).mode, 1);
    });
  });

  // ------------------------------------------------------------- QA-004

  group('QA-004 Reload after a failed GMMI0 switch', () {
    dialogTest('QA-004 from the tile: Reload shows PC-1 as ready while the '
        'projector is still Off', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: 40));
      await openDialog(tester, mode: 0);
      fake.warpFor(_ip).droppedAscii.add('VXX:GMMI0');
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(session().phase, WarpSessionPhase.failed);
      expect(fake.warpFor(_ip).mode, 0);

      // The projector answers again; the operator presses Reload.
      fake.warpFor(_ip).droppedAscii.clear();
      await tester.tap(reloadButton);
      await settle(tester);
      final s = session();
      expect(
        s.phase == WarpSessionPhase.ready ? fake.warpFor(_ip).mode : 3,
        3,
        reason:
            'Reload read PC-1 and shows it ready, but never switched the '
            'projector: it is still in mode ${fake.warpFor(_ip).mode}',
      );
    });

    dialogTest('QA-004 from a segment: Reload shows PC-2 as ready while the '
        'projector is still in PC-1', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      _seed(fake, WarpSlot.pc2, _gridTable(dx: 40));
      await openDialog(tester, mode: 3);
      fake.warpFor(_ip).droppedAscii.add('VXX:GMMI0');
      await tester.tap(find.text('PC-2'));
      await settle(tester);
      expect(session().phase, WarpSessionPhase.failed);
      expect(session().slot, WarpSlot.pc2);

      fake.warpFor(_ip).droppedAscii.clear();
      await tester.tap(reloadButton);
      await settle(tester);
      final s = session();
      expect(
        s.phase == WarpSessionPhase.ready ? fake.warpFor(_ip).mode : 4,
        4,
        reason:
            'PC-2 is shown ready, Reset / Store would write PC-2, but the '
            'projector still shows PC-1',
      );
    });
  });

  // ------------------------------------------------------------- QA-005

  group('QA-005 a model whose memories turn out not to be available', () {
    // 0x000a (10): no GEO_IS_NO_INVERSE; an FF 8B on the first read means
    // the model has no free grid memories.
    const noInverseMids = 'MIDS1=0010:00:26';

    dialogTest('QA-005 the tile click leaves the projector in its mode', (
      tester,
    ) async {
      expect(lookupWarpModelCaps('000a_00_26')!.isNoInverse, isFalse);
      fake.rawResponses['QVX:MIDS1'] = noInverseMids;
      await openDialog(tester, mode: 0);
      expect(
        find.byWidgetPredicate((w) => w is ModeTile && w.label == 'Free grid'),
        findsOneWidget,
      );
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(session().phase, WarpSessionPhase.unsupported);
      expect(
        fake.warpFor(_ip).mode,
        0,
        reason:
            'GMMI0 was switched to PC-1 before the read found the model '
            'unsupported, and nothing switched it back',
      );
    });

    dialogTest('QA-005 the unsupported state explains itself', (tester) async {
      fake.rawResponses['QVX:MIDS1'] = noInverseMids;
      await openDialog(tester, mode: 0);
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(session().phase, WarpSessionPhase.unsupported);
      expect(
        find.text('Could not read PC-1'),
        findsNothing,
        reason:
            'an unsupported model is shown as a failed read with an empty '
            'detail line, and Reload does nothing',
      );
    });
  });

  // ------------------------------------------------------------- QA-006

  group('QA-006 a worker isolate failure', () {
    dialogTest('QA-006 during a read: the session does not stay in loading', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.workerFailsNextBinary = true;
      await tester.tap(reloadButton);
      // Not pumpAndSettle: a stuck read keeps its skeleton pulsing forever.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final error = tester.takeException();
      expect(
        session().phase,
        WarpSessionPhase.failed,
        reason:
            'phase is ${session().phase}: the skeleton stays and Reload is '
            'gone (uncaught: $error)',
      );
      expect(reloadButton, findsOneWidget);
    });

    dialogTest('QA-006 on an overlay send: later overlay commands and leaving '
        'the mode still work', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(overlaySwitch);
      await settle(tester);
      expect(overlayFrames(), hasLength(1));

      // A colour change hits a dying worker.
      fake.workerFailsNextBinary = true;
      await tester.tap(find.byKey(const ValueKey('free-grid-swatch-Red')));
      await settle(tester);
      tester.takeException();

      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      final error = tester.takeException();
      expect(
        selectedTile(tester),
        'Keystone',
        reason: 'the mode cannot be left (uncaught: $error)',
      );
      expect(
        overlayFrames().last[4],
        0,
        reason: 'the overlay chain is poisoned: nothing more is sent',
      );
    });
  });

  // ------------------------------------------------------------- QA-007

  dialogTest('QA-007 an ER401 to GMMI0 in a read names no "null"', (
    tester,
  ) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    fake.rawResponsesByIp[_ip] = {'QVX:GMMI0': 'ER401'};
    await tester.tap(reloadButton);
    await settle(tester);
    expect(session().phase, WarpSessionPhase.failed);
    expect(
      session().failureMessage,
      isNot(contains('null')),
      reason: 'the operator reads: ${session().failureMessage}',
    );
  });

  // ------------------------------------------------------------- QA-008

  /// A window whose dialog is 720 x 510: the smallest the app gives it.
  const minimum = Size(800, 590);

  for (final (name, size) in [('minimum', minimum)]) {
    dialogTest('QA-008 the zoom cluster does not cover a control point at the '
        'first view ($name window)', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: size);
      final paint = find.byKey(const ValueKey('free-grid-paint'));
      final p = tester.widget<CustomPaint>(paint).painter! as FreeGridPainter;
      final origin = tester.getTopLeft(paint);
      final cluster = tester.getRect(
        find.byKey(const ValueKey('free-grid-zoom-cluster')),
      );
      final grid = p.grid!;
      final covered = [
        for (var i = 0; i < grid.points.length ~/ 2; i++)
          // A point is a circle of the point radius plus its 1 px outline.
          if (cluster
              .inflate(freeGridPointRadius(grid.columns) + 1)
              .contains(
                origin +
                    p.view.toScreen(
                      Offset(grid.points[2 * i], grid.points[2 * i + 1]),
                    ),
              ))
            i,
      ];
      expect(
        covered,
        isEmpty,
        reason: 'control points under the zoom cluster: $covered',
      );
    });
  }

  // ------------------------------------------------------------- QA-009

  dialogTest('QA-009 a read-only memory warns at the minimum window too', (
    tester,
  ) async {
    _seed(fake, WarpSlot.pc1, identityWarpTable(_caps.geometry, planes: 3));
    await openDialog(tester, mode: 3, size: minimum);
    expect(session().readOnly, isTrue);
    expect(
      find.text(
        // Spelled "color" now (UI-R-13), and shown in the footer's message
        // slot (UI-R-2): the compact card has no note line.
        'This memory holds one table per color, the editor cannot change it.',
      ),
      findsOneWidget,
      reason:
          'the note line, warnings included, is dropped in a compact canvas '
          'card',
    );
  });
}
