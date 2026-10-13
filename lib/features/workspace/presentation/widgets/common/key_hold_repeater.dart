import 'dart:async';

import 'package:flutter/services.dart';

/// Arrow-key stepping shared by the settings canvases (Corner Correction,
/// Edge Blending): one step on press, continuous steps once the key is held
/// past [holdDelay], and [onRelease] once on key-up — where the value gets
/// sent, so a held key costs one command, not one per step.
class KeyHoldRepeater {
  KeyHoldRepeater({required this.onStep, required this.onRelease});

  /// Short tap → 1 step only. Hold past this delay → continuous movement.
  static const holdDelay = Duration(milliseconds: 400);

  /// Continuous movement rate — intentionally slow for fine control.
  static const repeatInterval = Duration(milliseconds: 40);

  final void Function(LogicalKeyboardKey key) onStep;
  final void Function() onRelease;

  Timer? _holdTimer;
  Timer? _repeatTimer;
  LogicalKeyboardKey? _held;

  /// The key being stepped, null when none is down.
  LogicalKeyboardKey? get held => _held;

  void press(LogicalKeyboardKey key) {
    if (_held == key) return;
    _cancel();
    _held = key;
    onStep(key);
    _holdTimer = Timer(holdDelay, () {
      _repeatTimer = Timer.periodic(repeatInterval, (_) => onStep(key));
    });
  }

  void release() {
    if (_held == null) return;
    _cancel();
    onRelease();
  }

  void dispose() => _cancel();

  void _cancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _held = null;
  }
}
