import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's bundled fonts (Inter, IBM Plex Mono) instead of the test
/// font (every glyph a square), so a widget lays out at its real width. Call
/// from `setUpAll`.
Future<void> loadAppFonts() async {
  Future<void> load(String family, String dir, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', 'inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await load('IBM Plex Mono', 'ibm_plex_mono', [
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
    'IBMPlexMono-SemiBold.ttf',
  ]);
}
