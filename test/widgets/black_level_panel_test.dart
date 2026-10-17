import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_panel.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    ({BlendEdge edge, String tooltip})? linked,
    bool interlocked = false,
    double width = 420,
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
    ).$1.copyWith(mode: EdgeBlendMode.on);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 1400,
              child: BlackLevelControls(
                black: black,
                blend: blend,
                raster: (h: 3840, v: 2400),
                selectedEdge: null,
                title: 'Edges',
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

  testWidgets('the linked edge row shows a link icon', (tester) async {
    await pumpControls(
      tester,
      linked: (edge: BlendEdge.left, tooltip: 'Linked with B Right'),
    );
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('no link icon when not linked', (tester) async {
    await pumpControls(tester);
    expect(find.byIcon(Icons.link), findsNothing);
    expect(find.byIcon(Icons.join_inner), findsOneWidget);
  });

  testWidgets('Interlocked keeps every R, G, B control in place, no W', (
    tester,
  ) async {
    for (final interlocked in [false, true]) {
      await pumpControls(tester, interlocked: interlocked);
      // Non-overlapped and border: 3 sliders each; the widths are fields.
      expect(find.byType(Slider), findsNWidgets(6), reason: '$interlocked');
      expect(find.text('W'), findsNothing);
    }
  });

  testWidgets('a narrow card puts each edge on two lines, no overflow', (
    tester,
  ) async {
    await pumpControls(tester, width: 300);
    expect(tester.takeException(), isNull);
    final upper = tester.getSize(find.byKey(const ValueKey('level-row-upper')));
    await pumpControls(tester);
    final wide = tester.getSize(find.byKey(const ValueKey('level-row-upper')));
    expect(upper.height, greaterThan(wide.height));
  });
}
