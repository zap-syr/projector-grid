import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/group_palette.dart';

/// The readable text/icon colour to paint on top of [background]; mirrors
/// how the card's group band picks its own text colour.
Color contrastOn(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.light
      ? const Color(0xFF15171B)
      : Colors.white;
}

/// The *Color* label and the 48-colour group palette across the full width:
/// 16 columns, light / base / dark rows. Colours in [usedColors] carry a
/// small white dot; that is only a hint, they stay selectable.
class GroupColorPalette extends StatelessWidget {
  const GroupColorPalette({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.background,
    this.usedColors = const {},
  });

  final int selected;
  final ValueChanged<int> onSelected;

  /// The surface behind the palette: the gap between a selected tile and
  /// its ring is painted in it.
  final Color background;
  final Set<int> usedColors;

  static const double _gap = 5;
  static const double _tileHeight = 26;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final rows = groupPalette.length ~/ groupPaletteHues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('Color', style: t.label)),
            if (usedColors.any(groupPalette.contains)) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: t.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Used by another group',
                style: t.caption.copyWith(color: t.secondary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Color',
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) const SizedBox(height: _gap),
                SizedBox(
                  height: _tileHeight,
                  child: Row(
                    children: [
                      for (var hue = 0; hue < groupPaletteHues; hue++) ...[
                        if (hue > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: _tile(context, row * groupPaletteHues + hue),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    final value = groupPalette[index];
    final color = Color(value);
    final isSelected = value == selected;
    final isUsed = usedColors.contains(value);
    final name = groupPaletteName(index);
    return Semantics(
      label: [name, if (isUsed) 'used by another group'].join(', '),
      selected: isSelected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: cs.onSurface, spreadRadius: 4),
                  BoxShadow(color: background, spreadRadius: 2),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('group-color-$value'),
            borderRadius: BorderRadius.circular(7),
            onTap: () => onSelected(value),
            child: Center(
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: contrastOn(color))
                  : isUsed
                  ? Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.35),
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
