import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';
import '../common/labeled_slider_row.dart';

/// A small pill in a card header. Neutral (`Extended inward range`) unless it shows state: [selected] for the corner selection.
class GeometryPill extends StatelessWidget {
  const GeometryPill(this.label, {super.key, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(11),
      ),
      // widthFactor 1: as wide as the label, not the space it is given.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimaryContainer : t.secondary,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// The header of a group in the controls card: `Keystone degrees` on the
/// left, the range or a control on the right.
class GeometryGroupHeader extends StatelessWidget {
  const GeometryGroupHeader({
    super.key,
    required this.title,
    this.unit,
    this.range,
    this.trailing,
  });

  final String title;
  final String? unit;
  final String? range;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: '  $unit',
                        style: t.caption.copyWith(color: t.tertiary),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.label,
              ),
            ),
            const SizedBox(width: 12),
            if (range != null)
              // Its own width, so it sits at the right edge; capped so a
              // narrow card still shows the title.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.6,
                ),
                child: Text(
                  range!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption,
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// `Linearity -127 to 127` above a block of rows inside a group.
class GeometrySubHeader extends StatelessWidget {
  const GeometrySubHeader({super.key, required this.title, this.range});

  final String title;
  final String? range;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text.rich(
        TextSpan(
          text: title,
          children: [
            if (range != null)
              TextSpan(
                text: '  $range',
                style: t.caption.copyWith(fontWeight: FontWeight.w400),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: t.secondary,
        ),
      ),
    );
  }
}

/// One thin slider with its 32 px value field, label on the left. Every
/// Geometry range is symmetric, so the fill starts at the centre zero tick.
class GeometrySliderRow extends StatelessWidget {
  const GeometrySliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.step = 1,
    this.snap = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool snap;

  /// Both null: disabled and dimmed (Auto linearity and pincushion).
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Fits `Horizontal`, the longest label.
  static const double labelWidth = 80;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final enabled = onChanged != null || onChangeEnd != null;
    return LabeledSliderRow(
      labelWidth: labelWidth,
      labelStyle: t.body.copyWith(color: enabled ? t.secondary : t.disabled),
      label: label,
      zeroFraction: 0.5,
      value: value,
      min: min,
      max: max,
      step: step,
      snap: snap,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// A label + description row with a control on the right (Throw ratio,
/// Maintain aspect ratio).
class GeometrySettingRow extends StatelessWidget {
  const GeometrySettingRow({
    super.key,
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.description,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );
  }
}

/// The right-hand card: groups split by thin dividers, scrolling with a
/// scrollbar and a fade when the window is too short for them.
class GeometryControlsCard extends StatelessWidget {
  const GeometryControlsCard({super.key, required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.6),
    );
    return DialogCard(
      key: const ValueKey('geometry-controls-card'),
      child: DialogScrollBody(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, g) in groups.indexed) ...[
              if (i > 0) divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: g,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A group of the controls card: header, then its rows.
class GeometryGroup extends StatelessWidget {
  const GeometryGroup({super.key, required this.header, required this.rows});

  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [header, ...rows],
  );
}
