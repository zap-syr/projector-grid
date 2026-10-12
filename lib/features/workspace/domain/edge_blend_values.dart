/// Wire formats specific to Edge Blending: the legacy 4-digit values and the
/// `W,R,G,B` black level tuples (plan/EDGE_BLENDING_PLAN.md §1, §8).
library;

typedef Rgbw = ({int w, int r, int g, int b});

/// Legacy short write value: `10` → `0010` (`VEU:0010`). Replies come back
/// unpadded (`QEU` → `10`), which `parseKeyedInt` already reads.
String formatNt4(int v) => v.toString().padLeft(4, '0');

/// `050,010,020,030` or `EBBS0=050,010,020,030` → the four channels; null
/// for anything else (an error code, a missing reply).
Rgbw? parseRgbw(String? response) {
  if (response == null) return null;
  final eq = response.indexOf('=');
  final parts = response.substring(eq + 1).trim().split(',');
  if (parts.length != 4) return null;
  final values = parts.map((p) => int.tryParse(p.trim())).toList();
  if (values.any((v) => v == null || v < 0 || v > 255)) return null;
  return (w: values[0]!, r: values[1]!, g: values[2]!, b: values[3]!);
}

/// `(w: 50, r: 10, g: 20, b: 30)` → `050,010,020,030`.
String formatRgbw(Rgbw v) =>
    [v.w, v.r, v.g, v.b].map((c) => c.toString().padLeft(3, '0')).join(',');
