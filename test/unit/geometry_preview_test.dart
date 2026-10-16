import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/geometry_preview.dart';

/// Exported by tool/geometry_measure/export_fixture.py: camera edge samples of
/// measured frames, and outlines of the Python reference model.
final _fixture = jsonDecode(
  File('test/fixtures/geometry_preview_measured.json').readAsStringSync(),
) as Map<String, dynamic>;

GeometryPreview _preview(String mode, Map<String, dynamic> s, int samples) {
  double d(String k) => (s[k] as num).toDouble();
  int i(String k) => (s[k] as num).toInt();
  if (mode == 'keystone') {
    return keystonePreview(
      throwRatio: d('throwRatio'),
      vertical: d('vertical'),
      horizontal: d('horizontal'),
      verticalBalance: i('verticalBalance'),
      horizontalBalance: i('horizontalBalance'),
      samples: samples,
    );
  }
  return curvedPreview(
    throwRatio: d('throwRatio'),
    verticalArc: i('verticalArc'),
    horizontalArc: i('horizontalArc'),
    vertical: d('vertical'),
    horizontal: d('horizontal'),
    verticalBalance: i('verticalBalance'),
    horizontalBalance: i('horizontalBalance'),
    keepAspect: s['keepAspect'] as bool,
    samples: samples,
  );
}

/// Where the outline crosses the line `x = at` (top / bottom) or `y = at`
/// (left / right); the outermost crossing on that side, like the first lit
/// pixel of a camera profile.
double? _edgeAt(List<Offset> outline, String edge, double at) {
  final vertical = edge == 'top' || edge == 'bottom';
  final hits = <double>[];
  for (var k = 0; k < outline.length; k++) {
    final p = outline[k], q = outline[(k + 1) % outline.length];
    final (pa, qa) = vertical ? (p.dx, q.dx) : (p.dy, q.dy);
    if (pa == qa || at < math.min(pa, qa) || at > math.max(pa, qa)) continue;
    final t = (at - pa) / (qa - pa);
    hits.add(vertical ? p.dy + t * (q.dy - p.dy) : p.dx + t * (q.dx - p.dx));
  }
  if (hits.isEmpty) return null;
  return edge == 'top' || edge == 'left'
      ? hits.reduce(math.min)
      : hits.reduce(math.max);
}

List<Offset> _points(dynamic list) => [
  for (final p in list as List)
    Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
];

void _expectClose(
  List<Offset> actual,
  List<Offset> expected,
  double tol,
  String what,
) {
  expect(actual.length, expected.length, reason: what);
  for (var k = 0; k < actual.length; k++) {
    expect(
      (actual[k] - expected[k]).distance,
      lessThanOrEqualTo(tol),
      reason: '$what, point $k: ${actual[k]} vs ${expected[k]}',
    );
  }
}

/// Same points as [b] mirrored by [mirror], in any order.
void _expectMirrored(
  List<Offset> a,
  List<Offset> b,
  Offset Function(Offset) mirror,
) {
  for (final p in b.map(mirror)) {
    final nearest = a.map((q) => (q - p).distance).reduce(math.min);
    expect(nearest, lessThan(1e-3), reason: 'mirrored point $p');
  }
}

GeometryPreview _keystone(
  double tr,
  double v,
  double h, {
  int vb = 0,
  int hb = 0,
}) => keystonePreview(
  throwRatio: tr,
  vertical: v,
  horizontal: h,
  verticalBalance: vb,
  horizontalBalance: hb,
);

GeometryPreview _curved(
  double tr,
  int va,
  int ha, {
  double v = 0,
  double h = 0,
  int vb = 0,
  int hb = 0,
  bool keepAspect = true,
}) => curvedPreview(
  throwRatio: tr,
  verticalArc: va,
  horizontalArc: ha,
  vertical: v,
  horizontal: h,
  verticalBalance: vb,
  horizontalBalance: hb,
  keepAspect: keepAspect,
);

void main() {
  group('matches the projector (camera frames)', () {
    final tolerance = (_fixture['tolerance'] as num).toDouble();
    for (final c in _fixture['measured'] as List) {
      test(c['frame'] as String, () {
        final outline = _preview(
          c['mode'] as String,
          c['settings'] as Map<String, dynamic>,
          60,
        ).outline;
        for (final s in c['samples'] as List) {
          final edge = s[0] as String;
          final at = (s[1] as num).toDouble();
          final measured = (s[2] as num).toDouble();
          final model = _edgeAt(outline, edge, at);
          expect(model, isNotNull, reason: '$edge at $at');
          expect(
            (model! - measured).abs(),
            lessThanOrEqualTo(tolerance),
            reason: '$edge at $at: model $model, camera $measured',
          );
        }
      });
    }
  });

  group('matches the Python reference model', () {
    final tolerance = (_fixture['referenceTolerance'] as num).toDouble();
    final cases = _fixture['reference'] as List;
    for (var k = 0; k < cases.length; k++) {
      final c = cases[k];
      test('${c['mode']} ${c['settings']}', () {
        final p = _preview(
          c['mode'] as String,
          c['settings'] as Map<String, dynamic>,
          5,
        );
        _expectClose(p.outline, _points(c['outline']), tolerance, 'outline');
        _expectClose(
          p.centerRow,
          _points(c['centerRow']),
          tolerance,
          'centre row',
        );
        _expectClose(
          p.centerColumn,
          _points(c['centerColumn']),
          tolerance,
          'centre column',
        );
      });
    }
  });

  group('invariants', () {
    const fullPanel = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
    List<Offset> corners(GeometryPreview p, int samples) => [
      for (var e = 0; e < 4; e++) p.outline[e * samples],
    ];

    test('no correction fills the panel', () {
      _expectClose(
        corners(_keystone(1.5, 0, 0), 2),
        fullPanel,
        1e-3,
        'keystone',
      );
      for (final keep in [true, false]) {
        final p = curvedPreview(
          throwRatio: 1.5,
          verticalArc: 0,
          horizontalArc: 0,
          vertical: 0,
          horizontal: 0,
          verticalBalance: 0,
          horizontalBalance: 0,
          keepAspect: keep,
        );
        _expectClose(corners(p, 24), fullPanel, 1e-3, 'curved, aspect $keep');
      }
    });

    test('Balance without keystone changes nothing', () {
      _expectClose(
        corners(_keystone(1.5, 0, 0, vb: 60, hb: -30), 2),
        fullPanel,
        1e-3,
        'keystone',
      );
    });

    test('opposite angles mirror the shape', () {
      Offset flipV(Offset p) => Offset(p.dx, 1 - p.dy);
      Offset flipH(Offset p) => Offset(1 - p.dx, p.dy);
      _expectMirrored(
        _keystone(1.5, -20, 0).outline,
        _keystone(1.5, 20, 0).outline,
        flipV,
      );
      _expectMirrored(
        _keystone(1.5, 0, -10).outline,
        _keystone(1.5, 0, 10).outline,
        flipH,
      );
      _expectMirrored(
        _keystone(1.5, 20, 0, hb: -15).outline,
        _keystone(1.5, 20, 0, hb: 15).outline,
        flipH,
      );
    });

    test('positive V narrows the top, positive H the left side', () {
      final [tl, tr, br, bl] = corners(_keystone(1.5, 20, 0), 2);
      expect(tr.dx - tl.dx, lessThan(br.dx - bl.dx));
      final [tl2, tr2, br2, bl2] = corners(_keystone(1.5, 0, 10), 2);
      expect(bl2.dy - tl2.dy, lessThan(br2.dy - tr2.dy));
    });

    test('Vertical Keystone is capped by the throw ratio', () {
      expect(appliedVerticalKeystone(0.7, 40, 0), 27);
      expect(appliedVerticalKeystone(1.0, -40, 0), -33);
      expect(appliedVerticalKeystone(1.5, 40, 0), 40);
      expect(appliedVerticalKeystone(0.7, 40, 15), closeTo(25.05, 1e-9));
      _expectClose(
        _keystone(0.7, 40, 0).outline,
        _keystone(0.7, 27, 0).outline,
        1e-9,
        'TR 0.7, V 40 vs 27',
      );
    });

    test('a positive arc bends the edges inward, a negative one outward', () {
      final concave = _curved(0.7, 40, 0);
      final convex = _curved(0.7, -40, 0);
      // Left edge: middle point against its two ends.
      double bow(GeometryPreview p) {
        final left = p.outline.sublist(72, 96);
        return left[12].dx - (left.first.dx + left.last.dx) / 2;
      }

      expect(bow(concave), greaterThan(0.01));
      expect(bow(convex), lessThan(-0.01));
    });

    test('every outline stays on the panel', () {
      final rnd = math.Random(7);
      double r(double lo, double hi) => lo + rnd.nextDouble() * (hi - lo);
      for (var k = 0; k < 60; k++) {
        final p = k.isEven
            ? _keystone(
                r(0.7, 8),
                r(-40, 40),
                r(-15, 15),
                vb: rnd.nextInt(121) - 60,
                hb: rnd.nextInt(61) - 30,
              )
            : _curved(
                r(0.7, 8),
                rnd.nextInt(81) - 40,
                rnd.nextInt(81) - 40,
                v: r(-30, 30),
                h: r(-15, 15),
                vb: rnd.nextInt(121) - 60,
                hb: rnd.nextInt(61) - 30,
                keepAspect: rnd.nextBool(),
              );
        // The fit checks 13 points per edge; a bent edge drawn with more points
        // can pass the panel edge between them by ~1e-4 (0.05 px on a 480 px
        // preview).
        for (final q in [...p.outline, ...p.centerRow, ...p.centerColumn]) {
          expect(q.dx, inInclusiveRange(-1e-3, 1 + 1e-3), reason: 'case $k');
          expect(q.dy, inInclusiveRange(-1e-3, 1 + 1e-3), reason: 'case $k');
        }
      }
    });
  });

  test('fast enough for every slider tick', () {
    final rnd = math.Random(3);
    final sw = Stopwatch()..start();
    const runs = 100;
    for (var k = 0; k < runs; k++) {
      _curved(
        0.7 + rnd.nextDouble() * 3,
        rnd.nextInt(81) - 40,
        rnd.nextInt(81) - 40,
        v: rnd.nextDouble() * 40 - 20,
        vb: rnd.nextInt(61) - 30,
      );
    }
    final perCall = sw.elapsedMicroseconds / runs / 1000;
    // Debug JIT in the test runner; release is several times faster.
    expect(
      perCall,
      lessThan(8),
      reason: '${perCall.toStringAsFixed(2)} ms per call',
    );
  });
}
