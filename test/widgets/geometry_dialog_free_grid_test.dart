import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projector_grid/core/services/warp_backup_store.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_backup_store_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/confirm_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/segmented_tabs.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/skeleton.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_tooltip.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/dialog_title_bar.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry/free_grid/free_grid_canvas_card.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry/free_grid/free_grid_controls_card.dart';
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

/// Backups in memory: real file reads never finish under a widget test's
/// fake clock.
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

/// A fake that records the order of the commands that matter, and that can
/// hold one binary frame, to look at a dialog in the middle of a transfer.
class _Fake extends FakeProtocolService {
  final List<String> timeline = [];
  int _binaryCalls = 0;
  int? _holdAt;
  Completer<void>? _gate;

  /// Holds the binary frame that is [calls] frames from now until
  /// [release].
  void holdFrameAfter(int calls) {
    _holdAt = _binaryCalls + calls;
    _gate = Completer<void>();
  }

  void release() => _gate?.complete();

  @override
  Future<Uint8List> sendBinaryCommand(
    String ip,
    int port,
    String login,
    String password,
    Uint8List frame,
  ) async {
    _binaryCalls++;
    if (frame.length > 4 && frame[2] == 0xAB && frame[3] == 0x07) {
      timeline.add('overlay ${frame[4] == 1 ? 'on' : 'off'}');
    }
    if (_binaryCalls == _holdAt) await _gate!.future;
    return super.sendBinaryCommand(ip, port, login, password, frame);
  }

  @override
  Future<bool> sendCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) {
    if (cmd.startsWith('VXX:GMMI0')) timeline.add(cmd);
    return super.sendCommand(ip, port, login, password, cmd);
  }

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) {
    if (cmd.startsWith('VXX:GMMI0')) timeline.add(cmd);
    return super.sendRawCommand(ip, port, login, password, cmd);
  }
}

WarpTable _gridTable({double dx = 0, int columns = 3, int rows = 3}) {
  final grid = setControlPosition(
    WarpControlGrid.identity(
      columns: columns,
      rows: rows,
      panelWidth: _caps.panelWidth,
      panelHeight: _caps.panelHeight,
    ),
    {(columns * rows) ~/ 2},
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
  // The real fonts, so a row is as wide as it is in the app.
  setUpAll(loadAppFonts);

  late _Fake fake;
  late ProviderContainer container;

  setUp(() {
    fake = _Fake();
    fake.rawResponses['QID'] = 'PT-RQ25K';
    fake.rawResponses['QVX:MIDS1'] = _mids;
  });

  /// A widget test that ends with the app gone: the workspace's poll timer
  /// belongs to the container, and a test may not end with a timer pending.
  void dialogTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    });
  }

  const full = Size(1920, 1080);

  /// A window whose dialog is 720 x 510: the smallest the app gives it.
  const minimum = Size(800, 590);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(
    WidgetTester tester, {
    int mode = 0,
    Size size = full,
    ThemeData? theme,
    bool settleAll = true,
  }) async {
    fake.warpFor(_ip).mode = mode;
    fake.rawResponses['QVX:GMMI0'] = null;
    fake.rawResponses.remove('QVX:GMMI0');
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
          theme: theme ?? AppTheme.darkTheme,
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
    if (settleAll) await settle(tester);
  }

  // ---------------------------------------------------------------- finders

  Finder tileOf(String label) => find.byWidgetPredicate(
    (w) => w is ModeTile && w.label == label,
    description: 'tile $label',
  );

  List<String> tileLabels(WidgetTester tester) => [
    for (final t in tester.widgetList<ModeTile>(find.byType(ModeTile))) t.label,
  ];

  String selectedTile(WidgetTester tester) => tester
      .widgetList<ModeTile>(find.byType(ModeTile))
      .singleWhere((t) => t.selected)
      .label;

  WarpSlot? selectedSlot(WidgetTester tester) => tester
      .widget<SegmentedTabs<WarpSlot?>>(find.byType(SegmentedTabs<WarpSlot?>))
      .selected;

  final tilesKey = find.byKey(const ValueKey('geometry-mode-tiles'));
  final storeButton = find.byKey(const ValueKey('free-grid-store'));
  final reloadButton = find.byKey(const ValueKey('free-grid-reload'));
  final moreButton = find.byKey(const ValueKey('free-grid-memory-more'));

  FreeGridPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('free-grid-paint')),
              )
              .painter!
          as FreeGridPainter;

  List<Uint8List> overlayFrames() => [
    for (final (_, f) in fake.sentBinary)
      if (f.length > 4 && f[2] == 0xAB && f[3] == 0x07) f,
  ];

  List<String> gmmiWrites() => [
    for (final (_, cmd) in [...fake.sentCommands, ...fake.sentRaw])
      if (cmd.startsWith('VXX:GMMI0')) cmd,
  ];

  Future<void> openMemoryMenu(WidgetTester tester) async {
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
  }

  MenuItemButton menuItem(WidgetTester tester, String key) =>
      tester.widget<MenuItemButton>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(MenuItemButton),
        ),
      );

  Future<void> resetTo(WidgetTester tester) async {
    await openMemoryMenu(tester);
    await tester.tap(find.byKey(const ValueKey('free-grid-menu-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PC-1'));
  }

  // ------------------------------------------------------------------ tile

  group('the Free grid tile', () {
    dialogTest('is shown after Corner Correction for a supported model', (
      tester,
    ) async {
      await openDialog(tester);
      expect(tileLabels(tester), [
        'Off',
        'Keystone',
        'Curved Correction',
        'Corner Correction',
        'Free grid',
      ]);
      expect(selectedTile(tester), 'Off');
    });

    for (final (name, mids) in [
      ('no reply to MIDS1', null),
      ('a model that is not in the table', 'MIDS1=0027:00:26'),
      ('a model whose format is not understood', 'MIDS1=0024:00:30'),
    ]) {
      dialogTest('is not shown for $name', (tester) async {
        fake.rawResponses['QVX:MIDS1'] = mids;
        await openDialog(tester);
        expect(tileLabels(tester), [
          'Off',
          'Keystone',
          'Curved Correction',
          'Corner Correction',
        ]);
        expect(fake.sentBinary, isEmpty);
      });
    }

    dialogTest('a projector in PC-1 of such a model shows as Off', (
      tester,
    ) async {
      fake.rawResponses['QVX:MIDS1'] = null;
      await openDialog(tester, mode: 3);
      expect(selectedTile(tester), 'Off');
      expect(find.text('Geometry correction is off'), findsOneWidget);
    });

    dialogTest('the tiles are a skeleton of five until MIDS1 is read', (
      tester,
    ) async {
      fake.holdRaw[_ip] = Completer<void>();
      await openDialog(tester, settleAll: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ModeTile), findsNothing);
      expect(
        find.descendant(of: tilesKey, matching: find.byType(Skeleton)),
        findsNWidgets(5),
      );
      fake.holdRaw[_ip]!.complete();
      await settle(tester);
      expect(find.byType(ModeTile), findsNWidgets(5));
    });

    dialogTest('short labels below 860 px, Free grid is never shortened', (
      tester,
    ) async {
      // A 960 px window gives a dialog of 880 and a tile row of 832.
      await openDialog(tester, size: const Size(960, 1080));
      expect(tester.getSize(tilesKey).width, lessThan(860));
      expect(tileLabels(tester), [
        'Off',
        'Keystone',
        'Curved',
        'Corner',
        'Free grid',
      ]);
    });

    dialogTest('full labels from 860 px', (tester) async {
      await openDialog(tester);
      expect(tester.getSize(tilesKey).width, 872);
      expect(tileLabels(tester), contains('Corner Correction'));
    });

    dialogTest('a projector in PC-2 opens on the tile and the PC-2 memory '
        'without writing', (tester) async {
      _seed(fake, WarpSlot.pc2, _gridTable(dx: 30));
      await openDialog(tester, mode: 4);
      expect(selectedTile(tester), 'Free grid');
      expect(selectedSlot(tester), WarpSlot.pc2);
      expect(find.text('Control points'), findsOneWidget);
      expect(gmmiWrites(), isEmpty);
      expect(
        [
          for (final (_, cmd) in fake.sentRaw)
            if (cmd.startsWith('VXX:')) cmd,
        ],
        isEmpty,
        reason: 'opening the dialog writes nothing',
      );
      expect(fake.sentCommands, isEmpty);
      // Only reads went to the projector.
      expect(fake.sentBinary, isNotEmpty);
      expect({for (final (_, f) in fake.sentBinary) f[2]}, {0xA8});
    });

    dialogTest('opening on a projector that is Off writes nothing', (
      tester,
    ) async {
      await openDialog(tester, mode: 0);
      expect(fake.sentCommands, isEmpty);
      expect(fake.sentBinary, isEmpty);
      expect([
        for (final (_, cmd) in fake.sentRaw)
          if (cmd.startsWith('VXX:')) cmd,
      ], isEmpty);
    });

    dialogTest('clicking it from Off writes GMMI0 once and loads PC-1', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: 40));
      await openDialog(tester);
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(gmmiWrites(), ['VXX:GMMI0=+00003']);
      expect(fake.warpFor(_ip).mode, 3);
      expect(selectedTile(tester), 'Free grid');
      expect(selectedSlot(tester), WarpSlot.pc1);
      expect(find.text('Control points'), findsOneWidget);
      expect(painter(tester).grid, isNotNull);
    });

    dialogTest('clicking PC-3 switches the projector and reads it', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      _seed(fake, WarpSlot.pc3, _gridTable(dx: 70));
      await openDialog(tester, mode: 3);
      expect(gmmiWrites(), isEmpty);
      await tester.tap(find.text('PC-3'));
      await settle(tester);
      expect(gmmiWrites(), ['VXX:GMMI0=+00005']);
      expect(selectedSlot(tester), WarpSlot.pc3);
      expect(fake.warpFor(_ip).mode, 5);
      expect(painter(tester).grid, isNotNull);
      expect(
        tester
            .widget<CustomTooltip>(
              find.descendant(
                of: reloadButton,
                matching: find.byType(CustomTooltip),
              ),
            )
            .message,
        'Reload PC-3 from the projector',
      );
    });

    dialogTest('coming back to the mode takes the memory it was on', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc2, _gridTable());
      await openDialog(tester, mode: 4);
      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      expect(selectedTile(tester), 'Keystone');
      fake.timeline.clear();
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      // One write, for the memory the session was on.
      expect(fake.timeline.where((e) => e.startsWith('VXX:GMMI0')), [
        'VXX:GMMI0=+00004',
      ]);
      expect(selectedSlot(tester), WarpSlot.pc2);
    });
  });

  // ---------------------------------------------------------------- layout

  group('layout', () {
    dialogTest('560 + 16 + 296 at the full size', (tester) async {
      await openDialog(tester, mode: 3);
      expect(tester.getSize(find.byKey(freeGridCanvasCardKey)).width, 560);
      expect(tester.getSize(find.byKey(freeGridControlsCardKey)).width, 296);
      final canvas = tester.getRect(find.byKey(freeGridCanvasCardKey));
      final controls = tester.getRect(find.byKey(freeGridControlsCardKey));
      expect(controls.left - canvas.right, 16);
    });

    dialogTest('at the smallest window the canvas takes the rest', (
      tester,
    ) async {
      await openDialog(tester, mode: 3, size: minimum);
      final dialog = tester.getSize(find.byType(DialogTitleBar));
      expect(dialog.width, 720);
      expect(tester.getSize(find.byKey(freeGridControlsCardKey)).width, 296);
      // The body keeps the 24 px every mode has: 720 - 48 - 16 - 296.
      expect(tester.getSize(find.byKey(freeGridCanvasCardKey)).width, 360);
      expect(tester.takeException(), isNull);
    });

    dialogTest('the other modes keep their own split', (tester) async {
      await openDialog(tester);
      await tester.tap(tileOf('Corner Correction'));
      await settle(tester);
      expect(find.byKey(freeGridCanvasCardKey), findsNothing);
    });

    dialogTest('the title bar, the tiles and the footer do not move between '
        'Off, Keystone and the Free grid', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester);
      Rect rect(Finder f) => tester.getRect(f);
      final bar = rect(find.byType(DialogTitleBar));
      final tiles = rect(tilesKey);
      final footer = rect(find.byType(DialogFooter));

      void same() {
        expect(rect(find.byType(DialogTitleBar)), bar);
        expect(rect(tilesKey), tiles);
        expect(rect(find.byType(DialogFooter)), footer);
      }

      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      same();
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      same();
      await tester.tap(tileOf('Off'));
      await settle(tester);
      same();
    });

    dialogTest('and not between loading, ready and storing', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      Rect rect(Finder f) => tester.getRect(f);
      final bar = rect(find.byType(DialogTitleBar));
      final tiles = rect(tilesKey);
      final footer = rect(find.byType(DialogFooter));
      final button = rect(storeButton);
      final canvasCard = rect(find.byKey(freeGridCanvasCardKey));
      final controlsCard = rect(find.byKey(freeGridControlsCardKey));
      final canvasBody = rect(find.byKey(const ValueKey('free-grid-paint')));

      void same({bool body = true}) {
        expect(rect(find.byType(DialogTitleBar)), bar);
        expect(rect(tilesKey), tiles);
        expect(rect(find.byType(DialogFooter)), footer);
        expect(rect(storeButton), button);
        expect(rect(find.byKey(freeGridCanvasCardKey)), canvasCard);
        expect(rect(find.byKey(freeGridControlsCardKey)), controlsCard);
        if (body) {
          expect(
            rect(find.byKey(const ValueKey('free-grid-paint'))),
            canvasBody,
          );
        }
      }

      // Loading: a read that does not answer.
      fake.holdBinary[_ip] = Completer<void>();
      await tester.tap(reloadButton);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Reading PC-1 from the projector'), findsNWidgets(2));
      same(body: false);
      fake.holdBinary[_ip]!.complete();
      await settle(tester);
      same();

      // Storing: a write stopped on its third frame.
      fake.holdFrameAfter(3);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byKey(const ValueKey('free-grid-storing-chip')),
        findsOneWidget,
      );
      same();
      fake.release();
      await settle(tester);
      same();
    });

    dialogTest('the Store button keeps its width while it reads Storing', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final idle = tester.getSize(storeButton);
      expect(
        find.descendant(of: storeButton, matching: find.text('Store to PC-1')),
        findsWidgets,
      );
      expect(idle.width, greaterThanOrEqualTo(150));
      fake.holdFrameAfter(2);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(of: storeButton, matching: find.text('Storing')),
        findsOneWidget,
      );
      expect(tester.getSize(storeButton), idle);
      fake.release();
      await settle(tester);
      expect(tester.getSize(storeButton), idle);
    });

    dialogTest('Store is disabled: nothing has changed', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(tester.widget<FilledButton>(storeButton).onPressed, isNull);
      expect(find.text('Store to PC-1'), findsWidgets);
    });

    dialogTest('the footer says what is going on', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(
        find.text('Edits show on the projector live, Store keeps them in PC-1'),
        findsOneWidget,
      );
      fake.holdFrameAfter(3);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Storing to PC-1, about 1 second'), findsOneWidget);
      fake.release();
      await settle(tester);
    });

    dialogTest('a failed write is a line in the footer, in the error colour', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      // The READ frames are done; fail the second frame of the write.
      fake.warpFor(_ip).failFrame(fake.warpFor(_ip).frames.length + 1, 0x8C);
      await resetTo(tester);
      await settle(tester);
      final line = find.textContaining('Resetting PC-1 failed');
      expect(line, findsOneWidget);
      final error = Theme.of(tester.element(line)).colorScheme.error;
      expect(tester.widget<Text>(line).style!.color, error);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------- canvas

  group('the canvas card', () {
    dialogTest('the header: title, count, actions all disabled but help', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(find.text('Control points'), findsOneWidget);
      expect(find.text('3 x 3 points'), findsOneWidget);
      for (final key in [
        'undo',
        'redo',
        'bezier',
        'reset-positions',
        'mirror-horizontally',
        'mirror-vertically',
      ]) {
        expect(
          find.byKey(ValueKey('free-grid-$key')),
          findsOneWidget,
          reason: key,
        );
        final tooltip = tester.widget<CustomTooltip>(
          find.descendant(
            of: find.byKey(ValueKey('free-grid-$key')),
            matching: find.byType(CustomTooltip),
          ),
        );
        expect(
          const {
            'undo': 'Undo',
            'redo': 'Redo',
            'bezier': 'Bezier on selection (B)',
            'reset-positions': 'Reset positions (R)',
            'mirror-horizontally': 'Mirror horizontally (H)',
            'mirror-vertically': 'Mirror vertically (V)',
          }[key],
          tooltip.message,
        );
        final inkWell = find.descendant(
          of: find.byKey(ValueKey('free-grid-$key')),
          matching: find.byType(InkResponse),
        );
        expect(tester.widget<InkResponse>(inkWell).onTap, isNull, reason: key);
      }
    });

    dialogTest('the help tooltip lists the ten rows', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('free-grid-help'))),
      );
      await tester.pump();
      expect(find.text('Mouse and keyboard'), findsOneWidget);
      for (final text in [
        'Next or previous point, row by row',
        'Add to the selection',
        'Drag on empty space',
        'Select an area',
        'Zoom at the cursor',
        'Scroll up and down, sideways',
        'Pan',
        'Clear the selection',
        'Bezier on selection, reset positions',
        'Mirror horizontally, vertically',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.textContaining('Move the selection 1 px'), findsOneWidget);
      expect(find.text('Ctrl'), findsWidgets);
      expect(find.text('Cmd'), findsNothing);
    });

    dialogTest('a Mac shows Cmd in the help and in the hint', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(find.text('Cmd'), findsOneWidget, reason: 'the hint line');
      expect(find.text('Ctrl'), findsNothing);
    });

    dialogTest('the legend lists panel, grid and folded cell', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Control grid'), findsOneWidget);
      expect(find.text('Folded cell'), findsOneWidget);
      // At the first view the movable range is off the canvas.
      expect(find.text('Movable range'), findsNothing);
    });

    dialogTest('the movable range is listed while its frame shows', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(find.text('Movable range'), findsNothing);
      // Fit offers the movable range first.
      await tester.tap(find.byKey(const ValueKey('free-grid-fit')));
      await tester.pumpAndSettle();
      expect(find.text('Movable range'), findsOneWidget);
    });

    dialogTest('the hint line, with the reserved height of two lines', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final note = find.byKey(const ValueKey('free-grid-note'));
      expect(note, findsOneWidget);
      expect(
        tester.widget<Text>(note).textSpan!.toPlainText(),
        contains('Drag a point or an area.'),
      );
      final hintHeight = tester
          .getRect(find.byKey(freeGridCanvasCardKey))
          .height;
      // A folded cell warns on the same two-line space.
      final folded = _gridTable(dx: -3000);
      _seed(fake, WarpSlot.pc2, folded);
      await tester.tap(find.text('PC-2'));
      await settle(tester);
      expect(
        tester.widget<Text>(note).textSpan!.toPlainText(),
        contains('folded'),
      );
      expect(
        tester.getRect(find.byKey(freeGridCanvasCardKey)).height,
        hintHeight,
      );
    });

    dialogTest('a read-only memory: no control grid, a warning, Reset '
        'allowed, Store disabled', (tester) async {
      final planes = identityWarpTable(_caps.geometry, planes: 3);
      _seed(fake, WarpSlot.pc1, planes);
      await openDialog(tester, mode: 3);
      expect(painter(tester).grid, isNull);
      expect(painter(tester).plane, isNotNull, reason: 'the table still shows');
      expect(
        find.text(
          'This memory holds one table per color, the editor cannot change it.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(storeButton).onPressed, isNull);
      await openMemoryMenu(tester);
      expect(menuItem(tester, 'free-grid-menu-reset').onPressed, isNotNull);
    });

    dialogTest('a table the grid cannot describe names the actual size', (
      tester,
    ) async {
      final table = _gridTable();
      // One node 20 px off its place: no 3 x 3 grid builds that.
      table.planes.first.points[64 * 2 + 5] += 20;
      _seed(fake, WarpSlot.pc1, table);
      fake.warpFor(_ip).gridCounts[1] = '3:3';
      await openDialog(tester, mode: 3);
      expect(
        find.text(
          'This table has detail a 3 x 3 grid cannot describe. Editing will '
          'replace it with the grid shape. Try a larger grid first.',
        ),
        findsOneWidget,
      );
    });

    dialogTest('a read that fails: an error state, the memory group works', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      fake.warpFor(_ip).failFrame(0, 0x8C);
      await openDialog(tester, mode: 3);
      expect(find.text('Could not read PC-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('free-grid-paint')), findsNothing);
      // Reload and the segments stay usable; the other groups wait.
      expect(
        tester
            .widget<InkResponse>(
              find.descendant(
                of: reloadButton,
                matching: find.byType(InkResponse),
              ),
            )
            .onTap,
        isNotNull,
      );
      await tester.tap(reloadButton);
      await settle(tester);
      expect(find.text('Could not read PC-1'), findsNothing);
      expect(painter(tester).grid, isNotNull);
    });

    dialogTest('reading shows the title, the text and the skeleton groups', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      fake.holdBinary[_ip] = Completer<void>();
      await openDialog(tester, mode: 3, settleAll: false);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Reading PC-1 from the projector'), findsWidgets);
      expect(
        find.text(
          'Free grid is already selected on the projector. The control '
          'points appear once the PC-1 table is read, in about a second.',
        ),
        findsOneWidget,
      );
      for (final title in [
        'Memory',
        'Grid',
        'Selected points',
        'On the projector',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.byType(Skeleton), findsNWidgets(8));
      expect(
        find.text(
          'Before the first Store, the table is saved as a backup on this computer.',
        ),
        findsOneWidget,
      );
      fake.holdBinary[_ip]!.complete();
      await settle(tester);
    });

    dialogTest('storing: a chip with the step and a progress bar', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.holdFrameAfter(3);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              RegExp(r'^Writing the table to PC-1, step \d+ of \d+$')
                  .hasMatch(w.data ?? ''),
        ),
        findsOneWidget,
      );
      expect(find.text('3 x 3 points'), findsNothing);
      expect(find.text('Storing'), findsWidgets);
      expect(
        find.text(
          'The previous PC-1 table is saved as a backup on this computer. '
          'Polling is paused.',
        ),
        findsOneWidget,
      );
      // Every other control is out of reach.
      expect(
        tester
            .widget<InkResponse>(
              find.descendant(
                of: reloadButton,
                matching: find.byType(InkResponse),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkResponse>(
              find.descendant(
                of: moreButton,
                matching: find.byType(InkResponse),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkResponse>(
              find.descendant(
                of: find.byKey(const ValueKey('free-grid-zoom-in')),
                matching: find.byType(InkResponse),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<SegmentedTabs<WarpSlot?>>(
              find.byType(SegmentedTabs<WarpSlot?>),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('free-grid-switch-overlay')),
            )
            .onChanged,
        isNull,
      );
      // The other modes cannot be chosen.
      expect(tester.widget<ModeTile>(tileOf('Off')).onTap, isNull);
      fake.release();
      await settle(tester);
      expect(tester.widget<ModeTile>(tileOf('Off')).onTap, isNotNull);
    });

    dialogTest('while a memory is read nothing can be written', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.holdBinary[_ip] = Completer<void>();
      await tester.tap(reloadButton);
      await tester.pump(const Duration(milliseconds: 50));
      // The controls give way to their skeleton: nothing in them can be
      // used, and the footer's button is off.
      expect(reloadButton, findsNothing);
      expect(moreButton, findsNothing);
      expect(find.byType(Skeleton), findsNWidgets(8));
      expect(tester.widget<FilledButton>(storeButton).onPressed, isNull);
      fake.holdBinary[_ip]!.complete();
      await settle(tester);
    });
  });

  // -------------------------------------------------------------- controls

  group('the controls card', () {
    dialogTest('Memory: stored time, segments, Reload', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      fake.warpFor(_ip).storedTimes[1] = '20261120143200';
      await openDialog(tester, mode: 3);
      expect(
        find.text('Stored ${_local(DateTime.utc(2026, 11, 20, 14, 32))}'),
        findsOneWidget,
      );
      expect(find.text('PC-1'), findsWidgets);
      expect(find.text('PC-2'), findsOneWidget);
      expect(find.text('PC-3'), findsOneWidget);
      expect(tester.getSize(find.byType(SegmentedTabs<WarpSlot?>)).height, 32);
    });

    dialogTest('a memory that was never stored says so', (tester) async {
      await openDialog(tester, mode: 3);
      expect(find.text('Not stored yet'), findsOneWidget);
    });

    dialogTest('Grid shows the loaded counts, disabled', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable(columns: 5, rows: 4));
      fake.warpFor(_ip).gridCounts[1] = '5:4';
      await openDialog(tester, mode: 3);
      expect(find.text('Resizing keeps the shape'), findsOneWidget);
      expect(find.text('5 x 4 points'), findsOneWidget);
      for (final label in ['1/2', '2x']) {
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, label))
              .onPressed,
          isNull,
        );
      }
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    dialogTest('Selected points: two empty rows, none', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(find.text('Selected points'), findsOneWidget);
      expect(find.text('none'), findsOneWidget);
      expect(find.text('Position'), findsOneWidget);
      expect(find.text('Offset'), findsOneWidget);
      // The columns line up between the two rows.
      final x = [
        for (final t in find.text('X').evaluate())
          tester.getTopLeft(find.byWidget(t.widget)),
      ];
      expect(x, hasLength(2));
      expect(x[0].dx, x[1].dx);
      final fields = find.byType(TextField);
      // H, V, then X and Y of both rows.
      expect(fields, findsNWidgets(6));
      expect(tester.getSize(fields.at(0)).height, lessThanOrEqualTo(32));
    });

    dialogTest('On the projector: defaults, and the overlay is off', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      Switch sw(String key) =>
          tester.widget<Switch>(find.byKey(ValueKey('free-grid-switch-$key')));
      expect(sw('cursor').value, isTrue);
      expect(sw('overlay').value, isFalse);
      expect(sw('live').value, isTrue);
      expect(overlayFrames(), isEmpty, reason: 'opening changes no picture');
      expect(find.text('Cursor on the selected point'), findsOneWidget);
      expect(find.text('Grid overlay'), findsOneWidget);
      expect(find.text('Live preview while dragging'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('free-grid-swatch-Green')),
        findsOneWidget,
      );
      for (final name in [
        'White',
        'Red',
        'Green',
        'Blue',
        'Yellow',
        'Cyan',
        'Magenta',
      ]) {
        expect(find.byKey(ValueKey('free-grid-swatch-$name')), findsOneWidget);
      }
    });

    dialogTest('the grid overlay switch sends the overlay with its colour', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-overlay')));
      await settle(tester);
      expect(overlayFrames(), hasLength(1));
      expect(overlayFrames().last, [
        0x02,
        0x00,
        0xAB,
        0x07,
        1,
        3,
        3,
        0x00,
        0xFF,
        0x00,
        0x03,
      ]);
      // A colour while it is on is sent at once.
      await tester.tap(find.byKey(const ValueKey('free-grid-swatch-Red')));
      await settle(tester);
      expect(overlayFrames(), hasLength(2));
      expect(overlayFrames().last, [
        0x02,
        0x00,
        0xAB,
        0x07,
        1,
        3,
        3,
        0xFF,
        0x00,
        0x00,
        0x03,
      ]);
      // The chosen colour does nothing when tapped again.
      await tester.tap(find.byKey(const ValueKey('free-grid-swatch-Red')));
      await settle(tester);
      expect(overlayFrames(), hasLength(2));
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-overlay')));
      await settle(tester);
      expect(overlayFrames(), hasLength(3));
      expect(overlayFrames().last[4], 0);
      // A colour while it is off sends nothing.
      await tester.tap(find.byKey(const ValueKey('free-grid-swatch-Blue')));
      await settle(tester);
      expect(overlayFrames(), hasLength(3));
    });

    dialogTest('the cursor and live preview switches only keep their state', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final before = fake.sentBinary.length;
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-cursor')));
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-live')));
      await settle(tester);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('free-grid-switch-cursor')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('free-grid-switch-live')))
            .value,
        isFalse,
      );
      expect(fake.sentBinary.length, before);
    });

    dialogTest('leaving the mode takes the overlay off before the next mode '
        'is written', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-overlay')));
      await settle(tester);
      fake.timeline.clear();
      await tester.tap(tileOf('Keystone'));
      await settle(tester);
      expect(fake.timeline.take(2), ['overlay off', 'VXX:GMMI0=+00001']);
      expect(overlayFrames().last[4], 0);
      expect(selectedTile(tester), 'Keystone');
    });

    dialogTest('closing the dialog takes the overlay off', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-overlay')));
      await settle(tester);
      expect(overlayFrames().last[4], 1);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
      expect(overlayFrames().last[4], 0);
      expect(overlayFrames(), hasLength(2));
    });

    dialogTest('closing without an overlay sends nothing more', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final before = fake.sentBinary.length;
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(fake.sentBinary.length, before);
      expect(overlayFrames(), isEmpty);
    });

    dialogTest('a new memory gets the overlay again', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      _seed(fake, WarpSlot.pc2, _gridTable(columns: 5, rows: 4));
      fake.warpFor(_ip).gridCounts[2] = '5:4';
      await openDialog(tester, mode: 3);
      await tester.tap(find.byKey(const ValueKey('free-grid-switch-overlay')));
      await settle(tester);
      await tester.tap(find.text('PC-2'));
      await settle(tester);
      expect(overlayFrames().last, [
        0x02,
        0x00,
        0xAB,
        0x07,
        1,
        5,
        4,
        0x00,
        0xFF,
        0x00,
        0x03,
      ]);
    });
  });

  // ------------------------------------------------------ memory menu, confirms

  group('the memory menu', () {
    dialogTest('Restore backup is off without a backup', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await openMemoryMenu(tester);
      expect(find.text('No backup on this computer yet'), findsOneWidget);
      expect(menuItem(tester, 'free-grid-menu-restore').onPressed, isNull);
      expect(menuItem(tester, 'free-grid-menu-discard').onPressed, isNull);
      expect(menuItem(tester, 'free-grid-menu-reset').onPressed, isNotNull);
      expect(find.text('Go back to PC-1 as last stored'), findsOneWidget);
      expect(find.text('Reset PC-1 to neutral'), findsOneWidget);
      expect(find.text('Stores a flat table, no correction'), findsOneWidget);
    });

    dialogTest('Reset: the confirm says what changes; Cancel sends nothing', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final before = fake.sentBinary.length;
      await openMemoryMenu(tester);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Reset PC-1 to neutral?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConfirmDialog<bool>),
          matching: find.text('PT-RQ25K (10.0.0.1)'),
        ),
        findsOneWidget,
      );
      expect(find.text('What changes'), findsOneWidget);
      expect(
        find.textContaining(
          'PC-1 is stored flat, the image shows with no correction',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'The current PC-1 table is saved as a backup on this computer, Restore backup brings it back',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Changes not stored yet'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reset PC-1'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.sentBinary.length, before);
      expect(find.text('Reset PC-1 to neutral?'), findsNothing);
      expect(fake.warpFor(_ip).saves, isEmpty);
    });

    dialogTest('Reset writes the neutral table, with SAVE', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: 80));
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      final projector = fake.warpFor(_ip);
      expect(projector.saves, isNotEmpty);
      final stored = decodeTable(
        projector.blockOf(warpTypeCode(_caps.fullBase, WarpSlot.pc1))!,
        WarpEncoding.triple,
        _caps.bits,
      );
      final neutral = identityWarpTable(_caps.geometry);
      expect(stored.planes.first.points, neutral.planes.first.points);
      // The memory on screen is the neutral one, and Store is still off.
      expect(painter(tester).grid, isNotNull);
      expect(
        find.byKey(const ValueKey('free-grid-storing-chip')),
        findsNothing,
      );
      expect(find.textContaining('Stored '), findsOneWidget);
    });

    dialogTest('a second Reset says the backup stays', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: 80));
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-reset')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(' stays, Restore backup brings it back'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The current PC-1 table is saved'),
        findsNothing,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    dialogTest('Restore backup: confirm, then the original table is back', (
      tester,
    ) async {
      final original = _gridTable(dx: 80);
      _seed(fake, WarpSlot.pc1, original);
      // A memory that was stored once.
      fake.warpFor(_ip).storedTimes[1] = '20261120143200';
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      expect(menuItem(tester, 'free-grid-menu-restore').onPressed, isNotNull);
      expect(find.textContaining('Backup of '), findsOneWidget);
      expect(find.textContaining(', saved on this computer'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-restore')));
      await tester.pumpAndSettle();
      expect(find.text('Restore the PC-1 backup?'), findsOneWidget);
      expect(
        find.textContaining('PC-1 is stored as it was on '),
        findsOneWidget,
      );
      expect(
        find.textContaining(', from the backup on this computer'),
        findsOneWidget,
      );
      // Cancel changes nothing.
      final blockBefore = fake
          .warpFor(_ip)
          .blockOf(warpTypeCode(_caps.fullBase, WarpSlot.pc1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        fake.warpFor(_ip).blockOf(warpTypeCode(_caps.fullBase, WarpSlot.pc1)),
        blockBefore,
      );

      await openMemoryMenu(tester);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore PC-1'));
      await settle(tester);
      expect(
        fake.warpFor(_ip).blockOf(warpTypeCode(_caps.fullBase, WarpSlot.pc1)),
        _blockOf(original),
      );
    });
  });

  // ------------------------------------------------------------- interaction

  group('zoom and pan', () {
    Future<void> openReady(WidgetTester tester, {Size size = full}) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: size);
    }

    Offset canvasCentre(WidgetTester tester) =>
        tester.getCenter(find.byKey(const ValueKey('free-grid-paint')));

    dialogTest('the first view fits the panel with a margin', (tester) async {
      await openReady(tester);
      final size = tester.getSize(
        find.byKey(const ValueKey('free-grid-paint')),
      );
      final p = painter(tester);
      final panel = p.view.rectToScreen(p.frame.panel);
      final margin = (size.width - panel.width) / 2;
      expect(margin / size.width, closeTo(0.12, 0.01));
      expect(panel.center.dx, closeTo(size.width / 2, 0.5));
    });

    dialogTest('the zoom buttons step 1.25 times', (tester) async {
      await openReady(tester);
      final start = painter(tester).view.zoom;
      await tester.tap(find.byKey(const ValueKey('free-grid-zoom-in')));
      await tester.pump();
      expect(painter(tester).view.zoom, closeTo(start * 1.25, 1e-9));
      await tester.tap(find.byKey(const ValueKey('free-grid-zoom-out')));
      await tester.tap(find.byKey(const ValueKey('free-grid-zoom-out')));
      await tester.pump();
      expect(painter(tester).view.zoom, closeTo(start / 1.25, 1e-9));
    });

    dialogTest('Fit alternates and its tooltip names the next fit', (
      tester,
    ) async {
      await openReady(tester);
      String tip() => tester
          .widget<CustomTooltip>(
            find.descendant(
              of: find.byKey(const ValueKey('free-grid-fit')),
              matching: find.byType(CustomTooltip),
            ),
          )
          .message;
      final panelZoom = painter(tester).view.zoom;
      expect(tip(), 'Fit movable range');
      await tester.tap(find.byKey(const ValueKey('free-grid-fit')));
      await tester.pump();
      expect(painter(tester).view.zoom, lessThan(panelZoom));
      expect(tip(), 'Fit panel');
      await tester.tap(find.byKey(const ValueKey('free-grid-fit')));
      await tester.pump();
      expect(painter(tester).view.zoom, closeTo(panelZoom, 1e-9));
    });

    dialogTest('Ctrl and the wheel zoom at the cursor', (tester) async {
      await openReady(tester);
      final at = canvasCentre(tester) + const Offset(60, 20);
      final box = tester.getTopLeft(
        find.byKey(const ValueKey('free-grid-paint')),
      );
      final local = at - box;
      final before = painter(tester).view;
      final panelPoint = before.toPanel(local);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: at, scrollDelta: const Offset(0, -100)),
      );
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      final after = painter(tester).view;
      expect(after.zoom, closeTo(before.zoom * 1.25, 1e-9));
      final moved = after.toScreen(panelPoint);
      expect(moved.dx, closeTo(local.dx, 1e-6));
      expect(moved.dy, closeTo(local.dy, 1e-6));
    });

    dialogTest('the wheel scrolls, Shift sideways', (tester) async {
      await openReady(tester);
      final at = canvasCentre(tester);
      final before = painter(tester).view;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: at, scrollDelta: const Offset(0, 40)),
      );
      await tester.pump();
      expect(painter(tester).view.offset, before.offset + const Offset(0, -40));
      expect(painter(tester).view.zoom, before.zoom);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: at, scrollDelta: const Offset(0, 30)),
      );
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(
        painter(tester).view.offset,
        before.offset + const Offset(-30, -40),
      );
    });

    dialogTest('a middle drag pans', (tester) async {
      await openReady(tester);
      final before = painter(tester).view;
      final gesture = await tester.startGesture(
        canvasCentre(tester),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.moveBy(const Offset(25, -15));
      await gesture.up();
      await tester.pump();
      expect(
        painter(tester).view.offset,
        before.offset + const Offset(25, -15),
      );
    });

    dialogTest('Space and a primary drag pan; a plain drag does nothing', (
      tester,
    ) async {
      await openReady(tester);
      final before = painter(tester).view;
      // A plain drag on empty space is the rubber band, later.
      var gesture = await tester.startGesture(
        canvasCentre(tester),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(30, 30));
      await gesture.up();
      await tester.pump();
      expect(painter(tester).view, before);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      gesture = await tester.startGesture(
        canvasCentre(tester),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-20, 10));
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        painter(tester).view.offset,
        before.offset + const Offset(-20, 10),
      );
    });

    dialogTest('a pinch zooms at the pointer', (tester) async {
      await openReady(tester);
      final before = painter(tester).view;
      final at = canvasCentre(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      tester.binding.handlePointerEvent(pointer.panZoomStart(at));
      tester.binding.handlePointerEvent(pointer.panZoomUpdate(at, scale: 1.5));
      await tester.pump();
      tester.binding.handlePointerEvent(pointer.panZoomEnd());
      expect(painter(tester).view.zoom, closeTo(before.zoom * 1.5, 1e-9));
    });

    dialogTest('the pan keeps part of the movable range in view', (
      tester,
    ) async {
      await openReady(tester);
      final at = canvasCentre(tester);
      for (var i = 0; i < 40; i++) {
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: at, scrollDelta: const Offset(0, -2000)),
        );
      }
      await tester.pump();
      final p = painter(tester);
      final range = p.view.rectToScreen(p.frame.range);
      final size = p.frame.canvas;
      expect(range.top, lessThanOrEqualTo(size.height - 47));
    });

    dialogTest('zoom and pan are out of reach while storing', (tester) async {
      await openReady(tester);
      final before = painter(tester).view;
      fake.holdFrameAfter(3);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: canvasCentre(tester),
          scrollDelta: const Offset(0, 50),
        ),
      );
      await tester.pump();
      expect(painter(tester).view, before);
      fake.release();
      await settle(tester);
    });
  });

  // ---------------------------------------------------------------- compact

  group('the smallest window', () {
    dialogTest('the count moves to Selected points, help to the zoom '
        'cluster', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: minimum);
      expect(tester.takeException(), isNull);
      // No pill in the card header, and none in the controls card either
      // (UI-R-9): the Selected points caption is the caption it is at the
      // full size, and the Grid fields show the size.
      expect(find.text('3 x 3 points'), findsNothing);
      expect(find.text('none'), findsOneWidget);
      // The help sits in the zoom cluster, not in the header.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('free-grid-zoom-cluster')),
          matching: find.byKey(const ValueKey('free-grid-help')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('free-grid-help')), findsOneWidget);
      // The title and the six actions stay.
      expect(find.text('Control points'), findsOneWidget);
      for (final key in [
        'undo',
        'redo',
        'bezier',
        'reset-positions',
        'mirror-horizontally',
        'mirror-vertically',
      ]) {
        expect(find.byKey(ValueKey('free-grid-$key')), findsOneWidget);
      }
      // A short legend, and no note line.
      expect(find.text('Grid'), findsWidgets);
      expect(find.text('Folded'), findsOneWidget);
      expect(find.byKey(const ValueKey('free-grid-note')), findsNothing);
    });

    dialogTest('a full-size canvas keeps its pill and its help in the header', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      expect(
        find.descendant(
          of: find.byKey(freeGridCanvasCardKey),
          matching: find.text('3 x 3 points'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('free-grid-zoom-cluster')),
          matching: find.byKey(const ValueKey('free-grid-help')),
        ),
        findsNothing,
      );
      expect(find.text('none'), findsOneWidget);
    });

    dialogTest('the controls card scrolls', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: minimum);
      final scroll = find.descendant(
        of: find.byKey(freeGridControlsCardKey),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      final view = tester.getRect(scroll);
      final content = tester.getRect(
        find.descendant(of: scroll, matching: find.byType(Column)).first,
      );
      expect(
        content.height,
        greaterThan(view.height),
        reason: 'it needs the scroll',
      );
    });
  });

  // -------------------------------------------------------------- fix round

  Future<void> tab(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }

  bool inside(BuildContext context, Key key) {
    var found = false;
    context.visitAncestorElements((e) {
      if (e.widget.key == key) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump();
    return mouse;
  }

  group('the memory menu (UI-R-1, UI-R-14, QA-011)', () {
    dialogTest('is 300 wide, its right edge at the button, inside the dialog', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      final item = tester.getRect(
        find.byKey(const ValueKey('free-grid-menu-restore')),
      );
      final dialog = tester.getRect(find.byType(GeometryCorrectionDialog));
      expect(item.width, 288, reason: '300 with the 6 px inset on each side');
      expect(dialog.contains(item.topLeft), isTrue);
      expect(dialog.contains(item.bottomRight), isTrue);
      final button = tester.getRect(moreButton);
      expect(item.right + 6, closeTo(button.right, 1));
      expect(tester.takeException(), isNull);
    });

    dialogTest('stays inside the smallest dialog, a long line wraps', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: minimum);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      final item = tester.getRect(
        find.byKey(const ValueKey('free-grid-menu-restore')),
      );
      final dialog = tester.getRect(find.byType(GeometryCorrectionDialog));
      expect(item.width, 288);
      expect(item.right, lessThanOrEqualTo(dialog.right));
      expect(item.left, greaterThanOrEqualTo(dialog.left));
      final description = tester.getSize(
        find.textContaining(', saved on this computer'),
      );
      expect(description.height, greaterThan(16), reason: 'two lines');
      expect(tester.takeException(), isNull);
    });

    dialogTest('item titles are w500', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await openMemoryMenu(tester);
      for (final title in [
        'Restore backup',
        'Discard changes',
        'Reset PC-1 to neutral',
      ]) {
        expect(
          tester.widget<Text>(find.text(title)).style!.fontWeight,
          FontWeight.w500,
          reason: title,
        );
      }
    });

    dialogTest('its tooltip does not cover the menu it opens', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final mouse = await hover(tester, moreButton);
      expect(find.text('More memory actions'), findsOneWidget);
      // Click with the pointer still on the button.
      await mouse.down(tester.getCenter(moreButton));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Restore backup'), findsOneWidget, reason: 'open');
      expect(find.text('More memory actions'), findsNothing);
    });
  });

  group('closing while a write runs (decision 14.2)', () {
    dialogTest('Esc, the barrier and the close button are refused', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.holdFrameAfter(3);
      await resetTo(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byKey(const ValueKey('free-grid-storing-chip')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GeometryCorrectionDialog), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GeometryCorrectionDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GeometryCorrectionDialog), findsOneWidget);

      fake.release();
      await settle(tester);
      // The write is done: the dialog closes as it always does.
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
    });

    dialogTest('the barrier and Esc close it when nothing is written', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
    });
  });

  group('messages (UI-R-3, UI-R-12, QA-010, UI-R-20, lastStoreIncomplete)', () {
    dialogTest('a failed write: one line that ends with the action', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.warpFor(_ip).failFrame(fake.warpFor(_ip).frames.length + 1, 0x8C);
      await resetTo(tester);
      await settle(tester);
      final line = find.textContaining('Resetting PC-1 failed at step');
      expect(line, findsOneWidget);
      final text = tester.widget<Text>(line).data!;
      expect(text, endsWith('it may be partly written. Reload to check.'));
      expect(text, isNot(contains('0x')));
      // The reason is in the tooltip and in the event log.
      final tooltip = tester.widget<CustomTooltip>(
        find.ancestor(of: line, matching: find.byType(CustomTooltip)),
      );
      expect(tooltip.message, isNotEmpty);
      expect(tooltip.message, isNot(equals(text)));
      final events = container.read(eventLogProvider);
      expect(
        events.where((e) => e.message.contains('reset failed at step')),
        hasLength(1),
      );
    });

    dialogTest('a store that did not keep its time says so, until Reload', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.warpFor(_ip).droppedAscii.add('VXX:GDTS1');
      await resetTo(tester);
      await settle(tester);
      const warning =
          'PC-1 is stored, but the projector did not keep its stored time or '
          'grid size. Reload to check.';
      final line = find.text(warning);
      expect(line, findsOneWidget);
      final warningColor = AppStatusColors.of(tester.element(line)).warning;
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.ancestor(of: line, matching: find.byType(Row)).first,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
      );
      expect(icon.color, warningColor);
      fake.warpFor(_ip).droppedAscii.clear();
      await tester.tap(reloadButton);
      await settle(tester);
      expect(find.text(warning), findsNothing);
    });

    dialogTest('a read that failed: words, one title, Try again, no stale '
        'values', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable(columns: 5, rows: 4));
      fake.warpFor(_ip).gridCounts[1] = '5:4';
      fake.warpFor(_ip).failFrame(0, 0x8C);
      await openDialog(tester, mode: 3);
      expect(find.text('Could not read PC-1'), findsOneWidget);
      const detail =
          'The projector did not answer the read. Try again, or check that '
          'it is not busy.';
      expect(find.text(detail), findsOneWidget);
      // The reason is behind the detail, never in the line itself.
      expect(find.textContaining('0x8c'), findsNothing);
      final reason = tester.widget<CustomTooltip>(
        find.ancestor(
          of: find.text(detail),
          matching: find.byType(CustomTooltip),
        ),
      );
      expect(reason.message, startsWith('Could not read PC-1: '));
      // The Grid fields show nothing, the note and the footer are neutral.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect([for (final f in fields) f.controller!.text], everyElement(''));
      expect(find.text('PC-1 was not read'), findsOneWidget);
      expect(find.textContaining('Drag a point'), findsNothing);
      expect(
        find.text('There is nothing to edit until PC-1 has been read.'),
        findsOneWidget,
      );
      // No memory is selected: any segment switches the projector and reads.
      expect(selectedSlot(tester), isNull);

      await tester.tap(find.byKey(const ValueKey('free-grid-try-again')));
      await settle(tester);
      expect(find.text('Could not read PC-1'), findsNothing);
      expect(painter(tester).grid, isNotNull);
      expect(selectedSlot(tester), WarpSlot.pc1);
    });

    dialogTest('a failed read names the geometry mode when it has none', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.rawResponsesByIp[_ip] = {'QVX:GMMI0': 'ER401'};
      await tester.tap(reloadButton);
      await settle(tester);
      expect(
        find.text('The projector did not report its geometry mode.'),
        findsOneWidget,
      );
      expect(find.textContaining('null'), findsNothing);
    });

    dialogTest('a memory the projector is not in: Reload says so, a click '
        'on a segment switches', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.warpFor(_ip).mode = 0;
      await tester.tap(reloadButton);
      await settle(tester);
      expect(
        find.text('The projector is not in PC-1. Select PC-1 to switch it.'),
        findsOneWidget,
      );
      expect(fake.warpFor(_ip).mode, 0, reason: 'Reload never switches');
      await tester.tap(find.text('PC-1'));
      await settle(tester);
      expect(fake.warpFor(_ip).mode, 3);
      expect(painter(tester).grid, isNotNull);
    });

    dialogTest('Restore of a never-stored memory says it goes back to no '
        'correction', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      // No stored time: the memory was never stored.
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-restore')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'PC-1 goes back to no correction, as it was before the first Store',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('is stored as it was on'), findsNothing);
      expect(
        find.textContaining(
          'The current PC-1 table is replaced, it is not backed up',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    dialogTest('Restore of a stored memory keeps its date and says what is '
        'replaced', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      fake.warpFor(_ip).storedTimes[1] = '20261120143200';
      await openDialog(tester, mode: 3);
      await resetTo(tester);
      await settle(tester);
      await openMemoryMenu(tester);
      await tester.tap(find.byKey(const ValueKey('free-grid-menu-restore')));
      await tester.pumpAndSettle();
      expect(find.textContaining('is stored as it was on'), findsOneWidget);
      expect(find.textContaining('goes back to no correction'), findsNothing);
      expect(
        find.textContaining('The current PC-1 table is replaced'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('a model without memories (decision 14.3, QA-005)', () {
    dialogTest('the tile click changes nothing and the tile is gone', (
      tester,
    ) async {
      fake.rawResponses['QVX:MIDS1'] = 'MIDS1=0010:00:26';
      await openDialog(tester, mode: 0);
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(selectedTile(tester), 'Off', reason: 'back to the earlier mode');
      expect(tileLabels(tester), isNot(contains('Free grid')));
      expect(fake.warpFor(_ip).mode, 0);
      expect(gmmiWrites(), isEmpty);
      expect(
        [
          for (final (_, cmd) in fake.sentRaw)
            if (cmd.startsWith('VXX:')) cmd,
        ],
        isEmpty,
        reason: 'not even the Quad Pixel Drive step',
      );
      expect(fake.sentCommands, isEmpty);
      expect(find.text('Could not read PC-1'), findsNothing);
    });

    dialogTest('from Keystone it goes back to Keystone', (tester) async {
      fake.rawResponses['QVX:MIDS1'] = 'MIDS1=0010:00:26';
      await openDialog(tester, mode: 1);
      await tester.tap(tileOf('Free grid'));
      await settle(tester);
      expect(selectedTile(tester), 'Keystone');
      expect(tileLabels(tester), isNot(contains('Free grid')));
      expect(gmmiWrites(), isEmpty);
    });
  });

  group('the other modes wait while the session works (QA-003)', () {
    dialogTest('while reading, the tiles but the selected one are disabled', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      fake.holdBinary[_ip] = Completer<void>();
      await tester.tap(reloadButton);
      await tester.pump(const Duration(milliseconds: 50));
      for (final label in ['Off', 'Keystone', 'Curved Correction']) {
        expect(
          tester.widget<ModeTile>(tileOf(label)).onTap,
          isNull,
          reason: label,
        );
      }
      fake.holdBinary[_ip]!.complete();
      await settle(tester);
      expect(tester.widget<ModeTile>(tileOf('Off')).onTap, isNotNull);
    });
  });

  group('the compact window (UI-R-2)', () {
    dialogTest('a warning takes the footer message, with a tooltip', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: -3000));
      await openDialog(tester, mode: 3, size: minimum);
      final warning = find.byKey(const ValueKey('free-grid-footer-warning'));
      expect(warning, findsOneWidget);
      final text = tester
          .widget<Text>(
            find.descendant(of: warning, matching: find.byType(Text)),
          )
          .data!;
      expect(text, contains('folded'));
      expect(
        find.text('Edits show on the projector live, Store keeps them in PC-1'),
        findsNothing,
      );
      final tooltip = tester.widget<CustomTooltip>(
        find.descendant(of: warning, matching: find.byType(CustomTooltip)),
      );
      expect(tooltip.message, text);
      final warningColor = AppStatusColors.of(tester.element(warning)).warning;
      final icon = tester.widget<Icon>(
        find.descendant(
          of: warning,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
      );
      expect(icon.color, warningColor);
      expect(tester.takeException(), isNull);
    });

    dialogTest('no warning: the usual footer message', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3, size: minimum);
      expect(
        find.byKey(const ValueKey('free-grid-footer-warning')),
        findsNothing,
      );
      expect(
        find.text('Edits show on the projector live, Store keeps them in PC-1'),
        findsOneWidget,
      );
    });

    dialogTest('the full-size dialog keeps the note line, not the footer', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable(dx: -3000));
      await openDialog(tester, mode: 3);
      expect(
        find.byKey(const ValueKey('free-grid-footer-warning')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('free-grid-note')), findsOneWidget);
    });
  });

  group(
    'the controls card (UI-R-4, UI-R-5, UI-R-6, UI-R-7, UI-R-8, UI-R-18)',
    () {
      dialogTest('Tab never lands in a disabled field', (tester) async {
        _seed(fake, WarpSlot.pc1, _gridTable());
        await openDialog(tester, mode: 3);
        for (var i = 0; i < 40; i++) {
          await tab(tester);
          final context = FocusManager.instance.primaryFocus?.context;
          if (context == null) continue;
          expect(
            context.findAncestorWidgetOfExactType<EditableText>(),
            isNull,
            reason: 'stop $i is inside a text field',
          );
        }
      });

      dialogTest('Tab goes through the canvas card, then the controls card', (
        tester,
      ) async {
        _seed(fake, WarpSlot.pc1, _gridTable());
        await openDialog(tester, mode: 3);
        final regions = <String>[];
        for (var i = 0; i < 40; i++) {
          await tab(tester);
          final context = FocusManager.instance.primaryFocus?.context;
          final region = context == null
              ? 'none'
              : inside(context, freeGridCanvasCardKey)
              ? 'canvas'
              : inside(context, freeGridControlsCardKey)
              ? 'controls'
              : 'other';
          if (regions.isEmpty || regions.last != region) regions.add(region);
        }
        // The title bar and the tiles, the canvas card, the controls card, and
        // round again: never back and forth between the two cards.
        expect(regions.take(4), ['other', 'canvas', 'controls', 'other']);
        expect(
          regions.where((r) => r == 'canvas').length,
          regions.where((r) => r == 'controls').length,
        );
      });

      dialogTest('the colors are one stop that the arrow keys move', (
        tester,
      ) async {
        _seed(fake, WarpSlot.pc1, _gridTable());
        await openDialog(tester, mode: 3);
        await tester.tap(
          find.byKey(const ValueKey('free-grid-switch-overlay')),
        );
        await settle(tester);
        expect(overlayFrames().last.sublist(7, 10), [0x00, 0xFF, 0x00]);
        for (var i = 0; i < 60; i++) {
          await tab(tester);
          if (FocusManager.instance.primaryFocus?.debugLabel ==
              'overlay color') {
            break;
          }
        }
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'overlay color');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await settle(tester);
        expect(overlayFrames().last.sublist(7, 10), [
          0x00,
          0x00,
          0xFF,
        ], reason: 'Blue');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await settle(tester);
        expect(overlayFrames().last.sublist(7, 10), [
          0xFF,
          0x00,
          0x00,
        ], reason: 'Red');
        // The ends stop the choice.
        for (var i = 0; i < 10; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        }
        await settle(tester);
        expect(overlayFrames().last.sublist(7, 10), [
          0xFF,
          0x00,
          0xFF,
        ], reason: 'Magenta');
        // While the keyboard has the row, the chosen swatch's ring is primary.
        final swatch = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const ValueKey('free-grid-swatch-Magenta')),
                matching: find.byType(Container),
              )
              .first,
        );
        final shadows = (swatch.decoration! as BoxDecoration).boxShadow!;
        expect(
          shadows.first.color,
          Theme.of(
            tester.element(
              find.byKey(const ValueKey('free-grid-swatch-Magenta')),
            ),
          ).colorScheme.primary,
        );
      });

      dialogTest(
        'the chosen swatch: the ring first, the card-colored gap over it',
        (tester) async {
          _seed(fake, WarpSlot.pc1, _gridTable());
          await openDialog(tester, mode: 3);
          final green = find.byKey(const ValueKey('free-grid-swatch-Green'));
          final container = tester.widget<Container>(
            find.descendant(of: green, matching: find.byType(Container)).first,
          );
          final shadows = (container.decoration! as BoxDecoration).boxShadow!;
          final cs = Theme.of(tester.element(green)).colorScheme;
          expect(shadows, hasLength(2));
          expect(shadows[0].spreadRadius, 4);
          expect(
            shadows[0].color,
            cs.onSurface,
            reason: 'the ring is underneath',
          );
          expect(shadows[1].spreadRadius, 2);
          expect(
            shadows[1].color,
            DialogSurfaces.of(tester.element(green)).card,
          );
        },
      );

      dialogTest('the controls do not move when the table arrives (offsets)', (
        tester,
      ) async {
        _seed(fake, WarpSlot.pc1, _gridTable());
        await openDialog(tester, mode: 3);
        Map<String, Offset> offsets() => {
          for (final t in [
            'Memory',
            'Grid',
            'Selected points',
            'On the projector',
          ])
            t: tester.getTopLeft(find.text(t)),
        };
        final ready = offsets();
        final divider = tester.getRect(find.byKey(freeGridControlsCardKey));

        fake.holdBinary[_ip] = Completer<void>();
        await tester.tap(reloadButton);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(Skeleton), findsNWidgets(8));
        expect(offsets(), ready, reason: 'the skeleton has the same headers');
        expect(tester.getRect(find.byKey(freeGridControlsCardKey)), divider);

        fake.holdBinary[_ip]!.complete();
        await settle(tester);
        expect(offsets(), ready);
      });

      dialogTest('a read-only memory: no pill, no control grid entry, empty '
          'Grid fields', (tester) async {
        _seed(fake, WarpSlot.pc1, identityWarpTable(_caps.geometry, planes: 3));
        await openDialog(tester, mode: 3);
        expect(find.text('3 x 3 points'), findsNothing);
        expect(find.text('Control grid'), findsNothing);
        expect(find.text('Panel'), findsOneWidget);
        expect(find.text('Folded cell'), findsOneWidget);
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect([for (final f in fields) f.controller!.text], everyElement(''));
      });

      dialogTest('an editable memory shows its size in the Grid fields', (
        tester,
      ) async {
        _seed(fake, WarpSlot.pc1, _gridTable(columns: 5, rows: 4));
        fake.warpFor(_ip).gridCounts[1] = '5:4';
        await openDialog(tester, mode: 3);
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller!.text)
            .toList();
        expect(fields.take(2), ['5', '4']);
        expect(find.text('Control grid'), findsOneWidget);
      });
    },
  );

  group('help, focus and icons (UI-R-10, UI-R-15, UI-R-19)', () {
    dialogTest('every help row is one line and the keys do not wrap', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      await hover(tester, find.byKey(const ValueKey('free-grid-help')));
      final descriptions = [
        'Next or previous point, row by row',
        'Add to the selection',
        'Select an area',
        'Zoom at the cursor',
        'Scroll up and down, sideways',
        'Pan',
        'Clear the selection',
        'Bezier on selection, reset positions',
        'Mirror horizontally, vertically',
      ];
      final heights = {
        for (final d in descriptions) d: tester.getSize(find.text(d)).height,
      };
      expect(heights.values.toSet(), hasLength(1), reason: '$heights');
      final rich = tester.getSize(
        find.textContaining('Move the selection 1 px'),
      );
      expect(rich.height, heights.values.first);
      // The key column: 'Middle drag, [Space] drag' is a single line.
      final keys = tester.getSize(find.text('Middle drag,'));
      expect(keys.height, heights.values.first);
      final bubble = tester.getSize(find.byType(TooltipBubble));
      expect(bubble.width, lessThanOrEqualTo(420));
    });

    dialogTest('the canvas shows a ring for keyboard focus only', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      bool ringShown() =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(const ValueKey('free-grid-focus-ring')),
                      )
                      .decoration
                  as BoxDecoration)
              .border !=
          null;
      expect(ringShown(), isFalse);
      // A click focuses the canvas, with no ring.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('free-grid-paint'))),
      );
      await tester.pump();
      expect(ringShown(), isFalse);
      // The keyboard has it.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(ringShown(), isTrue);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    dialogTest('a round icon button shows a ring when the keyboard is on it', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      Color ring() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(of: reloadButton, matching: find.byType(DecoratedBox))
              .first,
        );
        return (box.decoration as BoxDecoration).border!.top.color;
      }

      expect(ring().a, 0, reason: 'no ring at rest');
      for (var i = 0; i < 40; i++) {
        await tab(tester);
        final context = FocusManager.instance.primaryFocus?.context;
        if (context != null &&
            tester.any(
              find.descendant(
                of: reloadButton,
                matching: find.byType(InkResponse),
              ),
            ) &&
            context.findAncestorWidgetOfExactType<InkResponse>() != null &&
            inside(context, const ValueKey('free-grid-reload'))) {
          break;
        }
      }
      expect(ring().a, 1, reason: 'a solid ring with the keyboard on it');
    });

    dialogTest('Fit movable range has its own icon, the tile keeps grid_on', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final fit = find.byKey(const ValueKey('free-grid-fit'));
      expect(
        tester
            .widget<Icon>(find.descendant(of: fit, matching: find.byType(Icon)))
            .icon,
        Icons.open_in_full,
      );
      expect(Icons.open_in_full, isNot(Icons.zoom_out_map));
      expect(
        tester.widget<ModeTile>(tileOf('Corner Correction')).icon,
        Icons.zoom_out_map,
      );
      expect(tester.widget<ModeTile>(tileOf('Free grid')).icon, Icons.grid_on);
    });
  });

  // ----------------------------------------------------------------- themes

  for (final (name, theme) in [
    ('dark', AppTheme.darkTheme),
    ('light', AppTheme.lightTheme),
  ]) {
    for (final (sizeName, size) in [('full', full), ('minimum', minimum)]) {
      dialogTest('renders in the $name theme at the $sizeName size', (
        tester,
      ) async {
        _seed(fake, WarpSlot.pc1, _gridTable());
        await openDialog(tester, mode: 3, theme: theme, size: size);
        expect(find.byKey(const ValueKey('free-grid-paint')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('free-grid-switch-overlay')),
        );
        await settle(tester);
        await openMemoryMenu(tester);
        expect(find.text('Restore backup'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// `2026-11-20 14:32` as the app shows a stored time, from its UTC value.
String _local(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  final t = utc.toLocal();
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
