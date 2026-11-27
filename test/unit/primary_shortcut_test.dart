import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/keyboard/primary_shortcut.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Windows binds Ctrl only', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final s = primaryShortcut(LogicalKeyboardKey.keyA);
    expect(s.trigger, LogicalKeyboardKey.keyA);
    expect(s.control, isTrue);
    expect(s.meta, isFalse);
    expect(s.shift, isFalse);
  });

  test('macOS binds Cmd only', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final s = primaryShortcut(LogicalKeyboardKey.keyA);
    expect(s.meta, isTrue);
    expect(s.control, isFalse);
    expect(s.shift, isFalse);
  });

  test('shift passes through on both platforms', () {
    for (final p in [TargetPlatform.windows, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = p;
      expect(primaryShortcut(LogicalKeyboardKey.keyS, shift: true).shift, true);
    }
  });
}
