import 'dart:io';

import 'package:flutter/foundation.dart';

/// Replaces [openInBrowser] in tests, so a link can be checked without
/// starting a browser.
@visibleForTesting
void Function(String url)? debugOpenInBrowserOverride;

/// Opens [url] in the default browser through the OS shell, which saves
/// pulling in `url_launcher` for the few links the app has.
void openInBrowser(String url) {
  final override = debugOpenInBrowserOverride;
  if (override != null) {
    override(url);
    return;
  }
  if (Platform.isWindows) {
    Process.run('cmd', ['/c', 'start', url]);
  } else {
    Process.run('open', [url]);
  }
}
