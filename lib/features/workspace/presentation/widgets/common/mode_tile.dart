import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../custom_tooltip.dart';

/// One choice in a [ModeTileRow]: icon + label (+ an optional muted line).
class ModeTileData<T> {
  const ModeTileData({
    required this.value,
    required this.icon,
    required this.label,
    this.shortLabel,
    this.detail,
    this.gapBefore = false,
  });

  final T value;
  final IconData icon;
  final String label;

  /// Used when the row is too narrow for [label]; the full label then goes
  /// into a tooltip.
  final String? shortLabel;

  /// Muted line under the label (Edge Blending: "No blending").
  final String? detail;

  /// A small extra gap before this tile, to split the row into families
  /// (Brightness: Normal / Eco / Quiet, then User 1 to 3).
  final bool gapBefore;
}

/// A row of equal-width mode tiles. The icon sits over the label when there
/// is no [ModeTileData.detail], left of label and detail otherwise. Tile
/// heights are per dialog: Brightness 60, Color Temperature 44, Geometry 46,
/// Edge Blending 54.
class ModeTileRow<T> extends StatelessWidget {
  const ModeTileRow({
    super.key,
    required this.tiles,
    required this.selected,
    required this.onSelected,
    required this.height,
    this.iconAbove = true,
    this.shortLabelsBelow = 0,
  });

  final List<ModeTileData<T>> tiles;

  /// Null selects none (a pair with mixed modes, a mode fixed elsewhere).
  final T? selected;

  /// Null disables every tile.
  final ValueChanged<T>? onSelected;
  final double height;

  /// Icon over the label; false puts it on the left (single-line tiles).
  final bool iconAbove;

  /// Below this width each tile shows its short label.
  final double shortLabelsBelow;

  static const double _gap = 8;
  static const double _familyGap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxWidth < shortLabelsBelow;
        return SizedBox(
          height: height,
          // Stretch: a tile whose content is a Row (iconAbove false) would
          // otherwise shrink to the label's height instead of [height].
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) SizedBox(width: t.gapBefore ? _familyGap : _gap),
                Expanded(
                  child: ModeTile(
                    icon: t.icon,
                    label: short && t.shortLabel != null
                        ? t.shortLabel!
                        : t.label,
                    tooltip: short && t.shortLabel != null ? t.label : null,
                    detail: t.detail,
                    iconAbove: iconAbove,
                    selected: t.value == selected,
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(t.value),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    this.tooltip,
    this.iconAbove = true,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final String? tooltip;
  final bool selected;
  final bool iconAbove;

  /// Null disables the tile (dimmed).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final enabled = onTap != null;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: iconAbove ? TextAlign.center : TextAlign.start,
      style: t.body.copyWith(
        color: fg,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
    final iconWidget = Icon(
      icon,
      size: 20,
      color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
    );
    final detailText = detail == null
        ? null
        : Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(
              color: selected
                  ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                  : cs.onSurfaceVariant,
            ),
          );

    final Widget content = iconAbove && detailText == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [iconWidget, const SizedBox(height: 4), labelText],
          )
        : Row(
            mainAxisAlignment: detailText == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, ?detailText],
                ),
              ),
            ],
          );

    final tile = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: content,
            ),
          ),
        ),
      ),
    );
    return tooltip == null
        ? tile
        : CustomTooltip(message: tooltip!, child: tile);
  }
}
