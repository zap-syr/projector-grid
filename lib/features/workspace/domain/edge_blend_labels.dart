/// What the Edge Blending dialog says about its own state: the tab pills,
/// the pair's reply badge and the overlap readout (DIALOG_REDESIGN_PLAN
/// §7a). Pure, so the wording is tested without building the dialog.
library;

import 'edge_blend_pair.dart';

/// The Edge Blending tab's pill: `Off` while the mode is Off, `Linked`
/// while a pair's Link applies, otherwise how many edges blend. Null until
/// the projector has answered, so no count is guessed.
String? blendTabPill({
  required bool loaded,
  required bool off,
  required bool linked,
  required int enabledEdges,
}) {
  if (!loaded) return null;
  if (off) return 'Off';
  if (linked) return 'Linked';
  return switch (enabledEdges) {
    0 => 'No edges',
    1 => '1 edge',
    final n => '$n edges',
  };
}

/// How the two projectors of a pair answer the dialog.
enum PairReply { reading, online, aSilent, bSilent, bothSilent }

/// One projector's load state, as [pairReplyOf] reads it.
typedef SideReply = ({bool loading, bool unreachable});

/// Reading while either one still loads; then which ones never answered.
PairReply pairReplyOf(SideReply a, SideReply b) {
  if (a.loading || b.loading) return PairReply.reading;
  return switch ((a.unreachable, b.unreachable)) {
    (false, false) => PairReply.online,
    (true, false) => PairReply.aSilent,
    (false, true) => PairReply.bSilent,
    (true, true) => PairReply.bothSilent,
  };
}

/// The title bar badge of a pair.
String pairReplyLabel(PairReply reply) => switch (reply) {
  PairReply.reading => 'Reading',
  PairReply.online => 'Online',
  PairReply.aSilent => 'A not replying',
  PairReply.bSilent => 'B not replying',
  PairReply.bothSilent => 'Not replying',
};

/// `A` or `B`: how the dialog names the two sides of a pair.
String sideLetter(int side) => side == 0 ? 'A' : 'B';

/// The overlap [pairOverlap] implies, in A's panel pixels along the facing
/// axis and as a whole percentage of one raster.
({int px, int percent}) pairOverlapReadout(FacingEdge a, FacingEdge b) {
  final overlap = pairOverlap(a, b);
  return (px: (overlap * a.span).round(), percent: (overlap * 100).round());
}

/// `Overlap 640 px, 17% of a raster`.
String pairOverlapLabel(({int px, int percent}) readout) =>
    'Overlap ${readout.px} px, ${readout.percent}% of a raster';
