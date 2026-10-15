import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs only the last action handed to [run] once [delay] passes without
/// another call: a burst of − / + presses or preset taps becomes one write
/// to the projector instead of a TCP connection per click.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;
  VoidCallback? _pending;

  void run(VoidCallback action) {
    _pending = action;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Runs a pending action now (e.g. on dispose, so the last press still
  /// reaches the projector).
  void flush() {
    _timer?.cancel();
    _timer = null;
    final action = _pending;
    _pending = null;
    action?.call();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
