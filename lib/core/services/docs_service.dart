import 'dart:io';
import 'package:flutter/foundation.dart';
import '../docs/osc_reference_html.dart';

class DocsService {
  static String get _oscReferencePath {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\ProjectorGrid\\osc_reference.html';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/ProjectorGrid/osc_reference.html';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/.config/ProjectorGrid/osc_reference.html';
    }
  }

  /// Writes the OSC reference HTML to the app data directory and opens it
  /// in the system default browser.
  static Future<void> openOscReference() async {
    try {
      final file = File(_oscReferencePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(oscReferenceHtml);
      final path = file.path;
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      debugPrint('DocsService: error opening OSC reference — $e');
    }
  }
}
