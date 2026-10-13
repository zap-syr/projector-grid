import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
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

ProjectorNode _node(String name) =>
    ProjectorNode(id: name, name: name, ipAddress: '10.0.0.1', x: 0, y: 0);

EdgeBlendState _blankState() =>
    parseEdgeBlendState(List.filled(edgeBlendQueries().length, null)).$1
        .copyWith(mode: EdgeBlendMode.on);

/// Single-mode events carry no side; pair mode prefixes the side index.
String _ev(List<String> parts, int side, bool pair) =>
    (pair ? ['$side', ...parts] : parts).join(' ');

void main() {
  late List<String> events;
  late List<EdgeBlendState> states;
  late List<BlackLevelState?> blacks;
  late int active;

  // Side 0, for the single-mode tests.
  late EdgeBlendState state;
  late BlackLevelState? black;
  void sync() {
    state = states[0];
    black = blacks[0];
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<EdgeBlendState> initial,
    bool blackLevel = false,
    int activeSide = 0,
  }) {
    events = [];
    states = [...initial];
    active = activeSide;
    blacks = [
      for (final _ in initial)
        blackLevel
            ? parseBlackLevelState(
                List.filled(blackLevelQueries().length, null),
              ).withBorderWidth(BlendEdge.left, 100)
            : null,
    ];
    sync();
    final pair = initial.length == 2;
    EdgeSelection? selection;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: _canvasSize,
              child: StatefulBuilder(
                builder: (context, setState) => EdgeBlendCanvas(
                  sides: [
                    for (var i = 0; i < states.length; i++)
                      BlendCanvasSide(
                        node: _node(i == 0 ? 'A' : 'B'),
                        raster: _raster,
                        state: states[i],
                        black: blacks[i],
                      ),
                  ],
                  active: active,
                  blackTab: blackLevel,
                  selection: selection,
                  onActivate: (i) {
                    events.add('activate $i');
                    setState(() => active = i);
                  },
                  onSelect: (i, edge, part) {
                    events.add(_ev(['select', edge.name, part.name], i, pair));
                    setState(
                      () => selection = (side: i, edge: edge, part: part),
                    );
                  },
                  onClearSelection: () {
                    events.add('clear');
                    setState(() => selection = null);
                  },
                  onPreview: (i, edge, part, v) {
                    events.add(
                      _ev(['preview', edge.name, part.name, '$v'], i, pair),
                    );
                    setState(() {
                      if (part == EdgePart.border) {
                        blacks[i] = blacks[i]!.withBorderWidth(edge, v);
                      } else {
                        states[i] = states[i].withEdge(
                          edge,
                          states[i][edge].withPart(part, v),
                        );
                      }
                      sync();
                    });
                  },
                  onCommit: (i, edge, part) => events.add(
                    _ev(['commit', edge.name, part.name], i, pair),
                  ),
                  onResetEdge: (i, edge) =>
                      events.add(_ev(['reset', edge.name], i, pair)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpCanvas(
    WidgetTester tester, {
    bool interactive = true,
    bool blackLevel = false,
    EdgeSettings left = const EdgeSettings(enabled: true, start: 0, width: 192),
  }) {
    final s = _blankState().withEdge(BlendEdge.left, left);
    return pump(
      tester,
      initial: [interactive ? s : s.copyWith(mode: EdgeBlendMode.off)],
      blackLevel: blackLevel,
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

  group('pair, side by side', () {
    // Same 520×340 canvas, 36 px pill band on top: each raster 244×152.5,
    // the 488 px extent from x 16, y 111.75. Facing widths 192 (0.1 of the
    // raster) overlap the pair by 24.4 px, centred: A at 16 + 12.2, B at
    // 16 + 244 − 12.2.
    const unit = 244 / 1920;
    const aRight = 16 + 12.2 + 244;
    const bLeft = 16 + 244 - 12.2;
    const midY = 111.75 + 152.5 / 2;
    const facing = EdgeSettings(enabled: true, start: 0, width: 192);

    Future<void> pumpPair(
      WidgetTester tester, {
      int activeSide = 0,
      int widthB = 192,
    }) => pump(
      tester,
      initial: [
        _blankState().withEdge(BlendEdge.right, facing),
        _blankState()
            .withEdge(BlendEdge.left, facing.copyWith(width: widthB))
            .withEdge(BlendEdge.right, facing),
      ],
      activeSide: activeSide,
    );

    Offset at(WidgetTester tester, double x) =>
        tester.getTopLeft(find.byType(EdgeBlendCanvas)) + Offset(x, midY);

    testWidgets('the ramps share pixels: active projector wins the handle', (
      tester,
    ) async {
      // A's Start line (A.Right) and B's zone end (B.Left width) share x.
      await pumpPair(tester);
      await tester.tapAt(at(tester, aRight));
      await tester.pump();
      expect(events, ['0 select right start']);

      await pumpPair(tester, activeSide: 1);
      await tester.tapAt(at(tester, aRight));
      await tester.pump();
      expect(events, ['1 select left width']);
    });

    testWidgets("the other projector's own handle is reachable", (
      tester,
    ) async {
      await pumpPair(tester);
      // B.Right zone end: 192 units in from B's right edge.
      await tester.tapAt(at(tester, bLeft + 244 - 192 * unit));
      await tester.pump();
      expect(events, ['1 select right width']);
    });

    testWidgets("dragging B's facing Start follows the pointer, though both "
        'rasters move with it', (tester) async {
      await pumpPair(tester, activeSide: 1);
      // B.Start and A's zone end share x; B is active, so its Start.
      await tester.dragFrom(at(tester, bLeft), const Offset(24.4, 0));
      await tester.pump();
      expect(states[1][BlendEdge.left].start, inInclusiveRange(188, 196));
      expect(events.last, '1 commit left start');
    });

    testWidgets('the wider facing Width moves both rasters by half', (
      tester,
    ) async {
      await pumpPair(tester);
      // A.Right zone end, dragged 24.4 px inward: width 192 → 384.
      await tester.dragFrom(at(tester, bLeft), const Offset(-24.4, 0));
      await tester.pump();
      expect(states[0][BlendEdge.right].width, inInclusiveRange(380, 388));
      events.clear();
      // Overlap 0.2: A's right edge, and its Start line, 12.2 px further
      // right.
      await tester.tapAt(at(tester, aRight + 12.2));
      await tester.pump();
      expect(events, ['0 select right start']);
    });

    testWidgets("the narrower facing Width doesn't move the rasters", (
      tester,
    ) async {
      await pumpPair(tester, widthB: 96);
      await tester.tapAt(at(tester, aRight));
      await tester.pump();
      expect(events, ['0 select right start']);
    });

    testWidgets('a pill switches the active projector', (tester) async {
      await pumpPair(tester);
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(events, ['activate 1']);
    });
  });
}
