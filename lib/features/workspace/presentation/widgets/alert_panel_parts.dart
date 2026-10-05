import 'package:flutter/material.dart';

import '../../domain/alert_rule.dart';
import 'alert_row.dart';

/// The raised surface both alert panels sit on.
class AlertPanelSurface extends StatelessWidget {
  const AlertPanelSurface({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.18,
            ),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A panel's title: a bold name and a muted note after it on one line.
class AlertPanelTitle extends StatelessWidget {
  const AlertPanelTitle({super.key, required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (note != null)
            TextSpan(
              text: '   $note',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Severity icon and a count, in the severity's text colour.
class AlertSeverityCount extends StatelessWidget {
  const AlertSeverityCount(this.severity, this.count, {super.key});

  final AlertSeverity severity;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Icon(
          AlertPalette.iconData(severity),
          size: 13,
          color: AlertPalette.icon(severity),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AlertPalette.of(context).text(severity),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// [AlertSeverityCount] for the alerts that are over (a signal that came
/// back): a green check.
class AlertRecoveredCount extends StatelessWidget {
  const AlertRecoveredCount(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        const Icon(
          Icons.check_circle,
          size: 13,
          color: AlertPalette.recoveredIcon,
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AlertPalette.of(context).recovered,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// 28px icon button. No tooltip, for the same reason as AcknowledgeButton.
class AlertPanelIconButton extends StatelessWidget {
  const AlertPanelIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

/// The fold header of a panel's acknowledged alerts.
class AcknowledgedHeader extends StatelessWidget {
  const AcknowledgedHeader({
    super.key,
    required this.count,
    required this.open,
    required this.onTap,
  });

  static const double height = 26;

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 3),
        child: Row(
          spacing: 4,
          children: [
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 120),
              child: Icon(Icons.chevron_right, size: 15, color: color),
            ),
            Text(
              'ACKNOWLEDGED ($count)',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0.7,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
