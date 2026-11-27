import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/free_grid_view.dart';
import 'package:projector_grid/features/workspace/domain/warp_control_grid.dart';
import 'package:projector_grid/features/workspace/domain/warp_model_caps.dart';
import 'package:projector_grid/features/workspace/domain/warp_session_state.dart';
import 'package:projector_grid/features/workspace/domain/warp_table.dart';

void main() {
  // A 1000 x 500 panel with 200 / 100 px of range, on a 500 x 400 canvas.
  const frame = FreeGridFrame(
    panelWidth: 1000,
    panelHeight: 500,
    rangeX: 200,
    rangeY: 100,
    canvas: Size(500, 400),
  );

  group('fit', () {
    test('the panel is centred with a 12 % margin on each side', () {
      final view = frame.fitPanel();
      // Width allows 500 * 0.76 / 1000, height 400 * 0.76 / 500.
      expect(view.zoom, closeTo(0.38, 1e-9));
      final panel = view.rectToScreen(frame.panel);
      expect(panel.center.dx, closeTo(250, 1e-9));
      expect(panel.center.dy, closeTo(200, 1e-9));
      expect(panel.left, closeTo(60, 1e-9));
      // The width is the limit: 12 % of the canvas stays free on each side.
      expect(panel.left, closeTo(500 * 0.12, 1e-9));
    });

    test('the movable range fit shows the whole range', () {
      final view = frame.fitRange();
      final range = view.rectToScreen(frame.range);
      expect(range.left, greaterThan(0));
      expect(range.right, lessThan(500));
      expect(range.top, greaterThan(0));
      expect(range.bottom, lessThan(400));
      expect(range.center.dx, closeTo(250, 1e-9));
      expect(view.zoom, lessThan(frame.fitPanel().zoom));
    });

    test('Fit alternates between the panel and the movable range', () {
      final panel = frame.fitPanel();
      expect(frame.nextFit(panel), FreeGridFit.movableRange);
      final range = frame.applyFit(frame.nextFit(panel));
      expect(range.sameAs(frame.fitRange()), isTrue);
      expect(frame.nextFit(range), FreeGridFit.panel);
      // Any other view fits the panel first.
      final moved = frame.panBy(panel, const Offset(30, 0));
      expect(frame.nextFit(moved), FreeGridFit.panel);
    });

    test('an empty canvas has a neutral view', () {
      const empty = FreeGridFrame(
        panelWidth: 100,
        panelHeight: 100,
        rangeX: 10,
        rangeY: 10,
        canvas: Size.zero,
      );
      expect(empty.fitPanel().zoom, 1);
    });
  });

  group('zoom', () {
    test('the point under the pointer stays under it', () {
      final view = frame.fitPanel();
      const anchor = Offset(130, 150);
      final before = view.toPanel(anchor);
      for (final factor in [1.25, 0.8, 2.0]) {
        final zoomed = frame.zoomAbout(view, anchor, factor);
        expect(zoomed.zoom, closeTo(view.zoom * factor, 1e-9));
        final after = zoomed.toScreen(before);
        expect(after.dx, closeTo(anchor.dx, 1e-9));
        expect(after.dy, closeTo(anchor.dy, 1e-9));
      }
    });

    test('a zoom button zooms about the canvas centre', () {
      final view = frame.fitPanel();
      final centrePoint = view.toPanel(const Offset(250, 200));
      final zoomed = frame.zoomAboutCentre(view, FreeGridFrame.zoomStep);
      final after = zoomed.toScreen(centrePoint);
      expect(after.dx, closeTo(250, 1e-9));
      expect(after.dy, closeTo(200, 1e-9));
      expect(zoomed.zoom, closeTo(view.zoom * 1.25, 1e-9));
    });

    test('out to half the movable range fit, in to 16 times the panel fit', () {
      final view = frame.fitPanel();
      final out = frame.zoomAbout(view, const Offset(250, 200), 1e-6);
      expect(out.zoom, closeTo(frame.fitRange().zoom * 0.5, 1e-9));
      expect(out.zoom, frame.minZoom);
      final inward = frame.zoomAbout(view, const Offset(250, 200), 1e6);
      expect(inward.zoom, closeTo(frame.fitPanel().zoom * 16, 1e-9));
      expect(inward.zoom, frame.maxZoom);
    });
  });

  group('pan', () {
    test('keeps 48 px of the movable range in view', () {
      final view = frame.fitPanel();
      final right = frame.panBy(view, const Offset(100000, 0));
      final rangeRight = right.rectToScreen(frame.range);
      // Its left edge stops 48 px from the canvas' right edge.
      expect(rangeRight.left, closeTo(500 - 48, 1e-9));
      final left = frame.panBy(view, const Offset(-100000, 0));
      expect(left.rectToScreen(frame.range).right, closeTo(48, 1e-9));
      final down = frame.panBy(view, const Offset(0, 100000));
      expect(down.rectToScreen(frame.range).top, closeTo(400 - 48, 1e-9));
      final up = frame.panBy(view, const Offset(0, -100000));
      expect(up.rectToScreen(frame.range).bottom, closeTo(48, 1e-9));
    });

    test('a small pan is applied as it is', () {
      final view = frame.fitPanel();
      final moved = frame.panBy(view, const Offset(12, -7));
      expect(moved.offset, view.offset + const Offset(12, -7));
      expect(moved.zoom, view.zoom);
    });

    test('a view that is too small keeps all of the range in view', () {
      // At the smallest zoom the range is narrower than 48 px on this
      // canvas.
      const small = FreeGridFrame(
        panelWidth: 100,
        panelHeight: 100,
        rangeX: 0,
        rangeY: 0,
        canvas: Size(500, 400),
      );
      final far = small.panBy(small.fitPanel(), const Offset(100000, 0));
      expect(small.canvasRect.overlaps(far.rectToScreen(small.range)), isTrue);
    });
  });

  group('the first view keeps clear of the zoom cluster', () {
    // A 1000 x 500 panel on a 360 x 190 canvas, the cluster 130 x 34 in the
    // bottom right corner.
    const size = Size(360, 190);
    const cluster = Rect.fromLTWH(360 - 8 - 130, 190 - 6 - 34, 130, 34);
    const plain = FreeGridFrame(
      panelWidth: 1000,
      panelHeight: 500,
      rangeX: 200,
      rangeY: 100,
      canvas: size,
    );
    const guarded = FreeGridFrame(
      panelWidth: 1000,
      panelHeight: 500,
      rangeX: 200,
      rangeY: 100,
      canvas: size,
      avoid: cluster,
    );

    test('without it the panel reaches the cluster', () {
      final panel = plain.fitPanel().rectToScreen(plain.panel);
      expect(panel.overlaps(cluster), isTrue);
    });

    test('with it the panel is fitted above the cluster', () {
      final view = guarded.fitPanel();
      final panel = view.rectToScreen(guarded.panel);
      expect(panel.overlaps(cluster), isFalse);
      expect(panel.bottom, lessThan(cluster.top));
      expect(panel.top, greaterThan(0));
      expect(view.zoom, lessThan(plain.fitPanel().zoom));
      // Still centred across the canvas.
      expect(panel.center.dx, closeTo(size.width / 2, 1e-9));
    });

    test('a panel that is clear of it keeps the plain fit', () {
      const roomy = Size(900, 700);
      const clear = FreeGridFrame(
        panelWidth: 1000,
        panelHeight: 500,
        rangeX: 200,
        rangeY: 100,
        canvas: roomy,
        avoid: Rect.fromLTWH(900 - 10 - 100, 700 - 8 - 34, 100, 34),
      );
      const bare = FreeGridFrame(
        panelWidth: 1000,
        panelHeight: 500,
        rangeX: 200,
        rangeY: 100,
        canvas: roomy,
      );
      expect(clear.fitPanel().sameAs(bare.fitPanel()), isTrue);
    });

    test('Fit toggles from the guarded view', () {
      final view = guarded.fitPanel();
      expect(guarded.nextFit(view), FreeGridFit.movableRange);
      expect(guarded.nextFit(guarded.fitRange()), FreeGridFit.panel);
    });
  });

  group('movable range frame', () {
    test('shows while some of its outline is in view', () {
      expect(frame.rangeFrameVisible(frame.fitRange()), isTrue);
      expect(frame.rangeFrameVisible(frame.fitPanel()), isTrue);
    });

    test('is dropped once the canvas lies inside it', () {
      final zoomed = frame.zoomAbout(
        frame.fitPanel(),
        const Offset(250, 200),
        1e6,
      );
      expect(frame.rangeFrameVisible(zoomed), isFalse);
    });

    test('is dropped when it is out of view', () {
      const wide = FreeGridFrame(
        panelWidth: 3840,
        panelHeight: 2400,
        rangeX: 1200,
        rangeY: 1200,
        canvas: Size(500, 400),
      );
      // Fitting the panel with a margin leaves the far range off the canvas.
      expect(wide.rangeFrameVisible(wide.fitPanel()), isFalse);
      expect(wide.rangeFrameVisible(wide.fitRange()), isTrue);
    });
  });

  group('point radius', () {
    test('is big on coarse grids and a dot on dense ones', () {
      expect(freeGridPointRadius(2), 4.5);
      expect(freeGridPointRadius(3), 4.5);
      expect(freeGridPointRadius(4), 4.2);
      expect(freeGridPointRadius(5), 4.2);
      expect(freeGridPointRadius(6), 4.0);
      expect(freeGridPointRadius(9), 4.0);
      expect(freeGridPointRadius(10), 3.0);
      expect(freeGridPointRadius(16), 3.0);
      expect(freeGridPointRadius(17), 2.0);
      expect(freeGridPointRadius(33), 2.0);
    });

    test('a compact canvas takes 0.5 less, never below 2', () {
      expect(freeGridPointRadius(3, compact: true), 4.0);
      expect(freeGridPointRadius(5, compact: true), closeTo(3.7, 1e-9));
      expect(freeGridPointRadius(9, compact: true), 3.5);
      expect(freeGridPointRadius(16, compact: true), 2.5);
      expect(freeGridPointRadius(17, compact: true), 2.0);
      expect(freeGridPointRadius(33, compact: true), 2.0);
    });
  });

  group('table lines', () {
    test('are at least 8 px apart on the canvas', () {
      // 32 px nodes at a zoom of 0.17 are 5.4 px apart: every second line.
      expect(freeGridDenseStride(32, 0.17), 2);
      expect(freeGridDenseStride(32, 0.5), 1);
      expect(freeGridDenseStride(16, 0.1), 5);
      for (final (step, zoom) in [(32.0, 0.05), (16.0, 0.3), (64.0, 0.01)]) {
        final stride = freeGridDenseStride(step, zoom);
        expect(stride * step * zoom, greaterThanOrEqualTo(8));
      }
    });

    test('show below 17 columns of control points', () {
      expect(freeGridDenseLinesBelowColumns, 17);
    });
  });

  group('note', () {
    final caps = lookupWarpModelCaps('001c_00_26')!;
    final wuxga = lookupWarpModelCaps('0016_00_26')!;

    test('a memory that could not be read is neutral', () {
      final note = freeGridNote(
        const WarpSessionState(phase: WarpSessionPhase.failed),
      );
      expect(note.kind, FreeGridNoteKind.notRead);
      expect(note.isWarning, isFalse);
    });

    test('the warning texts spell color the US way and name the grid', () {
      final s = WarpSessionState(
        caps: caps,
        gridCounts: (columns: 9, rows: 7),
        readOnlyReason: WarpReadOnlyReason.colourPlanes,
      );
      expect(
        freeGridWarningText(freeGridNote(s), s),
        'This memory holds one table per color, the editor cannot change it.',
      );
      final detail = WarpSessionState(
        caps: caps,
        table: identityWarpTable(caps.geometry),
        gridCounts: (columns: 9, rows: 7),
        undescribedDetail: true,
      );
      expect(
        freeGridWarningText(freeGridNote(detail), detail),
        contains('detail a 9 x 7 grid cannot describe'),
      );
      expect(
        freeGridWarningText(const FreeGridNote(FreeGridNoteKind.hint), s),
        '',
      );
    });

    WarpSessionState ready({
      WarpModelCaps? useCaps,
      WarpControlGrid? grid,
      WarpTable? table,
      WarpReadOnlyReason? readOnly,
      bool undescribed = false,
      WarpSessionPhase phase = WarpSessionPhase.ready,
    }) {
      final c = useCaps ?? caps;
      return WarpSessionState(
        phase: phase,
        caps: c,
        table: table ?? identityWarpTable(c.geometry),
        controlGrid:
            grid ??
            (readOnly == null
                ? WarpControlGrid.identity(
                    columns: 3,
                    rows: 3,
                    panelWidth: c.panelWidth,
                    panelHeight: c.panelHeight,
                  )
                : null),
        readOnlyReason: readOnly,
        undescribedDetail: undescribed,
      );
    }

    WarpControlGrid folded() {
      final grid = WarpControlGrid.identity(
        columns: 3,
        rows: 3,
        panelWidth: caps.panelWidth,
        panelHeight: caps.panelHeight,
      );
      // The centre point moves to the top left corner: its four cells fold.
      grid.points[8] = 0;
      grid.points[9] = 0;
      return grid;
    }

    test('a calm memory shows the hint', () {
      final note = freeGridNote(ready());
      expect(note.kind, FreeGridNoteKind.hint);
      expect(note.isWarning, isFalse);
    });

    test('read-only reasons come first', () {
      expect(
        freeGridNote(ready(readOnly: WarpReadOnlyReason.fit, undescribed: true))
            .kind,
        FreeGridNoteKind.readOnlyFit,
      );
      expect(
        freeGridNote(ready(readOnly: WarpReadOnlyReason.colourPlanes)).kind,
        FreeGridNoteKind.readOnlyPlanes,
      );
    });

    test('undescribed detail comes before folded cells', () {
      final note = freeGridNote(ready(grid: folded(), undescribed: true));
      expect(note.kind, FreeGridNoteKind.undescribed);
      expect(note.isWarning, isTrue);
    });

    test('points below -512 px on a WUXGA model', () {
      final table = identityWarpTable(wuxga.geometry);
      table.planes.first.points[0] = -600;
      final note = freeGridNote(
        ready(useCaps: wuxga, table: table, grid: folded()),
      );
      expect(note.kind, FreeGridNoteKind.belowLegacyLimit);
      // The same table on a model without that limit says nothing.
      final other = identityWarpTable(caps.geometry);
      other.planes.first.points[0] = -600;
      expect(freeGridNote(ready(table: other)).kind, FreeGridNoteKind.hint);
    });

    test('folded cells are counted', () {
      final note = freeGridNote(ready(grid: folded()));
      expect(note.kind, FreeGridNoteKind.folded);
      expect(note.foldedCells, foldedControlCells(folded()).length);
      expect(note.foldedCells, greaterThan(0));
    });

    test('while a memory is read or written, the backup line', () {
      expect(
        freeGridNote(const WarpSessionState(phase: WarpSessionPhase.loading))
            .kind,
        FreeGridNoteKind.loadingBackup,
      );
      expect(
        freeGridNote(ready(phase: WarpSessionPhase.storing)).kind,
        FreeGridNoteKind.storingBackup,
      );
    });
  });

  test('a time is shown as local date and minutes', () {
    expect(
      freeGridTimeLabel(DateTime(2026, 11, 20, 14, 32)),
      '2026-11-20 14:32',
    );
    expect(freeGridTimeLabel(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    // A UTC time is converted to local time first.
    final utc = DateTime.utc(2026, 11, 20, 14, 32);
    expect(freeGridTimeLabel(utc), freeGridTimeLabel(utc.toLocal()));
  });
}
