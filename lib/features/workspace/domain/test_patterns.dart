/// The test patterns the app offers, keyed by their `OTS:xx` command. Shared
/// by the control bar, the card thumbnail, the Monitoring column and
/// Alignment mode so the lists can't drift apart.
library;

const String kTestPatternOff = 'OTS:00';

/// Label per pattern, in the order the control bar's dropdown shows them.
const Map<String, String> kTestPatternLabels = {
  'OTS:01': 'White',
  'OTS:02': 'Black',
  'OTS:22': 'Red',
  'OTS:23': 'Green',
  'OTS:24': 'Blue',
  'OTS:28': 'Cyan',
  'OTS:29': 'Magenta',
  'OTS:30': 'Yellow',
  'OTS:05': 'Window',
  'OTS:06': 'Reversed Window',
  'OTS:08': 'Color Bar Vert',
  'OTS:51': 'Color Bar Horiz',
  'OTS:78': 'Focus',
  'OTS:59': 'Aspect Frame',
  'OTS:07': 'Cross Hatch',
  'OTS:70': 'Cross Hatch Red',
  'OTS:71': 'Cross Hatch Green',
  'OTS:72': 'Cross Hatch Blue',
  'OTS:73': 'Cross Hatch Cyan',
  'OTS:74': 'Cross Hatch Magenta',
  'OTS:75': 'Cross Hatch Yellow',
  'OTS:87': 'Circle',
};

const Map<String, String> kTestPatternIcons = {
  'OTS:01': 'assets/icons/test_patterns/tp_white.svg',
  'OTS:02': 'assets/icons/test_patterns/tp_black.svg',
  'OTS:22': 'assets/icons/test_patterns/tp_red.svg',
  'OTS:23': 'assets/icons/test_patterns/tp_green.svg',
  'OTS:24': 'assets/icons/test_patterns/tp_blue.svg',
  'OTS:28': 'assets/icons/test_patterns/tp_cyan.svg',
  'OTS:29': 'assets/icons/test_patterns/tp_magenta.svg',
  'OTS:30': 'assets/icons/test_patterns/tp_yellow.svg',
  'OTS:05': 'assets/icons/test_patterns/tp_window.svg',
  'OTS:06': 'assets/icons/test_patterns/tp_reversed_window.svg',
  'OTS:08': 'assets/icons/test_patterns/tp_colorbar_vert.svg',
  'OTS:51': 'assets/icons/test_patterns/tp_colorbar_horiz.svg',
  'OTS:78': 'assets/icons/test_patterns/tp_focus.svg',
  'OTS:59': 'assets/icons/test_patterns/tp_aspect_frame.svg',
  'OTS:07': 'assets/icons/test_patterns/tp_crosshatch.svg',
  'OTS:70': 'assets/icons/test_patterns/tp_crosshatch_red.svg',
  'OTS:71': 'assets/icons/test_patterns/tp_crosshatch_green.svg',
  'OTS:72': 'assets/icons/test_patterns/tp_crosshatch_blue.svg',
  'OTS:73': 'assets/icons/test_patterns/tp_crosshatch_cyan.svg',
  'OTS:74': 'assets/icons/test_patterns/tp_crosshatch_magenta.svg',
  'OTS:75': 'assets/icons/test_patterns/tp_crosshatch_yellow.svg',
  'OTS:87': 'assets/icons/test_patterns/tp_circle.svg',
};

/// Parses a `QTS` reply — the bare two-digit code, e.g. `07` — into the
/// `OTS:07` form the maps above use. Null for a failed query or a reply that
/// isn't a two-digit code.
String? parseTestPattern(String? raw) {
  final value = raw?.trim();
  if (value == null || !RegExp(r'^\d{2}$').hasMatch(value)) return null;
  return 'OTS:$value';
}

/// Display label; codes the app doesn't list (valid on the projector, e.g.
/// `OTS:52`) fall back to the raw code.
String testPatternLabel(String code) =>
    kTestPatternLabels[code] ??
    (code == kTestPatternOff ? 'Off' : code.replaceFirst('OTS:', 'Pattern '));

/// True when [code] puts a pattern on screen (shutter permitting).
bool isTestPatternActive(String? code) =>
    code != null && code != kTestPatternOff;
