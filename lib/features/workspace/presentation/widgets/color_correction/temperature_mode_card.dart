import 'package:flutter/material.dart';

import '../../../domain/color_correction.dart';
import '../common/lock_pill.dart';
import '../common/mode_tile.dart';
import '../common/skeleton.dart';
import 'card_heading.dart';

/// Color Temperature's first card: Default / User 1 / User 2 / Custom. While
/// Color Matching is on ([fixedBy]) the projector has no temperature mode,
/// so the tiles are dimmed, none is selected, and a lock pill says why.
class TemperatureModeCard extends StatelessWidget {
  const TemperatureModeCard({
    super.key,
    required this.mode,
    required this.fixedBy,
    required this.loading,
    required this.onSelected,
  });

  final TempMode mode;

  /// The Color Matching method that fixes the mode; null when it is off.
  final MatchMethod? fixedBy;
  final bool loading;
  final ValueChanged<TempMode> onSelected;

  static const double tileHeight = 44;

  static IconData _icon(TempMode m) => switch (m) {
    TempMode.defaultTemp => Icons.factory_outlined,
    TempMode.user1 || TempMode.user2 => Icons.person_outline,
    TempMode.custom => Icons.thermostat_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final fixed = fixedBy;
    final subtitle = loading
        ? null
        : fixed != null
        ? 'Fixed while Color Matching is on'
        : switch (mode) {
            TempMode.defaultTemp =>
              'The projector\'s factory color temperature',
            TempMode.user1 ||
            TempMode.user2 => 'User 1 and User 2 keep their own white balance',
            TempMode.custom => 'Custom sets an exact temperature in kelvin',
          };
    return ColorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          ColorCardHeading(
            title: 'Mode',
            subtitle: subtitle,
            trailing: fixed == null || loading
                ? null
                : LockPill('Color Matching: ${fixed.label}'),
          ),
          if (loading)
            SkeletonPulse(
              child: Row(
                spacing: 8,
                children: [
                  for (final _ in TempMode.values)
                    const Expanded(
                      child: Skeleton(height: tileHeight, radius: 10),
                    ),
                ],
              ),
            )
          else
            ModeTileRow<TempMode>(
              height: tileHeight,
              iconAbove: false,
              selected: fixed == null ? mode : null,
              onSelected: fixed == null ? onSelected : null,
              tiles: [
                for (final m in TempMode.values)
                  ModeTileData(value: m, icon: _icon(m), label: m.label),
              ],
            ),
        ],
      ),
    );
  }
}
