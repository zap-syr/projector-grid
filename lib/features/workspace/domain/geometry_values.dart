/// Pure NTCONTROL value parsing/formatting and Corner Correction maths used by
/// the Geometry dialog — kept out of the widget so it can be unit-tested.
library;

/// Extracts the value from a `KEY=value` reply. Falls back to whatever follows
/// the first `=` (some firmware echoes a different key), then to the whole
/// trimmed reply when there's no `=` at all.
String? parseKeyedValue(String? response, String key) {
  if (response == null) return null;
  final keyed = '$key=';
  final idx = response.indexOf(keyed);
  if (idx >= 0) return response.substring(idx + keyed.length).trim();
  final eq = response.indexOf('=');
  if (eq >= 0) return response.substring(eq + 1).trim();
  return response.trim();
}

int? parseKeyedInt(String? response, String key) {
  final raw = parseKeyedValue(response, key);
  if (raw == null) return null;
  return int.tryParse(raw.replaceAll('+', ''));
}

double? parseKeyedDouble(String? response, String key) {
  final raw = parseKeyedValue(response, key);
  if (raw == null) return null;
  return double.tryParse(raw.replaceAll('+', ''));
}

/// Signed 5-digit integer: `12` → `+00012`, `-12` → `-00012`.
String formatNtInt(int v) =>
    '${v >= 0 ? '+' : '-'}${v.abs().toString().padLeft(5, '0')}';

/// Signed 1-decimal degrees: `1.25` → `+1.3`, `-3` → `-3.0`.
String formatNtDeg(double v) {
  final clamped = double.parse(v.toStringAsFixed(1));
  return '${clamped >= 0 ? '+' : '-'}${clamped.abs().toStringAsFixed(1)}';
}

/// Throw ratio, always positive, at least 4 chars: `1.5` → `+01.5`.
String formatNtThrow(double v) {
  final clamped = double.parse(v.toStringAsFixed(1));
  final body = clamped.toStringAsFixed(1).padLeft(4, '0');
  return '+$body';
}

// Tier A — WUXGA-native panel → 3840x2400 Quad Pixel Drive canvas. Corner
// Correction inward limits confirmed live on PT-RQ25K: 960 H / 600 V
// (vs the WUXGA-class standard 480 H / 300 V). Outward limits (384/240)
// never change, on any model. Matched by numeric model code only (trailing
// lens/body-variant letters like K/K2/L stripped) — see
// plan/QUAD_PIXEL_DRIVE_CORNER_LIMITS.md for the full model survey.
const _tierAModels = [
  'PT-RQ25',
  'PT-RQ45',
  'PT-RQ35',
  'PT-RQ18',
  'PT-REQ15',
  'PT-REQ12',
  'PT-REQ10',
  'PT-REQ80',
];

// Tier B — WQXGA-native panel → 5120x3200 "4K+" canvas. Real Corner
// Correction limits are unconfirmed (no unit available to test), so these
// stay at the standard 480/300 limits rather than guess. They do have the
// QPDI1 register and still require it ON to enter a geometry mode, so they
// still get the auto-enable behavior.
const _tierBModels = ['PT-RQ32', 'PT-RQ22', 'PT-RQ13'];

enum QuadPixelTier { none, a, b }

QuadPixelTier quadPixelTierFor(String model) {
  if (_tierAModels.any(model.contains)) return QuadPixelTier.a;
  if (_tierBModels.any(model.contains)) return QuadPixelTier.b;
  return QuadPixelTier.none;
}

// Corner Correction protocol limits. Outward reach is a fixed lens/mechanical
// constraint; only the inward ceiling doubles on Tier A (QPD doubles the
// addressing resolution, not the physical reach).
const int cornerOutwardH = 384;
const int cornerOutwardV = 240;
int cornerInwardH({required bool extended}) => extended ? 960 : 480;
int cornerInwardV({required bool extended}) => extended ? 600 : 300;

// 1 canvas pixel = 6 projector pixels (1920/320 = 1200/200 = 6.0).
const double cornerCanvasScale = 6.0;

/// Raw protocol value → canvas-pixel delta from the corner's default. On
/// extended (Tier A) models the inward direction uses double the precision,
/// so the same visual reach covers twice the raw range.
double cornerToCanvas(
  int raw, {
  required bool inwardIsPositive,
  required bool extended,
}) {
  final isInward = inwardIsPositive ? raw >= 0 : raw <= 0;
  final scale = (isInward && extended)
      ? cornerCanvasScale * 2
      : cornerCanvasScale;
  return raw / scale;
}

/// Inverse of [cornerToCanvas].
int cornerToRaw(
  double canvasDelta, {
  required bool inwardIsPositive,
  required bool extended,
}) {
  final isInward = inwardIsPositive ? canvasDelta >= 0 : canvasDelta <= 0;
  final scale = (isInward && extended)
      ? cornerCanvasScale * 2
      : cornerCanvasScale;
  return (canvasDelta * scale).round();
}
