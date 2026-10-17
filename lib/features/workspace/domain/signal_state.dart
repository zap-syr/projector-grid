import 'projector_node.dart';

/// How the signal pill reads (Monitoring, the projector card's quick status).
enum SignalTone {
  /// A real signal: green, with its resolution.
  good,

  /// No signal while the projector is on: red.
  missing,

  /// Nothing to say: grey. Offline, a failed login, not polled yet, or no
  /// signal while the projector isn't on, when none is expected (owner,
  /// 2026-10-15).
  unknown,
}

/// The signal pill's label and tone for [node].
({String label, SignalTone tone}) signalStateOf(ProjectorNode node) {
  final reachable =
      node.connectionStatus == ConnectionStatus.connected ||
      node.connectionStatus == ConnectionStatus.unprotected;
  if (!reachable) return (label: 'Unknown', tone: SignalTone.unknown);
  if (!isUnusableSignalValue(node.signal)) {
    return (label: node.signal, tone: SignalTone.good);
  }
  if (node.signal.toUpperCase() == 'NO SIGNAL') {
    return (
      label: 'No signal',
      tone: node.powerStatus == PowerStatus.on
          ? SignalTone.missing
          : SignalTone.unknown,
    );
  }
  return (label: 'Unknown', tone: SignalTone.unknown);
}
