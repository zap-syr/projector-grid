import 'dart:io';
import 'package:flutter/foundation.dart';
import '../docs/osc_reference_html.dart';
import 'app_config_dir.dart';

class DocsService {
  static String get _oscReferencePath =>
      appConfigFilePath('osc_reference.html');

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
