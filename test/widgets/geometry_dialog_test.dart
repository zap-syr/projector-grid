import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/geometry_values.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_correction_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_preview_painter.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// Holds every query starting with a prefix given to [hold] until
/// [release], so a test can look at a loading layout.
class _HoldingFake extends FakeProtocolService {
  String? _prefix;
  Completer<void>? _gate;

  /// Call inside the test body: the completer must belong to the test's
  /// fake-async zone, or its completion never runs while pumping.
  void hold(String prefix) {
    _prefix = prefix;
    _gate = Completer<void>();
  }

  void release() {
    _prefix = null;
    _gate?.complete();
  }

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    final p = _prefix;
    final gate = _gate;
    if (p != null && gate != null && cmd.startsWith(p)) await gate.future;
    return super.sendRawCommand(ip, port, login, password, cmd);
  }
}

void main() {
  useTempConfigDir();

  late _HoldingFake fake;

  setUp(() => fake = _HoldingFake());

  const full = Size(1920, 1080);
  const small = Size(800, 600);

  Future<void> pumpDialog(
    WidgetTester tester, {
    String mode = '+00000',
    String model = 'PT-RQ25K',
    Size size = full,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fake.rawResponses.addAll({'QVX:GMMI0': 'GMMI0=$mode', 'QID': model});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const GeometryCorrectionDialog(
                      node: ProjectorNode(
                        id: '1',
                        name: 'P',
                        ipAddress: '10.0.0.1',
                        x: 0,
                        y: 0,
                      ),
                    ),
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
    // Skeletons pulse forever, so settle only once everything is read.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (settle) await tester.pumpAndSettle();
  }

  String selectedMode(WidgetTester tester) => tester
      .widgetList<ModeTile>(find.byType(ModeTile))
      .singleWhere((t) => t.selected)
      .label;

  List<String> writes() => [
    for (final (_, cmd) in fake.sentRaw)
      if (cmd.startsWith('VXX:')) cmd,
  ];

  // The Off state's cards repeat the mode names: tap the tile's.
  Finder tile(String label) =>
      find.descendant(of: find.byType(ModeTile), matching: find.text(label));

  Future<void> selectMode(WidgetTester tester, String label) async {
    await tester.tap(tile(label));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  group('modes and loading', () {
    testWidgets('loads the current mode and its parameters', (tester) async {
      await pumpDialog(tester, mode: '+00010');
      expect(selectedMode(tester), 'Corner Correction');
      final queried = fake.sentRaw.map((s) => s.$2);
      expect(
        queried,
        containsAll(['QVX:GMMI0', 'QID', 'QVX:GMFI1', 'QVX:GMFIF']),
      );
      expect(writes(), isEmpty, reason: 'opening must not write anything');
      expect(
        find.text('Changes are sent to the projector right away'),
        findsOne,
      );
    });

    testWidgets('unknown mode reply falls back to Off', (tester) async {
      await pumpDialog(tester, mode: '+00099');
      expect(selectedMode(tester), 'Off');
      expect(find.text('Geometry correction is off'), findsOneWidget);
    });

    testWidgets('switching mode sends VXX:GMMI0 and loads that mode', (
      tester,
    ) async {
      await pumpDialog(tester, model: 'PT-RZ120');
      await selectMode(tester, 'Keystone');
      expect(writes(), ['VXX:GMMI0=+00001']);
      expect(fake.sentRaw.map((s) => s.$2), contains('QVX:GMKS0'));
      expect(selectedMode(tester), 'Keystone');
      expect(find.byType(GeometryPreviewCanvas), findsOneWidget);
    });

    testWidgets('Quad Pixel Drive models enable QPD before leaving Off', (
      tester,
    ) async {
      await pumpDialog(tester, model: 'PT-RQ32K');
      await selectMode(tester, 'Corner Correction');
      expect(writes(), ['VXX:QPDI1=+00001', 'VXX:GMMI0=+00010']);

      // Only from Off: mode to mode doesn't re-send it.
      await selectMode(tester, 'Keystone');
      expect(writes().last, 'VXX:GMMI0=+00001');
      expect(writes().where((w) => w.startsWith('VXX:QPDI1')), hasLength(1));
    });

    testWidgets('a failed write shows the failure notice', (tester) async {
      await pumpDialog(tester, model: 'PT-RZ120');
      fake.rawResponses['VXX:GMMI0=+00002'] = null;
      await selectMode(tester, 'Curved Correction');
      expect(find.text('Failed to send: VXX:GMMI0=+00002'), findsOneWidget);
    });

    testWidgets('a mode loads in the full layout, not a spinner alone', (
      tester,
    ) async {
      await pumpDialog(tester, model: 'PT-RZ120');
      fake.hold('QVX:GMFI');
      await tester.tap(tile('Corner Correction'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Reading Corner Correction from the projector'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Mode is already switched. The controls appear once the 15 '
          'values are read.',
        ),
        findsOneWidget,
      );
      expect(find.text('Corners'), findsOneWidget);
      expect(
        find.text('Reading current values from the projector…'),
        findsOneWidget,
      );
      fake.release();
      await tester.pumpAndSettle();
      expect(find.text('Upper left'), findsOneWidget);
      expect(
        find.text('Changes are sent to the projector right away'),
        findsOne,
      );
    });
  });

  group('Off', () {
    testWidgets('Tier A gets the full Quad Pixel Drive note', (tester) async {
      await pumpDialog(tester, model: 'PT-RQ25K');
      expect(key('quad-pixel-note'), findsOneWidget);
      expect(find.textContaining('wider inward range'), findsOneWidget);
    });

    testWidgets('Tier B only the first sentence', (tester) async {
      await pumpDialog(tester, model: 'PT-RQ32K');
      expect(key('quad-pixel-note'), findsOneWidget);
      expect(find.textContaining('wider inward range'), findsNothing);
      expect(
        find.textContaining('turns on by itself when you choose a mode.'),
        findsOneWidget,
      );
    });

    testWidgets('other models have no note', (tester) async {
      await pumpDialog(tester, model: 'PT-RZ120');
      expect(key('quad-pixel-note'), findsNothing);
    });
  });

  group('Reset', () {
    testWidgets('Keystone resets angles and balance, keeps throw ratio', (
      tester,
    ) async {
      fake.rawResponses.addAll({
        'QVX:GMKS0': 'GMKS0=+02.0',
        'QVX:GMKS8': 'GMKS8=+12.4',
        'QVX:GMKI4': 'GMKI4=+00010',
      });
      await pumpDialog(tester, mode: '+00001');
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(writes(), [
        'VXX:GMKS8=+0.0',
        'VXX:GMKS9=+0.0',
        'VXX:GMKI4=+00000',
        'VXX:GMKI7=+00000',
      ]);
      expect(find.text('2.0'), findsOneWidget, reason: 'throw ratio kept');
    });

    testWidgets('Curved resets arcs, keystone and balance', (tester) async {
      fake.rawResponses['QVX:GMCIA'] = 'GMCIA=+00001';
      await pumpDialog(tester, mode: '+00002');
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(writes(), [
        'VXX:GMCI2=+00000',
        'VXX:GMCI3=+00000',
        'VXX:GMCI6=+00000',
        'VXX:GMCI7=+00000',
        'VXX:GMCS8=+0.0',
        'VXX:GMCS9=+0.0',
      ]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('Reset all in Corner writes the eight corner values', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00010');
      await tester.tap(find.text('Reset all'));
      await tester.pumpAndSettle();
      expect(writes(), [
        for (final k in [1, 2, 3, 4, 6, 7, 8, 9]) 'VXX:GMFI$k=+00000',
      ]);
    });
  });

  group('Corner', () {
    testWidgets('typing H commits clamped to the tier and sends the pair', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00010', model: 'PT-RZ120');
      final field = find.descendant(
        of: key('corner-h-ul'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '2000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes(), ['VXX:GMFI6=+00480', 'VXX:GMFI1=+00000']);
      expect(key('corner-moved-ul'), findsOneWidget);
    });

    testWidgets('Tier A allows the wider inward range', (tester) async {
      await pumpDialog(tester, mode: '+00010', model: 'PT-RQ25K');
      expect(find.text('Extended inward range'), findsOneWidget);
      final field = find.descendant(
        of: key('corner-v-lr'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '-2000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes(), ['VXX:GMFI9=+00000', 'VXX:GMFI4=-00600']);
    });

    testWidgets('row clicks select corners, Ctrl adds, the pill follows', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00010');
      await tester.tap(find.text('Upper right'));
      await tester.pump();
      expect(find.text('Upper right'), findsNWidgets(2), reason: 'pill');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Lower left'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('arrow keys move the selected corner, sent on release', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00010', model: 'PT-RZ120');
      await tester.tap(key('corner-handle-ul'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(writes(), [
        'VXX:GMFI6=+00001',
        'VXX:GMFI1=+00000',
        'VXX:GMFI6=+00001',
        'VXX:GMFI1=+00001',
      ]);
    });

    testWidgets('double click resets a corner', (tester) async {
      fake.rawResponses['QVX:GMFI7'] = 'GMFI7=-00100';
      await pumpDialog(tester, mode: '+00010', model: 'PT-RZ120');
      await tester.tap(key('corner-handle-ur'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(key('corner-handle-ur'));
      await tester.pumpAndSettle();
      expect(writes(), ['VXX:GMFI7=+00000', 'VXX:GMFI2=+00000']);
    });

    for (final size in [full, small]) {
      testWidgets('dragging works at the canvas scale (${size.width})', (
        tester,
      ) async {
        await pumpDialog(tester, mode: '+00010', model: 'PT-RZ120', size: size);
        final scale = tester.getSize(key('corner-canvas')).width / 480;
        if (size == small) expect(scale, lessThan(1));
        // Past the pan slop first: the drag counts from where it starts.
        final gesture = await tester.startGesture(
          tester.getCenter(key('corner-handle-ul')),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        final raw = cornerToRaw(
          30 / scale,
          inwardIsPositive: true,
          extended: false,
        );
        expect(writes(), ['VXX:GMFI6=${formatNtInt(raw)}', 'VXX:GMFI1=+00000']);
      });
    }

    testWidgets('Auto disables linearity and pincushion', (tester) async {
      await pumpDialog(tester, mode: '+00010');
      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      expect(sliders, hasLength(6));
      expect(sliders.every((s) => s.onChanged == null), isTrue);

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      expect(writes(), ['VXX:GMFIF=+00001']);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .every((s) => s.onChanged != null),
        isTrue,
      );
    });
  });

  group('layout', () {
    // Where the shared pieces sit: none may move between modes or states.
    Map<String, Rect> frame(WidgetTester tester, {bool cards = true}) => {
      'tiles': tester.getRect(key('geometry-mode-tiles')),
      'footer': tester.getRect(find.byType(DialogFooter)),
      if (cards) 'canvas': tester.getRect(key('geometry-canvas-card')),
      if (cards) 'controls': tester.getRect(key('geometry-controls-card')),
    };

    Rect dialogBox(WidgetTester tester) => tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );

    for (final size in [full, small]) {
      testWidgets('nothing moves between modes and loading (${size.width})', (
        tester,
      ) async {
        await pumpDialog(tester, mode: '+00001', size: size);
        expect(tester.takeException(), isNull);
        final keystone = frame(tester);
        final box = dialogBox(tester);

        await selectMode(tester, _label(size, 'Curved Correction'));
        expect(tester.takeException(), isNull);
        expect(frame(tester), keystone);

        fake.hold('QVX:GMFI');
        await tester.tap(tile(_label(size, 'Corner Correction')));
        await tester.pump();
        await tester.pump();
        expect(frame(tester), keystone, reason: 'loading Corner');
        fake.release();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(frame(tester), keystone, reason: 'Corner');

        await selectMode(tester, 'Off');
        expect(tester.takeException(), isNull);
        final off = frame(tester, cards: false);
        expect(off['tiles'], keystone['tiles']);
        expect(off['footer'], keystone['footer']);
        expect(dialogBox(tester), box);

        await selectMode(tester, 'Keystone');
        expect(frame(tester), keystone, reason: 'back to Keystone');

        expect(box.width, lessThanOrEqualTo(920));
        expect(box.height, lessThanOrEqualTo(720));
      });
    }

    testWidgets('opening shows the frame before the mode is read', (
      tester,
    ) async {
      fake.hold('QVX:GMMI0');
      await pumpDialog(tester, mode: '+00001', settle: false);
      final loading = frame(tester);
      expect(
        find.text('Reading geometry correction from the projector'),
        findsOneWidget,
      );
      fake.release();
      await tester.pumpAndSettle();
      expect(frame(tester), loading);
    });

    testWidgets('800x600: short mode labels with the full name in a tooltip', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00002', size: small);
      expect(tester.takeException(), isNull);
      expect(find.text('Curved'), findsOneWidget);
      expect(find.text('Corner'), findsOneWidget);
      expect(find.text('Curved Correction'), findsNothing);
      expect(find.text('Approximate'), findsOneWidget);
      expect(
        find.text(
          'The drawing is approximate, check the result on the screen.',
        ),
        findsNothing,
      );
    });

    testWidgets('800x600: the Corner controls scroll with a scrollbar', (
      tester,
    ) async {
      await pumpDialog(tester, mode: '+00010', size: small);
      expect(tester.takeException(), isNull);
      final card = key('geometry-controls-card');
      expect(
        find.descendant(of: card, matching: find.byType(Scrollbar)),
        findsOneWidget,
      );
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: card, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(find.text('Corner range'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    });

    testWidgets('full size: legend, note and Schematic pill', (tester) async {
      await pumpDialog(tester, mode: '+00001');
      expect(find.text('Schematic'), findsOneWidget);
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);
      expect(
        find.text(
          'The drawing is approximate, check the result on the screen.',
        ),
        findsOneWidget,
      );
    });
  });
}

String _label(Size size, String full) => size.width < 1000
    ? switch (full) {
        'Curved Correction' => 'Curved',
        'Corner Correction' => 'Corner',
        _ => full,
      }
    : full;
