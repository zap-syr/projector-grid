import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/geometry_corners.dart';
import '../sleek_stepper_input.dart';

/// One corner in the controls card: name, a dot when it is moved off 0,
/// and its H / V fields in raw protocol units. Highlighted while the corner
/// is selected; a click selects it (Ctrl / Cmd / Shift click adds).
///
/// [twoLines] puts the fields under the name, for a card too narrow for one
/// line (the 72 px fields don't shrink).
class CornerRow extends StatelessWidget {
  const CornerRow({
    super.key,
    required this.corner,
    required this.h,
    required this.v,
    required this.hRange,
    required this.vRange,
    required this.selected,
    required this.twoLines,
    required this.onTap,
    required this.onH,
    required this.onV,
  });

  final GeometryCorner corner;
  final int h;
  final int v;
  final CornerRange hRange;
  final CornerRange vRange;
  final bool selected;
  final bool twoLines;
  final VoidCallback onTap;
  final ValueChanged<int> onH;
  final ValueChanged<int> onV;

  /// One line fits from this card width (name, H and V fields).
  static const double oneLineWidth = 330;

  static IconData _icon(GeometryCorner c) => switch (c) {
    GeometryCorner.ul => Icons.north_west,
    GeometryCorner.ur => Icons.north_east,
    GeometryCorner.ll => Icons.south_west,
    GeometryCorner.lr => Icons.south_east,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = selected ? cs.onPrimaryContainer : t.primary;
    final moved = h != 0 || v != 0;

    final name = Row(
      children: [
        Icon(
          _icon(corner),
          size: 16,
          color: selected ? cs.onPrimaryContainer : t.secondary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            corner.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(fontWeight: FontWeight.w500, color: fg),
          ),
        ),
        const SizedBox(width: 6),
        // Always laid out, so the name doesn't shift when the dot comes.
        Visibility(
          visible: moved,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Container(
            key: ValueKey('corner-moved-${corner.name}'),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected ? cs.onPrimaryContainer : cs.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );

    Widget field(
      String axis,
      int value,
      CornerRange range,
      ValueChanged<int> on,
    ) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          axis,
          style: t.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimaryContainer : t.secondary,
          ),
        ),
        const SizedBox(width: 6),
        SleekStepperInput(
          key: ValueKey('corner-${axis.toLowerCase()}-${corner.name}'),
          initialValue: '$value',
          min: range.min.toDouble(),
          max: range.max.toDouble(),
          onValueChanged: (s) {
            final parsed = double.tryParse(s)?.round();
            if (parsed != null) on(parsed);
          },
        ),
      ],
    );

    final fields = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [field('H', h, hRange, onH), field('V', v, vRange, onV)],
    );

    return Material(
      key: ValueKey('corner-row-${corner.name}'),
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
          // The 2 px selected border is drawn inside: keep the content put.
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: twoLines
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    SizedBox(height: 24, child: name),
                    fields,
                  ],
                )
              : SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Expanded(child: name),
                      const SizedBox(width: 8),
                      fields,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
