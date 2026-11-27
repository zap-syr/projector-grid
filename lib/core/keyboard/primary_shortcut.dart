import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The platform's primary-modifier shortcut: Cmd on macOS, Ctrl elsewhere.
///
/// Reads [defaultTargetPlatform] on every call (never dart:io's Platform) so
/// tests can switch platforms; build shortcut maps inside `build()`, not in a
/// const or a top-level final. Binding only the platform's own modifier keeps
/// Ctrl+A (line start) free on macOS and the Windows key out of the app's
/// shortcuts.
SingleActivator primaryShortcut(LogicalKeyboardKey key, {bool shift = false}) {
  final mac = defaultTargetPlatform == TargetPlatform.macOS;
  return SingleActivator(key, meta: mac, control: !mac, shift: shift);
}
