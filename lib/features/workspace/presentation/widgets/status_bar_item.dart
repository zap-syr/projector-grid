import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'custom_tooltip.dart';

/// One item of the status bar (plan §7l.1): a 28 px flat button, radius 8,
/// a light fill on hover and while [pressed]. [onTap] null makes it plain
/// (Updated); [dimmed] greys it out in place and takes the click away (a
/// count at 0).
class StatusBarItem extends StatelessWidget {
  const StatusBarItem({
    super.key,
    required this.children,
    this.onTap,
    this.pressed = false,
    this.dimmed = false,
    this.narrow = false,
    this.tooltip,
    this.tooltipDetail,
    this.tooltipWarning = false,
    this.tooltipBody,
    this.semanticLabel,
  });

  static const double height = 28;

  final List<Widget> children;
  final VoidCallback? onTap;
  final bool pressed;
  final bool dimmed;

  /// Less padding, for the narrow bar.
  final bool narrow;
  final String? tooltip;
  final String? tooltipDetail;
  final bool tooltipWarning;
  final WidgetBuilder? tooltipBody;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final tap = dimmed ? null : onTap;
    Widget item = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 8),
      decoration: BoxDecoration(
        color: pressed ? cs.onSurface.withValues(alpha: 0.10) : null,
        borderRadius: radius,
      ),
      // Here, not only on the bar: the InkWell's Material below resets the
      // default text style to bodyMedium, which would make a clickable item
      // wider than the same one dimmed.
      child: DefaultTextStyle.merge(
        style: AppText.of(context).description,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: children,
        ),
      ),
    );
    if (tap != null) {
      // Its own Material: the bar's coloured container would otherwise hide
      // the hover, which the InkWell paints on the nearest Material below.
      item = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          borderRadius: radius,
          hoverColor: cs.onSurface.withValues(alpha: 0.08),
          child: item,
        ),
      );
    }
    if (dimmed) item = Opacity(opacity: 0.45, child: item);
    if (tooltip case final message?) {
      item = CustomTooltip(
        message: message,
        detail: tooltipDetail,
        warning: tooltipWarning,
        body: tooltipBody,
        placement: TooltipPlacement.bottom,
        child: item,
      );
    }
    return Semantics(button: tap != null, label: semanticLabel, child: item);
  }
}

/// The thin vertical line between the bar's groups.
class StatusBarDivider extends StatelessWidget {
  const StatusBarDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// A small status dot (online, offline, OSC listening).
class StatusBarDot extends StatelessWidget {
  const StatusBarDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A count in the bar: `body` w600 with tabular figures, so a changing
/// number keeps its digit width.
class StatusBarCount extends StatelessWidget {
  const StatusBarCount(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count',
    style: AppText.of(context).body.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
