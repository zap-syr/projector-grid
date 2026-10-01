/// Remote Preview's pre-show mode (REMOTE_PREVIEW_PLAN.md §4.3): the
/// projector keeps its input alive for the preview while staying off.
library;

/// The projector's `QVX:PSMI1` reply → whether pre-show is on; null when the
/// reply is missing or unreadable (e.g. ER401 mid-transition).
bool? parsePreShowResponse(String? response) {
  if (response == null) return null;
  final i = response.indexOf('PSMI1=');
  if (i < 0) return null;
  final v = response.substring(i + 6).trim();
  if (v.startsWith('+00001')) return true;
  if (v.startsWith('+00000')) return false;
  return null;
}

/// One projector's pre-show as the app knows it: [on] is null until read,
/// [applying] while a change is sent but not yet confirmed (entering takes
/// ~12 s to report back).
typedef PreShowState = ({bool? on, bool applying});
