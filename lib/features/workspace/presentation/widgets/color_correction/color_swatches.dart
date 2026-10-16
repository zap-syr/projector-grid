import 'package:flutter/material.dart';

import '../../../domain/color_correction.dart';

/// The dot of each Color Matching colour (the dialog's colours before the
/// redesign).
Color swatchOf(MatchColor c) => switch (c) {
  MatchColor.red => Colors.red,
  MatchColor.green => Colors.green,
  MatchColor.blue => Colors.blue,
  MatchColor.cyan => Colors.cyan,
  MatchColor.magenta => const Color(0xFFCC44CC),
  MatchColor.yellow => Colors.yellow,
  MatchColor.white => Colors.white,
};

/// Letter and accent of the R, G and B channel rows.
const rgbChannels = [
  ('R', Colors.red),
  ('G', Colors.green),
  ('B', Colors.blue),
];

/// What a Color Matching value looks like on screen: each channel 0 to
/// 2048 scaled to 0 to 255.
Color previewOf(List<int> rgb) {
  int c(int v) => (v * 255 / matchChannelMax).round().clamp(0, 255);
  return Color.fromARGB(255, c(rgb[0]), c(rgb[1]), c(rgb[2]));
}

/// Blackbody approximation from 3200 K to 13000 K; each stop is
/// (K - 3200) / 9800.
const kelvinGradient = LinearGradient(
  colors: [
    Color(0xFFFF9329), // 3200 K, warm amber
    Color(0xFFFFBE70), // 4500 K, orange-white
    Color(0xFFFFE4B4), // 5500 K, warm white
    Color(0xFFFFFEFA), // 6500 K, neutral white
    Color(0xFFCADBFF), // 8000 K, cool blue-white
    Color(0xFFBECFFF), // 10000 K, blue-white
    Color(0xFFB6C8FF), // 13000 K, cool blue
  ],
  stops: [0.000, 0.133, 0.235, 0.337, 0.490, 0.694, 1.000],
);
