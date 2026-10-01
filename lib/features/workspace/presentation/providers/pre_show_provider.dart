import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/pre_show.dart';
import '../../domain/projector_node.dart';
import 'protocol_service_provider.dart';
import 'remote_preview_provider.dart';
import 'workspace_provider.dart';

part 'pre_show_provider.g.dart';

/// One projector's pre-show while a Remote Preview of it is open — in the
/// app's dialog or on a web page — so both show the same state and either can
/// change it. Not `keepAlive`: read on first watch, forgotten when the last
/// preview closes (pre-show itself is sticky projector-side).
@riverpod
class PreShow extends _$PreShow {
  // Bumped on every change so a superseded confirmation loop bails out.
  int _gen = 0;

  @override
  PreShowState build(String nodeId) {
    unawaited(_load());
    return (on: null, applying: false);
  }

  ProjectorNode? get _node =>
      ref.read(workspaceProvider).where((n) => n.id == nodeId).firstOrNull;

  Future<void> _load() async {
    final n = _node;
    if (n == null || n.powerStatus != PowerStatus.standby) return;
    final on = parsePreShowResponse(await _sendPsmi(n));
    if (ref.mounted && on != null) state = (on: on, applying: state.applying);
  }

  /// Enter / leave pre-show over the preview socket — the caller checks the
  /// projector is in Standby with a live feed, since without one the command
  /// is silently dropped and never confirmed.
  Future<void> set(bool on) async {
    final n = _node;
    if (n == null) return;
    final gen = ++_gen;
    ref.read(remotePreviewProvider(n.ipAddress).notifier).setPreshow(on);
    // Reflect the intent at once: the WebSocket command has no reply, and
    // the projector takes seconds (≈12 s to enter) to report it over
    // NTCONTROL.
    state = (on: on, applying: true);

    // Confirm in the background: poll QVX:PSMI1 until it reports the value
    // asked for (ignoring transient ER401 during the transition), or give up
    // after a generous window and keep the optimistic value.
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!ref.mounted || _gen != gen) return;
      final back = parsePreShowResponse(await _sendPsmi(n));
      if (!ref.mounted || _gen != gen) return;
      if (back == on) break;
    }
    state = (on: on, applying: false);
  }

  // These probes run outside workspaceProvider's poll cycle and its
  // concurrency throttling (unthrottled NTCONTROL bursts risk ERR3/busy and
  // false-offline misreads — see panasonic_protocol_service.dart). Claiming
  // the node first (rather than just checking isPolling) keeps QVX:PSMI1
  // from landing on a projector's NTCONTROL socket at the same moment the
  // regular poll cycle starts on it: isPolling only says a cycle is running
  // right now, not that one is about to claim this specific node next.
  Future<String?> _sendPsmi(ProjectorNode n) async {
    final workspace = ref.read(workspaceProvider.notifier);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var claimed = workspace.claimNodeForExternalPoll(n.id);
    while (ref.mounted && !claimed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      claimed = workspace.claimNodeForExternalPoll(n.id);
    }
    if (!ref.mounted) {
      // The claim can succeed on the very iteration that races past
      // disposal — release it now since the try/finally below never runs.
      if (claimed) workspace.releaseNodeFromExternalPoll(n.id);
      return null;
    }
    try {
      // Best-effort: if the deadline passed without ever claiming the node,
      // send anyway rather than block the preview indefinitely.
      return await ref
          .read(protocolServiceProvider)
          .sendRawCommand(
            n.ipAddress,
            n.port,
            n.login,
            n.password,
            'QVX:PSMI1',
          );
    } finally {
      if (claimed) workspace.releaseNodeFromExternalPoll(n.id);
    }
  }
}
