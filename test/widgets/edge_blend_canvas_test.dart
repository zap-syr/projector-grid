import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_canvas.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';

// WUXGA raster in a 520×340 canvas with the 16 px margin: 488×305 at
// (16, 17.5), 0.2542 px per unit.
const _raster = (h: 1920, v: 1200);
const _canvasSize = Size(520, 340);
const _scale = 488 / 1920;
const _rasterLeft = 16.0;
const _rasterTop = 17.5;
const _rasterHeight = 305.0;

void main() {
  late List<String> events;
  late EdgeBlendState state;

  late BlackLevelState? black;

  Future<void> pumpCanvas(
    WidgetTester tester, {
    bool interactive = true,
    bool blackLevel = false,
    EdgeSettings left = const EdgeSettings(enabled: true, start: 0, width: 192),
  }) {
    events = [];
    final (s, _) = parseEdgeBlendState(
      List.filled(edgeBlendQueries().length, null),
    );
    state = s.copyWith(mode: EdgeBlendMode.on).withEdge(BlendEdge.left, left);
    black = blackLevel
        ? parseBlackLevelState(List.filled(blackLevelQueries().length, null))
              .withBorderWidth(BlendEdge.left, 100)
        : null;
    EdgePick? selection;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: _canvasSize,
              child: StatefulBuilder(
                builder: (context, setState) => EdgeBlendCanvas(
                  state: state,
                  black: black,
                  raster: _raster,
                  interactive: interactive,
                  selection: selection,
                  onSelect: (edge, part) {
                    events.add('select ${edge.name} ${part.name}');
                    setState(() => selection = (edge: edge, part: part));
                  },
                  onClearSelection: () {
                    events.add('clear');
                    setState(() => selection = null);
                  },
                  onPreview: (edge, part, v) {
                    events.add('preview ${edge.name} ${part.name} $v');
                    setState(() {
                      if (part == EdgePart.border) {
                        black = black!.withBorderWidth(edge, v);
                      } else {
                        state = state.withEdge(
                          edge,
                          state[edge].withPart(part, v),
                        );
                      }
                    });
                  },
                  onCommit: (edge, part) =>
                      events.add('commit ${edge.name} ${part.name}'),
                  onResetEdge: (edge) => events.add('reset ${edge.name}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Global position of the Left edge's Width handle (its line's midpoint).
  Offset leftWidthHandle(WidgetTester tester) {
    final origin = tester.getTopLeft(find.byType(EdgeBlendCanvas));
    final left = state[BlendEdge.left];
    return origin +
        Offset(
          _rasterLeft + (left.start + left.width) * _scale,
          _rasterTop + _rasterHeight / 2,
        );
  }

  testWidgets('overlapping handles: Width first, then Start is reachable', (
    tester,
  ) async {
    await pumpCanvas(
      tester,
      left: const EdgeSettings(enabled: true, start: 0, width: 0),
    );
    final both = leftWidthHandle(tester);
    await tester.dragFrom(both, const Offset(50, 0));
    await tester.pump();
    expect(events.last, 'commit left width');
    expect(state[BlendEdge.left].start, 0);

    events.clear();
    await tester.dragFrom(both, const Offset(20, 0));
    await tester.pump();
    expect(events.last, 'commit left start');
  });

  testWidgets('clicking a handle selects that edge and part', (tester) async {
    await pumpCanvas(tester);
    await tester.tapAt(leftWidthHandle(tester));
    await tester.pump();
    expect(events, ['select left width']);
  });

  testWidgets('clicking empty space clears the selection', (tester) async {
    await pumpCanvas(tester);
    final origin = tester.getTopLeft(find.byType(EdgeBlendCanvas));
    await tester.tapAt(origin + const Offset(260, 170));
    expect(events, ['clear']);
  });

  testWidgets('inward arrow steps 1, Shift 10, commit on key-up', (
    tester,
  ) async {
    await pumpCanvas(tester);
    await tester.tapAt(leftWidthHandle(tester));
    await tester.pump();
    events.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(events, [
      'preview left width 193',
      'commit left width',
      'preview left width 203',
      'commit left width',
      'preview left width 202',
      'commit left width',
    ]);
  });

  testWidgets('clearing the selection mid-hold ends the hold and sends', (
    tester,
  ) async {
    await pumpCanvas(tester);
    await tester.tapAt(leftWidthHandle(tester));
    await tester.pump();
    events.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(EdgeBlendCanvas));
    await tester.tapAt(origin + const Offset(260, 170));
    await tester.pump(); // the rebuild with no selection
    await tester.pump(const Duration(seconds: 1)); // past the hold delay
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(events, ['preview left width 193', 'clear', 'commit left width']);
  });

  testWidgets('arrows on the other axis are ignored', (tester) async {
    await pumpCanvas(tester);
    await tester.tapAt(leftWidthHandle(tester));
    await tester.pump();
    events.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(events, isEmpty);
  });

  testWidgets('dragging the Width handle previews, then commits once', (
    tester,
  ) async {
    await pumpCanvas(tester);
    await tester.dragFrom(leftWidthHandle(tester), const Offset(50, 0));
    await tester.pump();
    final previews = events.where((e) => e.startsWith('preview')).toList();
    expect(previews, isNotEmpty);
    // 50 px right ≈ +197 units.
    expect(state[BlendEdge.left].width, inInclusiveRange(386, 392));
    expect(events.last, 'commit left width');
    expect(events.where((e) => e.startsWith('commit')), hasLength(1));
  });

  testWidgets('dragging stops at the §8 ceiling', (tester) async {
    await pumpCanvas(tester);
    await tester.dragFrom(leftWidthHandle(tester), const Offset(1000, 0));
    await tester.pump();
    expect(state[BlendEdge.left].width, 1920);
  });

  testWidgets('double-click on a handle resets the edge', (tester) async {
    await pumpCanvas(tester);
    final handle = leftWidthHandle(tester);
    await tester.tapAt(handle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(handle);
    await tester.pump();
    expect(events.last, 'reset left');
  });

  testWidgets('Black Level: the handle moves the border width, up to '
      'raster minus blend width', (tester) async {
    await pumpCanvas(tester, blackLevel: true);
    final origin = tester.getTopLeft(find.byType(EdgeBlendCanvas));
    final handle =
        origin +
        const Offset(
          _rasterLeft + 100 * _scale,
          _rasterTop + _rasterHeight / 2,
        );
    await tester.dragFrom(handle, const Offset(50, 0));
    await tester.pump();
    expect(black!.borderWidth(BlendEdge.left), inInclusiveRange(294, 300));
    expect(state[BlendEdge.left].width, 192);
    expect(events.last, 'commit left border');

    await tester.dragFrom(
      origin +
          Offset(
            _rasterLeft + black!.borderWidth(BlendEdge.left) * _scale,
            _rasterTop + _rasterHeight / 2,
          ),
      const Offset(1000, 0),
    );
    await tester.pump();
    expect(black!.borderWidth(BlendEdge.left), 1920 - 192);
  });

  testWidgets('Black Level: arrows step the border width', (tester) async {
    await pumpCanvas(tester, blackLevel: true);
    final origin = tester.getTopLeft(find.byType(EdgeBlendCanvas));
    await tester.tapAt(
      origin +
          const Offset(
            _rasterLeft + 100 * _scale,
            _rasterTop + _rasterHeight / 2,
          ),
    );
    await tester.pump();
    expect(events, ['select left border']);
    events.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(events, ['preview left border 101', 'commit left border']);
  });

  testWidgets('mode Off: no handles to grab', (tester) async {
    await pumpCanvas(tester, interactive: false);
    await tester.dragFrom(leftWidthHandle(tester), const Offset(50, 0));
    await tester.pump();
    expect(events.where((e) => e.startsWith('preview')), isEmpty);
  });
}
