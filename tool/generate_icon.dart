// Generates assets/icon/app_icon.png — the app icon for Projectors Manager.
// Run with: dart run tool/generate_icon.dart
//
// Design: lens aperture — navy→teal diagonal gradient, 6-blade iris,
//         light blue-white blades, cyan-white glow centre.

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const _size    = 1024;
const _cx      = 512;
const _cy      = 512;
const _cornerR = 200;

void main() async {
  final icon = img.Image(width: _size, height: _size, numChannels: 4);

  // 1. Diagonal gradient background: navy #0E2454 → teal #0A7FA8
  for (int y = 0; y < _size; y++) {
    for (int x = 0; x < _size; x++) {
      final t = (x + y) / (_size * 2.0);
      final r = (14  + (10  - 14 ) * t).round().clamp(0, 255);
      final g = (36  + (127 - 36 ) * t).round().clamp(0, 255);
      final b = (84  + (168 - 84 ) * t).round().clamp(0, 255);
      icon.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
    }
  }

  // 2. Outer metallic bezel ring
  img.fillCircle(icon, x: _cx, y: _cy, radius: 456, color: img.ColorRgba8(60,  90, 150, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius: 448, color: img.ColorRgba8(14,  30,  66, 255));

  // 3. Lens body
  img.fillCircle(icon, x: _cx, y: _cy, radius: 444, color: img.ColorRgba8(16,  34,  76, 255));

  // 4. Subtle iris recess ring (inner edge of lens housing)
  img.fillCircle(icon, x: _cx, y: _cy, radius: 400, color: img.ColorRgba8(10,  22,  50, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius: 394, color: img.ColorRgba8(16,  34,  76, 255));

  // 5. Six aperture blades — light blue-white, drawn BEFORE glow
  final bladeColor = img.ColorRgba8(210, 228, 252, 255);
  for (var i = 0; i < 6; i++) {
    _drawBlade(icon, i * 60.0, bladeColor);
  }

  // 6. Inner rim ring — sits over blade inner tips, adds definition
  img.fillCircle(icon, x: _cx, y: _cy, radius: 186, color: img.ColorRgba8(20,  50, 110, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius: 178, color: img.ColorRgba8(12,  26,  58, 255));

  // 7. Central aperture glow: deep blue → cyan → near-white core
  img.fillCircle(icon, x: _cx, y: _cy, radius: 174, color: img.ColorRgba8(10,  80, 160, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius: 148, color: img.ColorRgba8(20, 140, 210, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius: 116, color: img.ColorRgba8(80, 190, 240, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius:  80, color: img.ColorRgba8(160, 225, 255, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius:  50, color: img.ColorRgba8(210, 242, 255, 255));
  img.fillCircle(icon, x: _cx, y: _cy, radius:  26, color: img.ColorRgba8(240, 250, 255, 255));

  // 8. Rounded corners
  _applyRoundedCorners(icon, _cornerR);

  // 9. Save
  Directory('assets/icon').createSync(recursive: true);
  final out = File('assets/icon/app_icon.png');
  out.writeAsBytesSync(img.encodePng(icon));
  print('Generated: ${out.path} (${_size}x$_size)');
}

// ── Aperture blade ────────────────────────────────────────────────────────────
//
// Scale: 2× the SVG (SVG was 512 px, PNG is 1024 px).
// Outer arc r=400 spanning ±30° approximated with 5 sample points.
// Inner edge r=172 shifted +25° from outer span — creates the rotational
// offset characteristic of an iris.  6 straight inner edges tile into the
// hexagonal aperture opening.

void _drawBlade(img.Image image, double angleDeg, img.Color color) {
  const rOuter = 400.0;
  const rInner = 172.0;

  final baseRelative = [
    _polar(rOuter, -30), // outer arc start
    _polar(rOuter, -15),
    _polar(rOuter,   0),
    _polar(rOuter,  15),
    _polar(rOuter,  30), // outer arc end
    _polar(rInner,  55), // inner right (+25° from outer right)
    _polar(rInner,  -5), // inner left  (+25° from outer left)
  ];

  final rad = angleDeg * math.pi / 180.0;
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);

  final vertices = baseRelative.map((p) {
    final rx = p.$1 * cosA - p.$2 * sinA;
    final ry = p.$1 * sinA + p.$2 * cosA;
    return img.Point(_cx + rx, _cy + ry);
  }).toList();

  img.fillPolygon(image, vertices: vertices, color: color);
}

(double, double) _polar(double r, double deg) {
  final rad = deg * math.pi / 180.0;
  return (r * math.cos(rad), r * math.sin(rad));
}

// ── Rounded corners ───────────────────────────────────────────────────────────

void _applyRoundedCorners(img.Image image, int radius) {
  final w = image.width;
  final h = image.height;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final inCornerCol = x < radius || x >= w - radius;
      final inCornerRow = y < radius || y >= h - radius;
      if (!inCornerCol || !inCornerRow) continue;

      final cx = x < radius ? radius : w - radius;
      final cy = y < radius ? radius : h - radius;

      final dx = (x + 0.5) - cx;
      final dy = (y + 0.5) - cy;
      final d  = math.sqrt(dx * dx + dy * dy);

      if (d >= radius + 0.5) {
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      } else if (d > radius - 0.5) {
        final t = (radius + 0.5 - d).clamp(0.0, 1.0);
        final p = image.getPixel(x, y);
        image.setPixel(x, y, img.ColorRgba8(
          p.r.toInt(), p.g.toInt(), p.b.toInt(),
          (p.a.toDouble() * t).round().clamp(0, 255)));
      }
    }
  }
}
