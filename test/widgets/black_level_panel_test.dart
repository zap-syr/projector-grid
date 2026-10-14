import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    ({BlendEdge edge, String tooltip})? linked,
    bool interlocked = false,
  }) {
    var black = parseBlackLevelState(
      List.filled(blackLevelQueries().length, null),
    );
    for (final slot in LevelSlot.values) {
      black = black.withLevel(
        slot,
        black[slot].copyWith(interlocked: interlocked),
      );
    }
    final blend = parseEdgeBlendState(
      List.filled(edgeBlendQueries().length, null),
    ).$1;
    return tester.pumpWidget(
      MaterialApp(
        // The test font's square glyphs are wider than the real ones; at
        // full size the fixed-width edge labels overflow.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: BlackLevelPanel(
                black: black,
                blend: blend,
                raster: (h: 3840, v: 2400),
                selectedEdge: null,
                linked: linked,
                onModeChanged: (_) {},
                onLevelChanged: (_, _, _) {},
                onLevelCommitted: (_) {},
                onInterlockedChanged: (_, _) {},
                onBorderWidthChanged: (_, _) {},
                onBorderWidthCommitted: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the linked overlapped row shows a link icon', (tester) async {
    await pumpPanel(
      tester,
      linked: (edge: BlendEdge.left, tooltip: 'Linked with PRJ-01 Right'),
    );
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('Interlocked keeps every R, G, B control in place, no W', (
    tester,
  ) async {
    for (final interlocked in [false, true]) {
      await pumpPanel(tester, interlocked: interlocked);
      // Non-overlapped and border: 3 sliders each, plus 4 border widths.
      expect(find.byType(Slider), findsNWidgets(10), reason: '$interlocked');
      expect(find.text('W'), findsNothing);
    }
  });

  testWidgets('no link icon when not linked', (tester) async {
    await pumpPanel(tester);
    expect(find.byIcon(Icons.link), findsNothing);
    expect(find.byIcon(Icons.join_inner), findsOneWidget);
  });
}
