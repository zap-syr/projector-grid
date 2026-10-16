import 'dart:math' as math;
import 'dart:ui' show Offset;

// Where Keystone and Curved Correction put the image on the panel, for the
// Geometry Correction preview. A port of tool/geometry_measure/geo_model.py,
// the model fitted to camera measurements of a PT-RQ25K on 2026-10-16
// (plan/GEOMETRY_PREVIEW_PLAN.md). Keep the two in step: the unit test checks
// this file against outlines exported from the Python model.
//
// The projector treats the settings as a description of the screen: a surface
// of circular arcs (Arc), tilted by the keystone angles, at a focal distance
// set by the throw ratio, seen through an optical axis that Balance shifts. It
// pre-warps the panel so the largest undistorted rectangle fits on that
// screen; the preview is that rectangle's outline on the panel.

const double _aspect = 1200 / 1920; // panel height / width, 16:10
const double _halfW = 0.5;
const double _halfH = _aspect / 2;

const double _keystoneFocalA = 1.0094; // Keystone: f = a * TR^p
const double _keystoneFocalP = 1.2111;
const double _curvedFocalP = 0.9858; // Curved: f = TR^p
const double _curvaturePerArc = 0.01508; // 1 / panel width per Arc step
const double _axisShiftPerVBalance = 0.00601; // panel widths per step
const double _axisShiftPerHBalance = -0.00907;
const double _horizontalScale =
    1.05; // Keystone applies H ~5 % above the set value

/// Image outline and centre cross on the panel, in panel coordinates (0..1 on
/// both axes, origin top left).
class GeometryPreview {
  const GeometryPreview({
    required this.outline,
    required this.centerRow,
    required this.centerColumn,
  });

  /// Clockwise from the top-left corner, `samples` points per edge with each
  /// corner ending one edge and starting the next.
  final List<Offset> outline;

  /// The image's middle row, left to right: straight in Keystone, bent with
  /// the screen in Curved.
  final List<Offset> centerRow;

  /// The image's middle column, top to bottom.
  final List<Offset> centerColumn;
}

/// The Vertical Keystone the projector applies in Keystone mode. It accepts
/// and reads back up to ±40 at any throw ratio but caps what it applies by
/// the lens, and a little more while Horizontal Keystone is set (measured).
double appliedVerticalKeystone(
  double throwRatio,
  double vertical,
  double horizontal,
) {
  final base = throwRatio < 0.85
      ? 27.0
      : throwRatio < 1.25
      ? 33.0
      : 40.0;
  final limit = base - 0.13 * horizontal.abs();
  return vertical.clamp(-limit, limit);
}

/// Keystone mode: `GMKS0` throw ratio, `GMKS8` / `GMKS9` degrees, `GMKI4` /
/// `GMKI7` balance.
GeometryPreview keystonePreview({
  required double throwRatio,
  required double vertical,
  required double horizontal,
  required int verticalBalance,
  required int horizontalBalance,
  int samples = 2,
}) {
  final screen = _Screen(
    focal: _keystoneFocalA * math.pow(throwRatio, _keystoneFocalP),
    vertical: appliedVerticalKeystone(throwRatio, vertical, horizontal),
    horizontal: horizontal * _horizontalScale,
    verticalBalance: verticalBalance,
    horizontalBalance: horizontalBalance,
  );
  return screen.preview(screen.image(keepAspect: true), samples);
}

/// Curved Correction: `GMCS0` throw ratio, `GMCI3` / `GMCI7` arcs, `GMCS8` /
/// `GMCS9` degrees, `GMCI2` / `GMCI6` balance, `GMCIA` maintain aspect ratio.
/// Keystone inside Curved was only measured up to V 30 at TR 1.5, so neither
/// the Keystone-mode cap nor its H scale is applied here.
GeometryPreview curvedPreview({
  required double throwRatio,
  required int verticalArc,
  required int horizontalArc,
  required double vertical,
  required double horizontal,
  required int verticalBalance,
  required int horizontalBalance,
  required bool keepAspect,
  int samples = 24,
}) {
  final screen = _Screen(
    focal: math.pow(throwRatio, _curvedFocalP).toDouble(),
    vertical: vertical,
    horizontal: horizontal,
    curvatureAcross: _curvaturePerArc * horizontalArc,
    curvatureDown: _curvaturePerArc * verticalArc,
    verticalBalance: verticalBalance,
    horizontalBalance: horizontalBalance,
  );
  return screen.preview(screen.image(keepAspect: keepAspect), samples);
}

/// A rectangle on the screen, in arc-length units: centre and half sizes.
typedef _Rect = ({double cx, double cy, double a, double b});

class _Screen {
  _Screen({
    required this.focal,
    required double vertical,
    required double horizontal,
    this.curvatureAcross = 0,
    this.curvatureDown = 0,
    required int verticalBalance,
    required int horizontalBalance,
  }) : _ox = _axisShiftPerHBalance * horizontalBalance,
       _oy = _axisShiftPerVBalance * verticalBalance {
    // R = Rx(-V) · Ry(H): the screen tilts about the horizontal axis, then the
    // vertical one (the other order fits the measurements three times worse).
    final a = -vertical * math.pi / 180;
    final b = horizontal * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    final cb = math.cos(b), sb = math.sin(b);
    _r = [cb, 0, sb, sa * sb, ca, -sa * cb, -ca * sb, sa, ca * cb];
  }

  final double focal;
  final double curvatureAcross;
  final double curvatureDown;
  final double _ox;
  final double _oy;
  late final List<double> _r;

  /// Screen arc-length coordinates to panel coordinates.
  Offset panel(double x, double y) {
    final (px, dzx) = _bend(x, curvatureAcross);
    final (py, dzy) = _bend(y, curvatureDown);
    final pz = -(dzx + dzy);
    final r = _r;
    final wx = r[0] * px + r[1] * py + r[2] * pz;
    final wy = r[3] * px + r[4] * py + r[5] * pz;
    final wz = r[6] * px + r[7] * py + r[8] * pz + focal;
    return Offset(
      0.5 + _ox + focal * wx / wz,
      0.5 + (_oy + focal * wy / wz) / _aspect,
    );
  }

  static (double, double) _bend(double s, double k) {
    if (k.abs() < 1e-9) return (s, 0);
    return (math.sin(k * s) / k, (1 - math.cos(k * s)) / k);
  }

  /// Every point of the rectangle's edges (13 per edge) lands on the panel.
  bool fits(double cx, double cy, double a, double b) {
    const n = 13;
    bool on(Offset p) =>
        p.dx >= -1e-9 && p.dx <= 1 + 1e-9 && p.dy >= -1e-9 && p.dy <= 1 + 1e-9;
    for (var i = 0; i < n; i++) {
      final t = -1 + 2 * i / (n - 1);
      if (!on(panel(cx + t * a, cy - b)) ||
          !on(panel(cx + a, cy + t * b)) ||
          !on(panel(cx - t * a, cy + b)) ||
          !on(panel(cx - a, cy - t * b))) {
        return false;
      }
    }
    return true;
  }

  double _maxScale(double cx, double cy, double ra, double rb) {
    var lo = 0.0, hi = 3.0;
    for (var i = 0; i < 22; i++) {
      final s = (lo + hi) / 2;
      if (fits(cx, cy, s * ra, s * rb)) {
        lo = s;
      } else {
        hi = s;
      }
    }
    return lo;
  }

  double _fitAxis(double cx, double cy, double a, double b, bool width) {
    var lo = 0.0, hi = 3 * (width ? _halfW : _halfH);
    for (var i = 0; i < 22; i++) {
      final m = (lo + hi) / 2;
      final ok = width ? fits(cx, cy, m, b) : fits(cx, cy, a, m);
      if (ok) {
        lo = m;
      } else {
        hi = m;
      }
    }
    return lo;
  }

  /// The screen point that lands on the panel centre (Newton's method). With a
  /// large Balance the screen centre itself is off the panel, so the image
  /// search starts here.
  (double, double) _panelCentrePoint() {
    var x = 0.0, y = 0.0;
    const h = 1e-6;
    for (var i = 0; i < 12; i++) {
      final p = panel(x, y);
      final fx = p.dx - 0.5, fy = p.dy - 0.5;
      if (fx.abs() < 1e-12 && fy.abs() < 1e-12) break;
      final px = panel(x + h, y), py = panel(x, y + h);
      final j11 = (px.dx - p.dx) / h, j12 = (py.dx - p.dx) / h;
      final j21 = (px.dy - p.dy) / h, j22 = (py.dy - p.dy) / h;
      final det = j11 * j22 - j12 * j21;
      x -= (j22 * fx - j12 * fy) / det;
      y -= (-j21 * fx + j11 * fy) / det;
    }
    return (x, y);
  }

  /// The largest rectangle whose projection stays on the panel: with the
  /// aspect kept, its proportions are the panel's and its centre is searched;
  /// otherwise width and height are widened in turn from the largest uniform
  /// scale (starting at full height collapses the width of a concave arc).
  _Rect image({required bool keepAspect}) {
    final (x0, y0) = _panelCentrePoint();
    if (keepAspect) {
      final c = _nelderMead((x, y) => -_maxScale(x, y, _halfW, _halfH), [
        (x0, y0),
        (x0 + 0.05, y0),
        (x0, y0 + 0.05),
      ]);
      final s = _maxScale(c.$1, c.$2, _halfW, _halfH);
      return (cx: c.$1, cy: c.$2, a: s * _halfW, b: s * _halfH);
    }
    final s = _maxScale(x0, y0, _halfW, _halfH);
    var a = s * _halfW, b = s * _halfH;
    for (var i = 0; i < 4; i++) {
      a = _fitAxis(x0, y0, a, b, true);
      b = _fitAxis(x0, y0, a, b, false);
    }
    return (cx: x0, cy: y0, a: a, b: b);
  }

  GeometryPreview preview(_Rect r, int samples) {
    assert(samples >= 2);
    final ts = [for (var i = 0; i < samples; i++) -1 + 2 * i / (samples - 1)];
    return GeometryPreview(
      outline: [
        for (final t in ts) panel(r.cx + t * r.a, r.cy - r.b),
        for (final t in ts) panel(r.cx + r.a, r.cy + t * r.b),
        for (final t in ts) panel(r.cx - t * r.a, r.cy + r.b),
        for (final t in ts) panel(r.cx - r.a, r.cy - t * r.b),
      ],
      centerRow: [for (final t in ts) panel(r.cx + t * r.a, r.cy)],
      centerColumn: [for (final t in ts) panel(r.cx, r.cy + t * r.b)],
    );
  }
}

/// Minimises [f] over two variables from [simplex] (Nelder-Mead with the
/// standard coefficients, as scipy.optimize.minimize runs it for the reference
/// model; same stopping rule: xatol 1e-4, fatol 1e-6, 400 iterations).
(double, double) _nelderMead(
  double Function(double x, double y) f,
  List<(double, double)> simplex,
) {
  const xatol = 1e-4, fatol = 1e-6, maxIter = 400;
  final sim = [for (final p in simplex) p];
  final fs = [for (final p in sim) f(p.$1, p.$2)];

  void sort() {
    // Stable, like numpy's argsort on three items.
    final order = [0, 1, 2]
      ..sort((i, j) {
        final c = fs[i].compareTo(fs[j]);
        return c != 0 ? c : i.compareTo(j);
      });
    final s = [for (final i in order) sim[i]];
    final v = [for (final i in order) fs[i]];
    sim.setAll(0, s);
    fs.setAll(0, v);
  }

  sort();
  for (var iter = 0; iter < maxIter; iter++) {
    var xSpread = 0.0, fSpread = 0.0;
    for (var j = 1; j < 3; j++) {
      xSpread = math.max(xSpread, (sim[j].$1 - sim[0].$1).abs());
      xSpread = math.max(xSpread, (sim[j].$2 - sim[0].$2).abs());
      fSpread = math.max(fSpread, (fs[j] - fs[0]).abs());
    }
    if (xSpread <= xatol && fSpread <= fatol) break;

    final bx = (sim[0].$1 + sim[1].$1) / 2, by = (sim[0].$2 + sim[1].$2) / 2;
    (double, double) toward(double k) =>
        (bx + k * (sim[2].$1 - bx), by + k * (sim[2].$2 - by));

    final xr = toward(-1);
    final fr = f(xr.$1, xr.$2);
    var shrink = false;
    if (fr < fs[0]) {
      final xe = toward(-2);
      final fe = f(xe.$1, xe.$2);
      if (fe < fr) {
        sim[2] = xe;
        fs[2] = fe;
      } else {
        sim[2] = xr;
        fs[2] = fr;
      }
    } else if (fr < fs[1]) {
      sim[2] = xr;
      fs[2] = fr;
    } else if (fr < fs[2]) {
      final xc = toward(-0.5);
      final fc = f(xc.$1, xc.$2);
      if (fc <= fr) {
        sim[2] = xc;
        fs[2] = fc;
      } else {
        shrink = true;
      }
    } else {
      final xcc = toward(0.5);
      final fcc = f(xcc.$1, xcc.$2);
      if (fcc < fs[2]) {
        sim[2] = xcc;
        fs[2] = fcc;
      } else {
        shrink = true;
      }
    }
    if (shrink) {
      for (var j = 1; j < 3; j++) {
        sim[j] = (
          sim[0].$1 + 0.5 * (sim[j].$1 - sim[0].$1),
          sim[0].$2 + 0.5 * (sim[j].$2 - sim[0].$2),
        );
        fs[j] = f(sim[j].$1, sim[j].$2);
      }
    }
    sort();
  }
  return sim[0];
}
