import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the app window's close waits for on a free grid session: a write that
/// runs (cut between frames it would leave the memory half written and
/// never saved) and the grid overlay or cursor it left on the projector.
abstract interface class WarpCloseParticipant {
  /// Whether a write is running or something is still shown on the
  /// projector.
  bool needsCloseSettle();

  /// Waits for the running write, then takes the overlay and the cursor off.
  Future<void> settleForClose();
}

/// The open free grid sessions, so that `onWindowClose` can settle them
/// before it destroys the window. It decides nothing: closing stays
/// `_MainWorkspaceScreenState.onWindowClose`'s.
class WarpWindowCloseGuard {
  final Set<WarpCloseParticipant> _participants = {};

  void register(WarpCloseParticipant participant) =>
      _participants.add(participant);

  void unregister(WarpCloseParticipant participant) =>
      _participants.remove(participant);

  /// Waits for the sessions that need it, for up to [timeout] in all, so an
  /// unreachable projector cannot hold the window. Returns at once when no
  /// session has anything to settle.
  Future<void> settle({Duration timeout = const Duration(seconds: 10)}) async {
    final pending = [
      for (final p in _participants.toList())
        if (p.needsCloseSettle()) p.settleForClose(),
    ];
    if (pending.isEmpty) return;
    await Future.wait(pending).timeout(timeout, onTimeout: () => const []);
  }
}

/// One guard for the app (a plain provider is kept alive). Written by hand:
/// it has no generated sibling.
final warpWindowCloseGuardProvider = Provider<WarpWindowCloseGuard>(
  (ref) => WarpWindowCloseGuard(),
);
