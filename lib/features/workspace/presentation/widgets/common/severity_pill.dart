import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/alert_rule.dart';

/// What a [SeverityPill] counts.
enum SeverityPillKind {
  critical,
  warning,

  /// Alerts that are over and not acknowledged yet.
  recovered;

  static SeverityPillKind of(AlertSeverity severity) => switch (severity) {
    AlertSeverity.critical => critical,
    AlertSeverity.warning => warning,
  };
}

/// A count of alerts of one kind (plan §7l.3): critical red, warning amber,
/// recovered green. [filled] (a tinted fill and a filled icon) while some
/// are unacknowledged, outlined once all are. Shared by the status bar and
/// the alerts panels' headers, so a count reads the same everywhere.
class SeverityPill extends StatelessWidget {
  const SeverityPill({
    super.key,
    required this.kind,
    required this.count,
    this.filled = true,
  });

  static const double height = 20;

  final SeverityPillKind kind;
  final int count;
  final bool filled;

  static Color colorOf(BuildContext context, SeverityPillKind kind) {
    final sc = AppStatusColors.of(context);
    return switch (kind) {
      SeverityPillKind.critical => Theme.of(context).colorScheme.error,
      SeverityPillKind.warning => sc.warning,
      SeverityPillKind.recovered => sc.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final color = colorOf(context, kind);
    final icon = switch ((kind, filled)) {
      (SeverityPillKind.critical, true) => Icons.error,
      (SeverityPillKind.critical, false) => Icons.error_outline,
      (SeverityPillKind.warning, true) => Icons.warning_rounded,
      (SeverityPillKind.warning, false) => Icons.warning_amber_rounded,
      (SeverityPillKind.recovered, true) => Icons.check_circle,
      (SeverityPillKind.recovered, false) => Icons.check_circle_outline,
    };
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 5, right: 7),
      decoration: ShapeDecoration(
        color: filled ? color.withValues(alpha: 0.16) : null,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: color.withValues(alpha: 0.85)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 14, color: color),
          Text(
            '$count',
            style: t.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
