import 'package:flutter/material.dart';

import '../../../domain/geometry_modes.dart';
import '../common/mode_tile.dart';
import '../common/skeleton.dart';

/// The four mode tiles (§7.1), 46 px, icon left of the label. Short labels
/// (*Curved*, *Corner*) with the full name in a tooltip when the row is
/// narrow; skeleton tiles of the same size until the mode is read.
class GeometryModeTiles extends StatelessWidget {
  const GeometryModeTiles({
    super.key,
    required this.mode,
    required this.onSelected,
  });

  /// Null while the current mode is being read.
  final GeometryMode? mode;
  final ValueChanged<GeometryMode> onSelected;

  static const double height = 46;

  /// Below this row width `Corner Correction` doesn't fit a quarter.
  static const double shortLabelsBelow = 760;

  static IconData iconOf(GeometryMode m) => switch (m) {
    GeometryMode.off => Icons.block,
    GeometryMode.keystone => Icons.transform,
    GeometryMode.curved => Icons.vrpano_outlined,
    GeometryMode.corner => Icons.zoom_out_map,
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
              for (final _ in GeometryMode.values)
                const Expanded(child: Skeleton(height: height, radius: 10)),
            ],
          ),
        ),
      );
    }
    return ModeTileRow<GeometryMode>(
      key: const ValueKey('geometry-mode-tiles'),
      height: height,
      iconAbove: false,
      shortLabelsBelow: shortLabelsBelow,
      selected: current,
      onSelected: onSelected,
      tiles: [
        for (final m in GeometryMode.values)
          ModeTileData(
            value: m,
            icon: iconOf(m),
            label: m.label,
            shortLabel: m.shortLabel == m.label ? null : m.shortLabel,
          ),
      ],
    );
  }
}
