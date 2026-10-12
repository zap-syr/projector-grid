/// The four edges of an Edge Blending setup, each with its NTCONTROL keys,
/// so the whole command table lives in one place (plan/EDGE_BLENDING_PLAN.md
/// §1).
enum BlendEdge {
  upper(
    label: 'Upper',
    enableCmd: 'GU',
    startCmd: 'EU',
    widthKey: 'EUWI0',
    borderCmd: 'JU',
    overlapKey: 'EBBS0',
    overlapInterlockKey: 'EBII3',
  ),
  lower(
    label: 'Lower',
    enableCmd: 'GB',
    startCmd: 'EB',
    widthKey: 'EBWI0',
    borderCmd: 'JB',
    overlapKey: 'EBBS1',
    overlapInterlockKey: 'EBII4',
  ),
  left(
    label: 'Left',
    enableCmd: 'GL',
    startCmd: 'EL',
    widthKey: 'ELWI0',
    borderCmd: 'JL',
    overlapKey: 'EBBS2',
    overlapInterlockKey: 'EBII5',
  ),
  right(
    label: 'Right',
    enableCmd: 'GR',
    startCmd: 'ER',
    widthKey: 'ERWI0',
    borderCmd: 'JR',
    overlapKey: 'EBBS3',
    overlapInterlockKey: 'EBII6',
  );

  final String label;

  /// Legacy short commands: `V<cmd>:1` / `Q<cmd>`.
  final String enableCmd;
  final String startCmd;
  final String borderCmd;

  /// VXX keys: `VXX:<key>=…` / `QVX:<key>`.
  final String widthKey;
  final String overlapKey;
  final String overlapInterlockKey;

  const BlendEdge({
    required this.label,
    required this.enableCmd,
    required this.startCmd,
    required this.widthKey,
    required this.borderCmd,
    required this.overlapKey,
    required this.overlapInterlockKey,
  });

  /// Left/Right are measured along the raster width, Upper/Lower along its
  /// height.
  bool get isHorizontal => this == left || this == right;

  /// The edge that shares the raster span with this one (§8: opposite
  /// widths add up to at most the raster).
  BlendEdge get opposite => switch (this) {
    upper => lower,
    lower => upper,
    left => right,
    right => left,
  };
}
