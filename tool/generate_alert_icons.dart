// Writes the desktop notification's severity icons to assets/alert_icons/:
//   critical.png — red circle with "!"
//   warning.png  — orange triangle with "!"
//   recovered.png — green circle with a check (the signal is back)
// Windows shows the toast's logo at a fixed size, so the glyph fills only
// about 75% of the image and the transparent margin makes it look smaller.
// Run from the project root: dart run tool/generate_alert_icons.dart
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const _size = 96;

/// Drawing units: the glyph is drawn in 0–48, the image shows -8–56.
const _viewMin = -8.0;
const _viewSpan = 64.0;
const _samples = 4;

typedef Shape = bool Function(double x, double y);

/// The app's alert colours (`AlertPalette.icon`: Colors.red / orange /
/// green).
const _red = (0xF4, 0x43, 0x36);
const _orange = (0xFF, 0x98, 0x00);
const _green = (0x4C, 0xAF, 0x50);

Shape circle(double cx, double cy, double r) =>
    (x, y) => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;

/// A vertical bar with round ends, from [top] to [bottom].
Shape capsule(double cx, double top, double bottom, double r) => (x, y) {
  final dy = y < top + r
      ? y - (top + r)
      : (y > bottom - r ? y - (bottom - r) : 0);
  return (x - cx) * (x - cx) + dy * dy <= r * r;
};

double _segmentDistance(double x, double y, Point<double> a, Point<double> b) {
  final abx = b.x - a.x, aby = b.y - a.y;
  final t = (((x - a.x) * abx + (y - a.y) * aby) / (abx * abx + aby * aby))
      .clamp(0.0, 1.0);
  final px = a.x + t * abx - x, py = a.y + t * aby - y;
  return sqrt(px * px + py * py);
}

/// A triangle grown by [round] on every side, its corners rounded.
Shape roundedTriangle(List<Point<double>> p, double round) => (x, y) {
  double side(Point<double> a, Point<double> b) =>
      (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x);
  final s = [side(p[0], p[1]), side(p[1], p[2]), side(p[2], p[0])];
  if (s.every((v) => v >= 0) || s.every((v) => v <= 0)) return true;
  return [
    for (var i = 0; i < 3; i++) _segmentDistance(x, y, p[i], p[(i + 1) % 3]),
  ].any((d) => d <= round);
};

/// [fill] in [color], [mark] cut out of it in white; anti-aliased by
/// supersampling.
void writeIcon(String path, Shape fill, Shape mark, (int, int, int) color) {
  final image = img.Image(width: _size, height: _size, numChannels: 4);
  for (var py = 0; py < _size; py++) {
    for (var px = 0; px < _size; px++) {
      var filled = 0, white = 0;
      for (var sy = 0; sy < _samples; sy++) {
        for (var sx = 0; sx < _samples; sx++) {
          final x = _viewMin + (px + (sx + 0.5) / _samples) / _size * _viewSpan;
          final y = _viewMin + (py + (sy + 0.5) / _samples) / _size * _viewSpan;
          if (mark(x, y)) {
            white++;
          } else if (fill(x, y)) {
            filled++;
          }
        }
      }
      final covered = filled + white;
      if (covered == 0) continue;
      int mix(int c) => ((c * filled + 255 * white) / covered).round();
      image.setPixelRgba(
        px,
        py,
        mix(color.$1),
        mix(color.$2),
        mix(color.$3),
        (255 * covered / (_samples * _samples)).round(),
      );
    }
  }
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $path');
}

void main() {
  writeIcon(
    'assets/alert_icons/critical.png',
    circle(24, 24, 20),
    (x, y) => capsule(24, 12, 27, 2.5)(x, y) || circle(24, 33.5, 3)(x, y),
    _red,
  );
  writeIcon(
    'assets/alert_icons/warning.png',
    roundedTriangle(const [Point(24, 5), Point(45, 42), Point(3, 42)], 1.5),
    (x, y) => capsule(24, 17, 30, 2.4)(x, y) || circle(24, 35.5, 2.8)(x, y),
    _orange,
  );
  const tick = [Point(14.0, 24.5), Point(21.0, 31.5), Point(34.0, 17.0)];
  writeIcon(
    'assets/alert_icons/recovered.png',
    circle(24, 24, 20),
    (x, y) =>
        _segmentDistance(x, y, tick[0], tick[1]) <= 2.6 ||
        _segmentDistance(x, y, tick[1], tick[2]) <= 2.6,
    _green,
  );
}
