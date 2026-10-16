/// Pure values and NTCONTROL wire formats of the Color Correction dialog:
/// Color Matching (CMAI0, VMR/VMG/VMB, C7CS0..6), Color Temperature (OTE /
/// QTE) and white balance (VHR.. / VOR..).
library;

/// A colour Color Matching adjusts. 3 colors uses the first three.
enum MatchColor {
  red('Red', [2048, 0, 0]),
  green('Green', [0, 2048, 0]),
  blue('Blue', [0, 0, 2048]),
  cyan('Cyan', [0, 2048, 2048]),
  magenta('Magenta', [2048, 0, 2048]),
  yellow('Yellow', [2048, 2048, 0]),
  white('White', [2048, 2048, 2048]);

  const MatchColor(this.label, this.defaultRgb);

  final String label;

  /// Factory default (owner, 2026-10-15): what Reset writes, and what the
  /// "Changed" dot compares against.
  final List<int> defaultRgb;

  bool isDefault(List<int> rgb) =>
      rgb[0] == defaultRgb[0] &&
      rgb[1] == defaultRgb[1] &&
      rgb[2] == defaultRgb[2];
}

/// Each channel of a Color Matching colour is 0 to this.
const int matchChannelMax = 2048;

enum MatchMethod {
  off('Off', []),
  three('3 colors', [MatchColor.red, MatchColor.green, MatchColor.blue]),
  seven('7 colors', MatchColor.values);

  const MatchMethod(this.label, this.colors);

  final String label;
  final List<MatchColor> colors;

  /// `CMAI0` value: 0 off, 1 three colors, 2 seven colors.
  static MatchMethod fromProtocol(int v) => switch (v) {
    1 => three,
    2 => seven,
    _ => off,
  };

  String get writeCommand => 'VXX:CMAI0=+${index.toString().padLeft(5, '0')}';
}

enum TempMode {
  defaultTemp('Default', '10'),
  user1('User 1', '04'),
  user2('User 2', '09'),
  custom('Custom', '');

  const TempMode(this.label, this._code);

  final String label;
  final String _code;

  bool get isUser => this == user1 || this == user2;

  /// `OTE:` write; Custom carries the kelvin value itself.
  String writeCommand(int kelvin) =>
      'OTE:${this == custom ? '$kelvin' : _code}';
}

const int kelvinMin = 3200;
const int kelvinMax = 13000;
const int kelvinStep = 100;
const List<int> kelvinPresets = [3200, 5400, 6500, 9300];

/// What a `QTE` reply means: the mode, and the kelvin for Custom. Null when
/// the reply is no mode at all (ER401 while Color Matching is on).
(TempMode, int?)? parseColorTemperature(String? raw) {
  final v = int.tryParse(raw?.trim() ?? '');
  if (v == null) return null;
  if (v == 4) return (TempMode.user1, null);
  if (v == 9) return (TempMode.user2, null);
  if (v == 10) return (TempMode.defaultTemp, null);
  if (v >= kelvinMin && v <= kelvinMax) {
    return (TempMode.custom, (v ~/ kelvinStep) * kelvinStep);
  }
  return null;
}

/// `2048,0096,0000` (the value part of QMR or `C7CS3=…`) as three ints.
List<int>? parseRgbTriple(String raw) {
  final valuePart = raw.contains('=') ? raw.split('=').last : raw;
  final parts = valuePart.trim().split(',');
  if (parts.length != 3) return null;
  final values = parts.map((p) => int.tryParse(p.trim())).toList();
  if (values.any((v) => v == null)) return null;
  return List.unmodifiable(values.cast<int>());
}

String _fmt4(int v) => v.toString().padLeft(4, '0');
String _fmt3(int v) => v.toString().padLeft(3, '0');

/// The read for [color] under [method] (3 colors: QMR/QMG/QMB; 7 colors:
/// QVX:C7CS0..6).
String colorMatchingQuery(MatchMethod method, MatchColor color) =>
    method == MatchMethod.three
    ? 'QM${_rgbLetter(color)}'
    : 'QVX:C7CS${color.index}';

/// One write of all three channels of [color] under [method].
String colorMatchingWrite(MatchMethod method, MatchColor color, List<int> rgb) {
  final values = '${_fmt4(rgb[0])},${_fmt4(rgb[1])},${_fmt4(rgb[2])}';
  return method == MatchMethod.three
      ? 'VM${_rgbLetter(color)}:$values'
      : 'VXX:C7CS${color.index}=$values';
}

String _rgbLetter(MatchColor color) => switch (color) {
  MatchColor.red => 'R',
  MatchColor.green => 'G',
  _ => 'B',
};

const whiteBalanceHighMax = 255;
const whiteBalanceLowMax = 127;

/// White balance High is the register value, 0 to 255.
int parseWhiteBalanceHigh(String? raw, int fallback) =>
    (int.tryParse(raw?.trim() ?? '') ?? fallback).clamp(0, whiteBalanceHighMax);

/// White balance Low is 1 to 255 on the wire, shown as -127 to 127.
int parseWhiteBalanceLow(String? raw, int fallback) {
  final v = int.tryParse(raw?.trim() ?? '');
  return v == null
      ? fallback
      : (v - 128).clamp(-whiteBalanceLowMax, whiteBalanceLowMax);
}

String whiteBalanceHighWrite(int channel, int value) =>
    '${const ['VHR', 'VHG', 'VHB'][channel]}:${_fmt3(value)}';

String whiteBalanceLowWrite(int channel, int display) =>
    '${const ['VOR', 'VOG', 'VOB'][channel]}:'
    '${_fmt3((display + 128).clamp(1, 255))}';

/// A Low slider drag lands on 0 within ±3, so the neutral point is easy to
/// hit by hand.
int snapWhiteBalanceLow(int v) => v.abs() <= 3 ? 0 : v;
