import 'package:material_ui/material_ui.dart';

import '../../../domain/geometry_modes.dart';
import '../common/mode_tile.dart';
import '../common/skeleton.dart';

/// The mode tiles (section 7.1), 46 px, icon left of the label. Short labels
/// (*Curved*, *Corner*) with the full name in a tooltip when the row is
/// narrow; skeleton tiles of the same size until the mode is read.
///
/// The fifth tile, *Free grid*, stands for the memories PC-1 to PC-3 and is
/// there only for a projector model that has them.
class GeometryModeTiles extends StatelessWidget {
  const GeometryModeTiles({
    super.key,
    required this.mode,
    required this.onSelected,
    this.showFreeGrid = false,
    this.othersEnabled = true,
  });

  /// Null while the current mode is being read. A memory PC-1 to PC-3 selects
  /// the Free grid tile.
  final GeometryMode? mode;

  /// Called with [freeGridTile] for the Free grid tile.
  final ValueChanged<GeometryMode> onSelected;
  final bool showFreeGrid;

  /// False dims every tile but the selected one (a write is running).
  final bool othersEnabled;

  static const double height = 46;

  /// Below this row width `Corner Correction` doesn't fit a fifth.
  static const double shortLabelsBelow = 860;

  /// The mode the Free grid tile stands for; the editor picks the memory.
  static const GeometryMode freeGridTile = GeometryMode.pc1;

  static const String freeGridLabel = 'Free grid';

  /// The tiles a skeleton shows: every model with a Free grid has five.
  static const int skeletonTiles = 5;

  static IconData iconOf(GeometryMode m) => switch (m) {
    GeometryMode.off => Icons.block,
    GeometryMode.keystone => Icons.transform,
    GeometryMode.curved => Icons.vrpano_outlined,
    GeometryMode.corner => Icons.zoom_out_map,
    GeometryMode.pc1 || GeometryMode.pc2 || GeometryMode.pc3 => Icons.grid_on,
  };

  @override
  Widget build(BuildContext context) {
    final current = mode;
    if (current == null) {
      return SkeletonPulse(
        child: SizedBox(
          key: const ValueKey('geometry-mode-tiles'),
          height: height,
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < skeletonTiles; i++)
                const Expanded(child: Skeleton(height: height, radius: 10)),
            ],
          ),
        ),
      );
    }
    final selected = current.isFreeGrid ? freeGridTile : current;
    return ModeTileRow<GeometryMode>(
      key: const ValueKey('geometry-mode-tiles'),
      height: height,
      iconAbove: false,
      shortLabelsBelow: shortLabelsBelow,
      horizontalPadding: 6,
      selected: selected,
      onSelected: onSelected,
      tiles: [
        for (final m in [
          ...GeometryMode.tileModes,
          if (showFreeGrid) freeGridTile,
        ])
          ModeTileData(
            value: m,
            icon: iconOf(m),
            label: m == freeGridTile ? freeGridLabel : m.label,
            shortLabel: m == freeGridTile || m.shortLabel == m.label
                ? null
                : m.shortLabel,
            enabled: othersEnabled || m == selected,
          ),
      ],
    );
  }
}
