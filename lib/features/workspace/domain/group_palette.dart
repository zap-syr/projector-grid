/// Group colours: 16 hues × 3 tones (Tailwind 400, 500 and 700) as ARGB,
/// flattened tone-major so a 16-column grid shows one hue per column, light
/// to dark from top to bottom. The 24 colours of the earlier 8-hue palette
/// are all in here, so saved projects keep theirs.
const List<int> groupPalette = [
  // 400
  0xFFF87171, 0xFFFB923C, 0xFFFBBF24, 0xFFFACC15, //
  0xFFA3E635, 0xFF4ADE80, 0xFF34D399, 0xFF2DD4BF, //
  0xFF22D3EE, 0xFF38BDF8, 0xFF60A5FA, 0xFF818CF8, //
  0xFFA78BFA, 0xFFC084FC, 0xFFE879F9, 0xFFF472B6, //
  // 500
  0xFFEF4444, 0xFFF97316, 0xFFF59E0B, 0xFFEAB308, //
  0xFF84CC16, 0xFF22C55E, 0xFF10B981, 0xFF14B8A6, //
  0xFF06B6D4, 0xFF0EA5E9, 0xFF3B82F6, 0xFF6366F1, //
  0xFF8B5CF6, 0xFFA855F7, 0xFFD946EF, 0xFFEC4899, //
  // 700
  0xFFB91C1C, 0xFFC2410C, 0xFFB45309, 0xFFA16207, //
  0xFF4D7C0F, 0xFF15803D, 0xFF047857, 0xFF0F766E, //
  0xFF0E7490, 0xFF0369A1, 0xFF1D4ED8, 0xFF4338CA, //
  0xFF6D28D9, 0xFF7E22CE, 0xFFA21CAF, 0xFFBE185D, //
];

const int groupPaletteHues = 16;

const List<String> _hueNames = [
  'Red',
  'Orange',
  'Amber',
  'Yellow',
  'Lime',
  'Green',
  'Emerald',
  'Teal',
  'Cyan',
  'Sky',
  'Blue',
  'Indigo',
  'Violet',
  'Purple',
  'Fuchsia',
  'Pink',
];

/// Spoken name of the palette entry at [index]: `Red light`, `Red`,
/// `Red dark`.
String groupPaletteName(int index) {
  final hue = _hueNames[index % groupPaletteHues];
  return switch (index ~/ groupPaletteHues) {
    0 => '$hue light',
    1 => hue,
    _ => '$hue dark',
  };
}

/// The colour a new group starts with: the first palette entry no group uses
/// yet, base tones before light and dark ones so the first groups get the
/// clearest colours. With every colour taken it falls back to the first base
/// tone (colours may repeat, they are only a hint).
int firstUnusedGroupColor(Iterable<int> usedColors) {
  final used = usedColors.toSet();
  const order = [1, 0, 2];
  for (final row in order) {
    for (var hue = 0; hue < groupPaletteHues; hue++) {
      final color = groupPalette[row * groupPaletteHues + hue];
      if (!used.contains(color)) return color;
    }
  }
  return groupPalette[groupPaletteHues];
}
