import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/labeled_slider_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blending_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/sleek_stepper_input.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

const _a = ProjectorNode(
  id: 'a',
  name: 'PRJ-01',
  ipAddress: '10.0.0.1',
  x: 0,
  y: 0,
);
const _b = ProjectorNode(
  id: 'b',
  name: 'PRJ-02',
  ipAddress: '10.0.0.2',
  x: 200,
  y: 0,
);

const _full = Size(1920, 1080);
const _small = Size(800, 600);

void main() {
  useTempConfigDir();

  late FakeProtocolService fake;

  setUp(() {
    fake = FakeProtocolService();
    fake.rawResponses.addAll({
      'QVX:EDBI0': 'EDBI0=+00001',
      'QID': 'PT-RQ35K',
      'QGL': '1',
      'QGR': '1',
      'QVX:ELWI0': 'ELWI0=+00192',
      'QVX:ERWI0': 'ERWI0=+00192',
      'QJI': '000,000,000,000',
    });
  });

  /// B answers nothing at all.
  void silenceB() => fake.rawResponsesByIp[_b.ipAddress] = {
    for (final q in edgeBlendQueries()) q: null,
  };

  Future<void> pump(
    WidgetTester tester, {
    bool pair = false,
    Size size = _full,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // A fresh tree, so a second pump in one test opens a new dialog.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    // Not const: the dialog's assert reads the length.
                    builder: (_) =>
                        EdgeBlendingDialog(nodes: pair ? [_a, _b] : [_a]),
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
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(edgeBlendTabsKey),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

  Map<Key, Rect> frame(WidgetTester tester) => {
    for (final k in [
      edgeBlendModeTilesKey,
      edgeBlendTabsKey,
      edgeBlendCanvasCardKey,
      edgeBlendControlsCardKey,
    ])
      k: rectOf(tester, k),
  };

  List<(String, String)> writes(String prefix) => [
    for (final (ip, cmd) in fake.sentRaw)
      if (cmd.startsWith(prefix)) (ip, cmd),
  ];

  group('pair', () {
    testWidgets('the facing card carries the Link chip, linked', (
      tester,
    ) async {
      await pump(tester, pair: true);
      expect(find.text('Linked with B Left'), findsOneWidget);
      expect(
        find.textContaining('Edges of A', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('the linked overlapped row shows the link icon', (
      tester,
    ) async {
      await pump(tester, pair: true);
      await tapTab(tester, 'Black Level');
      expect(
        find.descendant(
          of: find.byKey(edgeBlendControlsCardKey),
          matching: find.byIcon(Icons.link),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Link turned on before Black Level loads copies the level '
        'once it has', (tester) async {
      fake.rawResponsesByIp[_a.ipAddress] = {
        'QVX:EBBS3': 'EBBS3=010,010,010,010',
      };
      await pump(tester, pair: true);
      await tester.tap(find.text('Linked with B Left'));
      await tester.pumpAndSettle();
      expect(find.text('Link with B Left'), findsOneWidget);
      await tester.tap(find.text('Link with B Left'));
      await tester.pumpAndSettle();
      fake.sentRaw.clear();
      await tapTab(tester, 'Black Level');
      expect(
        fake.sentRaw,
        contains((_b.ipAddress, 'VXX:EBBS2=010,010,010,010')),
      );
    });

    testWidgets('the A / B switch switches the active projector', (
      tester,
    ) async {
      await pump(tester, pair: true);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('edge-blend-projector-switch')),
          matching: find.text(_b.ipAddress),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Edges of B', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Linked with A Right'), findsOneWidget);
    });

    testWidgets('Markers writes both projectors', (tester) async {
      await pump(tester, pair: true);
      await tester.tap(find.byKey(const ValueKey('edge-blend-markers')));
      await tester.pumpAndSettle();
      expect(
        writes('VGM'),
        unorderedEquals([(_a.ipAddress, 'VGM:1'), (_b.ipAddress, 'VGM:1')]),
      );
    });

    testWidgets('B not replying: Markers goes to A only, B keeps its place', (
      tester,
    ) async {
      await pump(tester, pair: true);
      final online = frame(tester);

      silenceB();
      await pump(tester, pair: true);
      expect(find.text('B not replying'), findsOneWidget);
      expect(find.text('Link needs B'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(frame(tester), online);

      await tester.tap(find.byKey(const ValueKey('edge-blend-markers')));
      await tester.pumpAndSettle();
      expect(writes('VGM'), [(_a.ipAddress, 'VGM:1')]);
    });

    testWidgets('the overlap readout follows the facing widths', (
      tester,
    ) async {
      await pump(tester, pair: true);
      // 192 of 3840 on both: the wider Width, 5% of a raster.
      expect(find.text('Overlap 192 px, 5% of a raster'), findsOneWidget);
    });
  });

  group('edges', () {
    testWidgets('a disabled edge collapses to one row', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('edge-left-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('edge-upper-start')), findsNothing);
      expect(find.byKey(const ValueKey('edge-upper-width')), findsNothing);
      expect(find.text('Off'), findsWidgets);
    });

    testWidgets('a disabled edge keeps its border width shown but disabled', (
      tester,
    ) async {
      await pump(tester);
      await tapTab(tester, 'Black Level');
      bool ignored(String edge) => tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('border-width-$edge')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring;
      expect(find.byKey(const ValueKey('border-width-upper')), findsOneWidget);
      expect(ignored('upper'), isTrue);
      expect(ignored('left'), isFalse);
      // R, G, B of the four edges and their widths.
      expect(find.byType(SleekStepperInput), findsAtLeastNWidgets(16));
    });

    testWidgets('Start is amber, Width primary', (tester) async {
      await pump(tester);
      final context = tester.element(find.byType(EdgeBlendingDialog));
      Color? colorOf(String key) =>
          tester.widget<LabeledSliderRow>(find.byKey(ValueKey(key))).color;
      expect(colorOf('edge-left-start'), AppStatusColors.of(context).warning);
      expect(colorOf('edge-left-width'), Theme.of(context).colorScheme.primary);
    });
  });

  group('Off', () {
    testWidgets('shows the note over the canvas and keeps the layout', (
      tester,
    ) async {
      await pump(tester);
      final on = frame(tester);
      expect(find.byKey(const ValueKey('edge-blend-off-note')), findsNothing);

      fake.rawResponses['QVX:EDBI0'] = 'EDBI0=+00000';
      await pump(tester);
      expect(find.byKey(const ValueKey('edge-blend-off-note')), findsOneWidget);
      expect(find.text('Edge blending is off'), findsOneWidget);
      expect(frame(tester), on);
    });

    testWidgets('choosing Off writes the mode', (tester) async {
      await pump(tester);
      await tester.tap(find.text('No blending'));
      await tester.pumpAndSettle();
      expect(writes('VXX:EDBI0'), [(_a.ipAddress, 'VXX:EDBI0=+00000')]);
    });
  });

  group('layout', () {
    for (final size in [_full, _small]) {
      testWidgets('nothing moves between tabs, single and pair '
          '(${size.width})', (tester) async {
        await pump(tester, size: size);
        final blend = frame(tester);
        await tapTab(tester, 'Black Level');
        expect(frame(tester), blend);
        await tapTab(tester, 'Edge Blending');
        expect(frame(tester), blend);

        await pump(tester, pair: true, size: size);
        expect(frame(tester), blend);
        await tapTab(tester, 'Black Level');
        expect(frame(tester), blend);
      });

      testWidgets('the frame is in place while loading (${size.width})', (
        tester,
      ) async {
        await pump(tester, size: size);
        final loaded = frame(tester);
        // A projector that never answers: the same frame, no spinner alone.
        fake.rawResponses.clear();
        await pump(tester, size: size);
        expect(find.text('Retry'), findsOneWidget);
        expect(frame(tester), loaded);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('800x600 lays out without overflow ($brightness)', (
        tester,
      ) async {
        await pump(tester, size: _small, brightness: brightness);
        await tapTab(tester, 'Black Level');
        await pump(tester, pair: true, size: _small, brightness: brightness);
        await tapTab(tester, 'Black Level');
        silenceB();
        await pump(tester, pair: true, size: _small, brightness: brightness);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('the Black Level tab pill names the mode once read', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(BlackLevelMode.softEdgeAndBlack.pill), findsNothing);
    expect(find.text('2 edges'), findsOneWidget);
    await tapTab(tester, 'Black Level');
    expect(find.text(BlackLevelMode.softEdgeAndBlack.pill), findsOneWidget);
    expect(EdgeBlendMode.on.detail, 'Built-in blend curve');
  });
}
