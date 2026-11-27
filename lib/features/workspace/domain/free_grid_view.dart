import 'dart:math' as math;
import 'dart:ui';

import 'warp_codec.dart';
import 'warp_control_grid.dart';
import 'warp_session_state.dart';

/// The Free grid canvas' view math: where panel pixels land on the canvas,
/// and the zoom and pan rules. Pure, so it is tested without a widget.
///
/// A [FreeGridView] maps panel px to canvas px as `screen = panel * zoom +
/// offset`. The [FreeGridFrame] knows the panel, the movable range around it
/// and the canvas, and keeps every view it produces inside the rules.
class FreeGridView {
  const FreeGridView({required this.zoom, required this.offset});

  /// Canvas px per panel px.
  final double zoom;

  /// Where panel (0, 0) sits on the canvas.
  final Offset offset;

  Offset toScreen(Offset panel) => panel * zoom + offset;

  Offset toPanel(Offset screen) => (screen - offset) / zoom;

  Rect rectToScreen(Rect panel) =>
      Rect.fromPoints(toScreen(panel.topLeft), toScreen(panel.bottomRight));

  /// Whether this view is the same as [other] within half a pixel.
  bool sameAs(FreeGridView other) =>
      (zoom - other.zoom).abs() < 1e-6 * math.max(1, zoom) &&
      (offset - other.offset).distance < 0.5;

  @override
  bool operator ==(Object other) =>
      other is FreeGridView && other.zoom == zoom && other.offset == offset;

  @override
  int get hashCode => Object.hash(zoom, offset);
}

/// What a click on Fit does next.
enum FreeGridFit { panel, movableRange }

/// The panel, its movable range and the canvas they are shown on.
class FreeGridFrame {
  const FreeGridFrame({
    required this.panelWidth,
    required this.panelHeight,
    required this.rangeX,
    required this.rangeY,
    required this.canvas,
  });

  final int panelWidth;
  final int panelHeight;

  /// How far a point may leave the panel on each side.
  final int rangeX;
  final int rangeY;
  final Size canvas;

  /// The share of the canvas left empty on each side of the panel at the
  /// first view.
  static const double panelMargin = 0.12;

  /// A thinner margin when the whole movable range is fitted.
  static const double rangeMargin = 0.03;

  /// Zoom steps of the zoom buttons.
  static const double zoomStep = 1.25;

  /// How far out the view may go, relative to the movable range fit, and how
  /// far in, relative to the panel fit.
  static const double minZoomOfRangeFit = 0.5;
  static const double maxZoomOfPanelFit = 16;

  /// The least of the movable range, in canvas px, that must stay in view
  /// when panning.
  static const double keepInView = 48;

  Rect get panel =>
      Rect.fromLTWH(0, 0, panelWidth.toDouble(), panelHeight.toDouble());

  Rect get range => Rect.fromLTRB(
    -rangeX.toDouble(),
    -rangeY.toDouble(),
    (panelWidth + rangeX).toDouble(),
    (panelHeight + rangeY).toDouble(),
  );

  Rect get canvasRect => Offset.zero & canvas;

  FreeGridView _fit(Rect target, double margin) {
    if (canvas.isEmpty || target.isEmpty) {
      return const FreeGridView(zoom: 1, offset: Offset.zero);
    }
    final usable = 1 - 2 * margin;
    final zoom = math.min(
      canvas.width * usable / target.width,
      canvas.height * usable / target.height,
    );
    return FreeGridView(
      zoom: zoom,
      offset: canvas.center(Offset.zero) - target.center * zoom,
    );
  }

  /// The panel centred with [panelMargin] on each side: the first view.
  FreeGridView fitPanel() => _fit(panel, panelMargin);

  /// The whole movable range in view.
  FreeGridView fitRange() => _fit(range, rangeMargin);

  double get minZoom => fitRange().zoom * minZoomOfRangeFit;

  double get maxZoom => fitPanel().zoom * maxZoomOfPanelFit;

  /// What the Fit button does next: it fits the movable range when the view
  /// is the panel fit already, and the panel otherwise.
  FreeGridFit nextFit(FreeGridView view) =>
      view.sameAs(fitPanel()) ? FreeGridFit.movableRange : FreeGridFit.panel;

  FreeGridView applyFit(FreeGridFit fit) => switch (fit) {
    FreeGridFit.panel => fitPanel(),
    FreeGridFit.movableRange => fitRange(),
  };

  /// [view] with its zoom multiplied by [factor] (limited), the panel point
  /// under [anchor] staying under it.
  FreeGridView zoomAbout(FreeGridView view, Offset anchor, double factor) {
    final zoom = (view.zoom * factor).clamp(minZoom, maxZoom);
    if (zoom == view.zoom) return view;
    final panelPoint = view.toPanel(anchor);
    return clampView(
      FreeGridView(zoom: zoom, offset: anchor - panelPoint * zoom),
    );
  }

  FreeGridView zoomAboutCentre(FreeGridView view, double factor) =>
      zoomAbout(view, canvas.center(Offset.zero), factor);

  FreeGridView panBy(FreeGridView view, Offset delta) =>
      clampView(FreeGridView(zoom: view.zoom, offset: view.offset + delta));

  /// [view] with the zoom limited and the offset moved so that part of the
  /// movable range stays in view.
  FreeGridView clampView(FreeGridView view) {
    final zoom = view.zoom.clamp(minZoom, maxZoom);
    final r = Rect.fromLTRB(
      range.left * zoom,
      range.top * zoom,
      range.right * zoom,
      range.bottom * zoom,
    );
    // The range's screen edges are `r + offset`. Keep [keep] px of it
    // between the canvas edges, or all of it when it is smaller than that.
    double axis(double offset, double lo, double hi, double extent) {
      final keep = math.min(keepInView, hi - lo);
      return offset.clamp(keep - hi, extent - keep - lo);
    }

    return FreeGridView(
      zoom: zoom,
      offset: Offset(
        axis(view.offset.dx, r.left, r.right, canvas.width),
        axis(view.offset.dy, r.top, r.bottom, canvas.height),
      ),
    );
  }

  /// Whether the dashed movable range frame shows on the canvas: it does
  /// while some of its outline is in view, not when the canvas lies wholly
  /// inside it or wholly outside.
  bool rangeFrameVisible(FreeGridView view) {
    final frame = view.rectToScreen(range);
    final canvasRect = this.canvasRect;
    if (!frame.overlaps(canvasRect)) return false;
    final enclosesCanvas =
        frame.left <= 0 &&
        frame.top <= 0 &&
        frame.right >= canvas.width &&
        frame.bottom >= canvas.height;
    return !enclosesCanvas;
  }
}

/// The radius, in canvas px, of a control point on a grid of [columns]: big
/// on a coarse grid, a dot on a dense one. [compact] canvases take 0.5 less,
/// never below 2.
double freeGridPointRadius(int columns, {bool compact = false}) {
  final radius = switch (columns) {
    <= 3 => 4.5,
    <= 5 => 4.2,
    <= 9 => 4.0,
    <= 16 => 3.0,
    _ => 2.0,
  };
  return compact ? math.max(2.0, radius - 0.5) : radius;
}

/// The dense table's faint lines only show on a grid below this many
/// columns; beyond it they would hide the control grid.
const int freeGridDenseLinesBelowColumns = 17;

/// The least gap, in canvas px, between two faint table lines.
const double freeGridDenseLineGap = 8;

/// How many table nodes to skip between two drawn lines so that they are at
/// least [freeGridDenseLineGap] px apart on the canvas.
int freeGridDenseStride(double stepPanelPx, double zoom) {
  final gap = stepPanelPx * zoom;
  if (gap <= 0) return 1;
  return math.max(1, (freeGridDenseLineGap / gap).ceil());
}

/// What the canvas card's note line says, highest priority first.
enum FreeGridNoteKind {
  /// The memory cannot be shown as a grid at all.
  readOnlyFit,

  /// The memory holds one table per colour.
  readOnlyPlanes,

  /// The table has detail the grid cannot describe.
  undescribed,

  /// Some points are below the limit other tools can read.
  belowLegacyLimit,

  /// Some cells are folded; see [FreeGridNote.foldedCells].
  folded,

  /// A memory is being read.
  loadingBackup,

  /// A memory is being written.
  storingBackup,

  /// Nothing to warn about: how to select.
  hint,
}

class FreeGridNote {
  const FreeGridNote(this.kind, {this.foldedCells = 0});

  final FreeGridNoteKind kind;
  final int foldedCells;

  /// The warnings carry the warning icon.
  bool get isWarning => switch (kind) {
    FreeGridNoteKind.readOnlyFit ||
    FreeGridNoteKind.readOnlyPlanes ||
    FreeGridNoteKind.undescribed ||
    FreeGridNoteKind.belowLegacyLimit ||
    FreeGridNoteKind.folded => true,
    FreeGridNoteKind.loadingBackup ||
    FreeGridNoteKind.storingBackup ||
    FreeGridNoteKind.hint => false,
  };
}

/// The note for the session as it is now.
FreeGridNote freeGridNote(WarpSessionState s) {
  switch (s.readOnlyReason) {
    case WarpReadOnlyReason.fit:
      return const FreeGridNote(FreeGridNoteKind.readOnlyFit);
    case WarpReadOnlyReason.colourPlanes:
      return const FreeGridNote(FreeGridNoteKind.readOnlyPlanes);
    case null:
      break;
  }
  if (s.undescribedDetail) {
    return const FreeGridNote(FreeGridNoteKind.undescribed);
  }
  final grid = s.controlGrid;
  final caps = s.caps;
  final table = s.table;
  if (table != null &&
      caps != null &&
      tableBreaksLegacyReader(table, caps.bits)) {
    return const FreeGridNote(FreeGridNoteKind.belowLegacyLimit);
  }
  if (grid != null) {
    final folded = foldedControlCells(grid).length;
    if (folded > 0) {
      return FreeGridNote(FreeGridNoteKind.folded, foldedCells: folded);
    }
  }
  return switch (s.phase) {
    WarpSessionPhase.detecting || WarpSessionPhase.loading =>
      const FreeGridNote(FreeGridNoteKind.loadingBackup),
    WarpSessionPhase.storing => const FreeGridNote(
      FreeGridNoteKind.storingBackup,
    ),
    _ => const FreeGridNote(FreeGridNoteKind.hint),
  };
}

/// `2026-11-20 14:32`, local time, for a stored or backup time.
String freeGridTimeLabel(DateTime time) {
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
