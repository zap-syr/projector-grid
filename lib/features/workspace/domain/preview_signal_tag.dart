import '../../../core/services/projector_web_status_service.dart';
import 'projector_node.dart';

/// The bottom-right tag on a live Remote Preview frame; null when nothing is
/// known yet. Shared by the app's viewport and the Web API's preview stream.
///
/// Primary source is [webSignal] — the projector's own web UI, event-driven
/// off the preview socket's SIGNAL message (see previewSignalStatusProvider);
/// it works in every power state, unlike NTCONTROL. That provider keeps its
/// last known-good value across a transient fetch failure, so the polled node
/// fields are only a fallback until the very first fetch lands, not on every
/// failure — that would mean displaying NTCONTROL's own stale/ER401 reading
/// with no time bound, the exact staleness this tag exists to avoid.
///  - web says a real signal  -> "HDMI1 · 3840x2160/60p (134.99kHz/59.99Hz)"
///  - web says no signal      -> "No signal" (authoritative — built-in test
///    pattern / no external input, in any power state)
///  - no fetch has ever landed, polled value real -> that, same format
///  - polled value also unusable  -> "No signal" if that's what NTCONTROL
///    said, else no tag (nothing known yet)
String? previewSignalTag(ProjectorNode node, WebSignalStatus? webSignal) {
  bool real(String s) => !isUnusableSignalValue(s);
  if (webSignal != null) {
    if (!webSignal.hasSignal) return 'No signal';
    final input = webSignal.input.isNotEmpty ? webSignal.input : node.input;
    final freq = webSignal.signalFrequency;
    final detail = freq.isNotEmpty
        ? '${webSignal.signalName} ($freq)'
        : webSignal.signalName;
    return real(input) ? '$input · $detail' : detail;
  }
  if (real(node.signal)) {
    return real(node.input) ? '${node.input} · ${node.signal}' : node.signal;
  }
  if (node.signal.toUpperCase() == 'NO SIGNAL') return 'No signal';
  return null;
}
