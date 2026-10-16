import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/color_correction.dart';
import 'color_swatches.dart';

/// One colour of Color Matching: a dot over the name (7 colors), or a dot
/// left of the name and its values (3 colors, [wide]). Both are [height]
/// tall, so the editor under them doesn't move between the methods. A small
/// dot in the corner marks values that differ from the default.
class ColorTile extends StatelessWidget {
  const ColorTile({
    super.key,
    required this.color,
    required this.rgb,
    required this.selected,
    required this.wide,
    required this.onTap,
  });

  static const double height = 58;

  final MatchColor color;
  final List<int> rgb;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    final changed = !color.isDefault(rgb);

    Widget dot(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: swatchOf(color),
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant),
      ),
    );

    final Widget content = wide
        ? Row(
            spacing: 12,
            children: [
              dot(22),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      color.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rgb.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.monoSmall.copyWith(
                        color: selected ? cs.onPrimaryContainer : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              dot(18),
              Text(
                color.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(color: fg),
              ),
            ],
          );

    return Semantics(
      button: true,
      selected: selected,
      label: changed ? '${color.label}, changed' : color.label,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
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
            onTap: selected ? null : onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 2),
                    child: content,
                  ),
                ),
                if (changed)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      key: const ValueKey('color-tile-changed'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
