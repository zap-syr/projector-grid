import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_pair.dart';
import 'black_level_state.dart';
import 'edge_blend_side.dart';
import 'edge_blend_state.dart';

/// Every edit the dialog makes, routed so that pair mode's Link mirrors the
/// facing edge (plan §9): enable, Width and the overlapped level go to the
/// other projector's facing edge too. Start never does: it compensates each
/// projector's own position. Built per use from the dialog's current
/// sides, arrangement and toggle; with one side it just passes through.
class EdgeBlendLink {
  const EdgeBlendLink({
    required this.sides,
    required this.arrangement,
    required this.on,
  });

  final List<EdgeBlendSide> sides;
  final PairArrangement arrangement;

  /// The user's toggle; [linked] is whether it applies right now.
  final bool on;

  static bool _ready(EdgeBlendSide s) => !s.loading && !s.unreachable;

  bool get _bothReady => sides.length == 2 && sides.every(_ready);

  /// Widths are in each projector's own raster units: with different
  /// rasters a fixed ratio would be a guess, so Link is off the table.
  bool get available => _bothReady && !mixedRasters;

  bool get mixedRasters =>
      _bothReady && !canLinkRasters(sides[0].raster, sides[1].raster);

  bool get linked => on && available;

  /// The facing edge on the other projector, when [edge] of [side] is the
  /// linked one.
  ({EdgeBlendSide side, BlendEdge edge})? partnerOf(int side, BlendEdge edge) {
    if (!linked || edge != arrangement.facingOf(side)) return null;
    final other = 1 - side;
    return (side: sides[other], edge: arrangement.facingOf(other));
  }

  /// A linked Width has to fit both projectors (§8 on each).
  int maxFor(int side, BlendEdge edge, EdgePart part) {
    final s = sides[side];
    final own = s.blend.maxFor(edge, part, s.raster);
    final partner = part == EdgePart.width ? partnerOf(side, edge) : null;
    if (partner == null) return own;
    final p = partner.side;
    return linkedMax(own, p.blend.maxFor(partner.edge, part, p.raster));
  }

  void setEnabled(int side, BlendEdge edge, bool on) {
    sides[side].setEnabled(edge, on);
    final partner = partnerOf(side, edge);
    partner?.side.setEnabled(partner.edge, on);
  }

  void preview(int side, BlendEdge edge, EdgePart part, int v) {
    sides[side].preview(edge, part, v);
    final partner = part == EdgePart.width ? partnerOf(side, edge) : null;
    partner?.side.preview(partner.edge, part, v);
  }

  void commit(int side, BlendEdge edge, EdgePart part) {
    sides[side].commit(edge, part);
    final partner = part == EdgePart.width ? partnerOf(side, edge) : null;
    partner?.side.commit(partner.edge, part);
  }

  /// Start and Width to 0 here; on the partner only Width.
  void resetEdge(int side, BlendEdge edge) {
    sides[side].resetEdge(edge);
    final partner = partnerOf(side, edge);
    if (partner == null) return;
    partner.side
      ..preview(partner.edge, EdgePart.width, 0)
      ..commit(partner.edge, EdgePart.width);
  }

  /// The partner's overlapped slot, once its Black Level values are in: a
  /// level can't be mirrored into values that haven't loaded.
  ({EdgeBlendSide side, LevelSlot slot})? _levelPartner(
    int side,
    LevelSlot slot,
  ) {
    final edge = slot.edge;
    final partner = edge == null ? null : partnerOf(side, edge);
    if (partner == null || partner.side.black == null) return null;
    return (side: partner.side, slot: LevelSlot.overlap(partner.edge));
  }

  void previewLevel(int side, LevelSlot slot, RgbChannel channel, int v) {
    final s = sides[side];
    s.previewLevel(slot, channel, v);
    final partner = _levelPartner(side, slot);
    partner?.side.previewLevelValue(partner.slot, s.black![slot].value);
  }

  void commitLevel(int side, LevelSlot slot) {
    sides[side].commitLevel(slot);
    final partner = _levelPartner(side, slot);
    partner?.side.commitLevel(partner.slot);
  }

  void setInterlocked(int side, LevelSlot slot, bool on) {
    final s = sides[side];
    s.setInterlocked(slot, on);
    final partner = _levelPartner(side, slot);
    partner?.side.copyLevel(partner.slot, s.black![slot]);
  }

  /// Link turned on with different values: [side]'s facing edge wins,
  /// enable and Width ([copyLevelFrom] does the overlapped level). A Width
  /// over the other projector's own §8 limit stops at it; the two ramps
  /// then show different widths on the canvas.
  void copyFrom(int side) {
    if (!linked) return;
    final edge = arrangement.facingOf(side);
    final source = sides[side];
    final partner = partnerOf(side, edge)!;
    final p = partner.side;
    final e = source.blend[edge];
    p.setEnabled(partner.edge, e.enabled);
    final max = p.blend.maxFor(partner.edge, EdgePart.width, p.raster);
    p
      ..preview(partner.edge, EdgePart.width, e.width < max ? e.width : max)
      ..commit(partner.edge, EdgePart.width);
  }

  /// The overlapped level half of turning Link on, which can only run once
  /// both projectors' Black Level values are in. False when they aren't
  /// yet.
  bool copyLevelFrom(int side) {
    if (!linked) return false;
    final edge = arrangement.facingOf(side);
    final black = sides[side].black;
    final partner = partnerOf(side, edge)!;
    if (black == null || partner.side.black == null) return false;
    partner.side.copyLevel(
      LevelSlot.overlap(partner.edge),
      black[LevelSlot.overlap(edge)],
    );
    return true;
  }
}
