// Regression tests for the second QA round of the Free grid dialog
// (QA-012 to QA-015 in projector-grid-notes/QA_FINDINGS.md; the id is in the
// test name). The first five probes are the tester's, with extra checks.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_backup_store_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_edit_session_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/segmented_tabs.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_tooltip.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_correction_dialog.dart';

import '../helpers/app_fonts.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

const _ip = '10.0.0.1';
const _mids = 'MIDS1=0028:00:26';

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

/// A fake whose model query can fail the way the protocol worker does when it
/// dies: with a [StateError].
class _Fake extends FakeProtocolService {
  int workerFailsMids = 0;

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) {
    if (cmd == 'QVX:MIDS1' && workerFailsMids > 0) {
      workerFailsMids--;
      // The dialog asks too; only the session's query dies (the second one).
      if (sentRaw.where((e) => e.$2 == 'QVX:MIDS1').isNotEmpty) {
        throw StateError('Protocol worker exited');
      }
    }
    return super.sendRawCommand(ip, port, login, password, cmd);
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

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void setUpContainer(WidgetTester tester, int mode) {
    fake.warpFor(_ip).mode = mode;
    container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        warpBackupStoreProvider.overrideWithValue(_MemoryBackups()),
      ],
    );
    container.read(workspaceProvider.notifier).setNodes([_node]);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openDialog(WidgetTester tester, {int mode = 0}) async {
    setUpContainer(tester, mode);
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

  /// Opens the dialog the way a projector card's context menu does: from a
  /// menu item, whose menu then closes and hands focus back to what had it.
  Future<void> openDialogFromMenu(WidgetTester tester, {int mode = 0}) async {
    setUpContainer(tester, mode);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            const GeometryCorrectionDialog(node: _node),
                      ),
                      child: const Text('Geometry Correction'),
                    ),
                  ],
                  builder: (context, controller, _) => TextButton(
                    onPressed: controller.open,
                    child: const Text('card'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geometry Correction'));
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

  final overlaySwitch = find.byKey(const ValueKey('free-grid-switch-overlay'));
  final reloadButton = find.byKey(const ValueKey('free-grid-reload'));
  final moreButton = find.byKey(const ValueKey('free-grid-memory-more'));

  List<Uint8List> overlayFrames() => [
    for (final (_, f) in fake.sentBinary)
      if (f.length > 4 && f[2] == 0xAB && f[3] == 0x07) f,
  ];

  WarpSessionState session() =>
      container.read(warpEditSessionProvider(_node.id));

  WorkspaceNotifier workspace() => container.read(workspaceProvider.notifier);

  bool tapIsRefused(WidgetTester tester, Finder button) =>
      tester
          .widget<InkResponse>(
            find.descendant(of: button, matching: find.byType(InkResponse)),
          )
          .onTap ==
      null;

  // ------------------------------------------------------------- QA-012

  dialogTest('QA-012 Try again after a busy tile click shows PC-1 only when '
      'the projector is in it', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable(dx: 40));
    await openDialog(tester, mode: 0);

    // A poll holds the projector longer than the session's 3 s claim wait.
    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(tileOf('Free grid'));
    await pumpFor(tester, 3500);
    workspace().releaseNodeFromExternalPoll(_node.id);
    await settle(tester);
    expect(session().phase, WarpSessionPhase.failed);
    expect(fake.warpFor(_ip).mode, 0);

    await tester.tap(find.byKey(const ValueKey('free-grid-try-again')));
    await settle(tester);
    expect(
      session().phase == WarpSessionPhase.ready ? fake.warpFor(_ip).mode : 3,
      3,
      reason:
          'Try again opened without the switch: PC-1 is shown ready while '
          'the projector is still in mode ${fake.warpFor(_ip).mode}',
    );
    // It repeated the switch: the memory is shown, and the projector is in it.
    expect(session().phase, WarpSessionPhase.ready);
    expect(fake.warpFor(_ip).mode, 3);
  });

  dialogTest('QA-012 the worker dies on the tile\'s model query: Try again '
      'repeats the switch', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable(dx: 40));
    await openDialog(tester, mode: 0);
    fake.workerFailsMids = 1;
    await tester.tap(tileOf('Free grid'));
    await settle(tester);
    expect(session().phase, WarpSessionPhase.failed);
    expect(session().caps, isNull, reason: 'the model is not known yet');
    expect(fake.warpFor(_ip).mode, 0);

    await tester.tap(find.byKey(const ValueKey('free-grid-try-again')));
    await settle(tester);
    expect(session().phase, WarpSessionPhase.ready);
    expect(fake.warpFor(_ip).mode, 3);
    expect(selectedTile(tester), 'Free grid');
  });

  dialogTest('QA-012 the Reload icon repeats the switch too', (tester) async {
    _seed(fake, WarpSlot.pc2, _gridTable(dx: 40));
    await openDialog(tester, mode: 0);
    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(tileOf('Free grid'));
    await pumpFor(tester, 3500);
    workspace().releaseNodeFromExternalPoll(_node.id);
    await settle(tester);
    expect(session().phase, WarpSessionPhase.failed);

    await tester.tap(reloadButton);
    await settle(tester);
    expect(session().phase, WarpSessionPhase.ready);
    expect(fake.warpFor(_ip).mode, 3);
  });

  // ------------------------------------------------------------- QA-013

  dialogTest('QA-013 a memory picked while the overlay goes off does not '
      'outlive the mode change', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    _seed(fake, WarpSlot.pc2, _gridTable(dx: 40));
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);

    // A poll holds the projector: the switch-off waits for it.
    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(tileOf('Keystone'));
    await tester.pump(const Duration(milliseconds: 100));
    // Free grid still shows, and its segments are live meanwhile.
    await tester.tap(find.text('PC-2'));
    await tester.pump(const Duration(milliseconds: 100));
    workspace().releaseNodeFromExternalPoll(_node.id);
    await pumpFor(tester, 2000);
    await settle(tester);

    final shown = selectedTile(tester);
    final mode = fake.warpFor(_ip).mode;
    expect(
      (shown, mode),
      anyOf(('Keystone', 1), ('Free grid', 4)),
      reason: 'the tiles show $shown, the projector is in mode $mode',
    );
  });

  dialogTest('QA-013 while the switch-off waits, every control of the editor '
      'is out of reach and nothing moves', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);
    final before = tester.getRect(find.byType(GeometryCorrectionDialog));
    final cardBefore = tester.getRect(
      find.byKey(const ValueKey('free-grid-controls-card')),
    );

    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(tileOf('Keystone'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<SegmentedTabs<WarpSlot?>>(
            find.byType(SegmentedTabs<WarpSlot?>),
          )
          .enabled,
      isFalse,
    );
    expect(tapIsRefused(tester, reloadButton), isTrue);
    expect(tapIsRefused(tester, moreButton), isTrue);
    expect(tester.widget<Switch>(overlaySwitch).onChanged, isNull);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('free-grid-switch-cursor')))
          .onChanged,
      isNull,
    );
    expect(
      tapIsRefused(tester, find.byKey(const ValueKey('free-grid-zoom-in'))),
      isTrue,
    );
    for (final label in ['Off', 'Curved Correction', 'Corner Correction']) {
      expect(
        tester.widget<ModeTile>(tileOf(label)).onTap,
        isNull,
        reason: label,
      );
    }
    expect(tester.getRect(find.byType(GeometryCorrectionDialog)), before);
    expect(
      tester.getRect(find.byKey(const ValueKey('free-grid-controls-card'))),
      cardBefore,
    );

    // Nothing was sent to the session meanwhile (no read, no GMMI0).
    final reads = fake.sentBinary.length;
    await tester.tap(find.text('PC-2'));
    await tester.tap(reloadButton);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.sentBinary.length, reads);
    expect(fake.sentCommands, isEmpty);

    workspace().releaseNodeFromExternalPoll(_node.id);
    await settle(tester);
    expect(selectedTile(tester), 'Keystone');
    expect(fake.warpFor(_ip).mode, 1);
  });

  // ------------------------------------------------------------- QA-014

  dialogTest('QA-014 turning the overlay off while a poll holds the projector '
      'for over a second still takes it off', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);
    expect(overlayFrames().last[4], 1);

    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(overlaySwitch);
    await pumpFor(tester, 1500);
    workspace().releaseNodeFromExternalPoll(_node.id);
    await settle(tester);
    expect(tester.widget<Switch>(overlaySwitch).value, isFalse);

    // The operator leaves the mode: the projector must not keep the overlay.
    await tester.tap(tileOf('Keystone'));
    await settle(tester);
    expect(selectedTile(tester), 'Keystone');
    expect(
      overlayFrames().last[4],
      0,
      reason:
          'the off command gave up after 1 s; the switch reads off, so '
          'leaving the mode sends nothing either',
    );
  });

  dialogTest('QA-014 an off that cannot be sent: the switch goes back on, the '
      'footer says so, and leaving sends the off again', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);

    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(overlaySwitch);
    await pumpFor(tester, 5500);
    await settle(tester);
    expect(
      tester.widget<Switch>(overlaySwitch).value,
      isTrue,
      reason: 'the overlay is still on the projector',
    );
    expect(
      find.text('The grid overlay could not be turned off. Try again.'),
      findsOneWidget,
    );
    expect(overlayFrames().last[4], 1);
    expect(
      container
          .read(eventLogProvider)
          .where((e) => e.message.startsWith('Grid overlay may still be on')),
      hasLength(1),
    );

    // The poll lets go; the operator leaves the mode: the off goes out.
    workspace().releaseNodeFromExternalPoll(_node.id);
    await tester.tap(tileOf('Keystone'));
    await settle(tester);
    expect(selectedTile(tester), 'Keystone');
    expect(overlayFrames().last[4], 0);
  });

  dialogTest('QA-014 an off that cannot be sent is tried again when the dialog '
      'closes', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable());
    await openDialog(tester, mode: 3);
    await tester.tap(overlaySwitch);
    await settle(tester);
    expect(workspace().claimNodeForExternalPoll(_node.id), isTrue);
    await tester.tap(overlaySwitch);
    await pumpFor(tester, 5500);
    await settle(tester);
    workspace().releaseNodeFromExternalPoll(_node.id);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.byType(GeometryCorrectionDialog), findsNothing);
    expect(overlayFrames().last[4], 0);
  });

  // ------------------------------------------------------- 14.2 checks

  dialogTest('14.2 Esc, a click outside and the close button do not dismiss '
      'while a Reset runs', (tester) async {
    _seed(fake, WarpSlot.pc1, _gridTable(dx: 80));
    await openDialog(tester, mode: 3);
    fake.holdBinary[_ip] = Completer<void>();
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('free-grid-menu-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PC-1'));
    await pumpFor(tester, 600);
    expect(session().phase, WarpSessionPhase.storing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, 400);
    expect(find.byType(GeometryCorrectionDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await pumpFor(tester, 400);
    expect(find.byType(GeometryCorrectionDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, 400);
    expect(find.byType(GeometryCorrectionDialog), findsOneWidget);

    fake.holdBinary.remove(_ip)!.complete();
    await settle(tester);
    expect(session().phase, WarpSessionPhase.ready);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(GeometryCorrectionDialog), findsNothing);
  });

  // ------------------------------------------------------------- QA-015

  group('QA-015 keyboard focus when the dialog opens', () {
    bool focusIsInDialog(WidgetTester tester) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      var inside = false;
      context.visitAncestorElements((e) {
        if (e.widget is GeometryCorrectionDialog) {
          inside = true;
          return false;
        }
        return true;
      });
      return inside;
    }

    dialogTest('opened from a menu, Esc closes it', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialogFromMenu(tester, mode: 3);
      expect(find.byType(GeometryCorrectionDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
    });

    dialogTest('opened from a menu, Tab goes into the dialog', (tester) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialogFromMenu(tester, mode: 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsInDialog(tester), isTrue);
    });

    dialogTest('the Off state and the other modes get focus too', (
      tester,
    ) async {
      await openDialogFromMenu(tester, mode: 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsInDialog(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
    });

    dialogTest('focus moved elsewhere while it is open comes back for Esc', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      // Something outside takes the focus (a menu closing, a window coming
      // back).
      final outside = FocusNode();
      addTearDown(outside.dispose);
      FocusManager.instance.rootScope.requestFocus(outside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(GeometryCorrectionDialog), findsNothing);
    });

    dialogTest('the help button is reached by Tab and shows its tooltip', (
      tester,
    ) async {
      _seed(fake, WarpSlot.pc1, _gridTable());
      await openDialog(tester, mode: 3);
      final help = find.byKey(const ValueKey('free-grid-help'));
      var reached = false;
      for (var i = 0; i < 40 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) continue;
        context.visitAncestorElements((e) {
          if (e.widget.key == const ValueKey('free-grid-help')) {
            reached = true;
            return false;
          }
          return true;
        });
      }
      expect(reached, isTrue, reason: 'Tab never reached the help button');
      expect(help, findsOneWidget);
      // The keyboard has no hover: the focus shows the tooltip.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Mouse and keyboard'), findsOneWidget);
      // Tabbing on takes it away.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Mouse and keyboard'), findsNothing);
      expect(
        tester
            .widget<CustomTooltip>(
              find.descendant(of: help, matching: find.byType(CustomTooltip)),
            )
            .message,
        'Mouse and keyboard',
      );
    });
  });
}
