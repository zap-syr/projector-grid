import 'package:flutter/material.dart';

import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';

/// Colours of the alert panels: the severity icon colours, readable text
/// tones of them for each theme, and the row surface.
class AlertPalette {
  const AlertPalette._(this._dark);

  factory AlertPalette.of(BuildContext context) =>
      AlertPalette._(Theme.of(context).brightness == Brightness.dark);

  final bool _dark;

  static Color icon(AlertSeverity s) =>
      s == AlertSeverity.critical ? Colors.red : Colors.orange;

  static IconData iconData(AlertSeverity s, {bool filled = true}) =>
      switch ((s, filled)) {
        (AlertSeverity.critical, true) => Icons.error,
        (AlertSeverity.critical, false) => Icons.error_outline,
        (AlertSeverity.warning, true) => Icons.warning,
        (AlertSeverity.warning, false) => Icons.warning_amber,
      };

  /// [icon] is too light for text on the light theme's surfaces.
  Color text(AlertSeverity s) => switch ((s, _dark)) {
    (AlertSeverity.critical, false) => const Color(0xFFC62828),
    (AlertSeverity.critical, true) => const Color(0xFFFF8A80),
    (AlertSeverity.warning, false) => const Color(0xFFB45F00),
    (AlertSeverity.warning, true) => const Color(0xFFFFB74D),
  };

  Color get item => _dark ? const Color(0xFF31343A) : const Color(0xFFF8F7F9);
}

/// One active alert: severity chip, rule name, the value large in the
/// severity colour, how long and since when, and Acknowledge in its own
/// column.
class AlertRow extends StatelessWidget {
  const AlertRow({
    super.key,
    required this.alert,
    required this.now,
    required this.onAcknowledge,
    this.title,
    this.titleNote,
  });

  /// Fixed so the panels can count the rows hidden below the fold.
  static const double height = 46;

  final ActiveAlert alert;
  final DateTime now;
  final VoidCallback onAcknowledge;

  /// Replaces the rule name, for lists grouped by rule (the projector is
  /// then the row's subject), with [titleNote] muted after it (its IP).
  final String? title;
  final String? titleNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AlertPalette.of(context);
    final severityIcon = AlertPalette.icon(alert.severity);
    final muted = colors.onSurfaceVariant.withValues(alpha: 0.75);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(7, 0, 6, 0),
      decoration: BoxDecoration(
        color: palette.item,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 10,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                severityIcon.withValues(alpha: 0.17),
                palette.item,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              AlertPalette.iconData(alert.severity),
              size: 16,
              color: severityIcon,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: title ?? alert.rule.label),
                      if (titleNote case final note?)
                        TextSpan(
                          text: '   $note',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: title == null
                      ? theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                          height: 1.2,
                        )
                      : theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                ),
                Text(
                  alert.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.text(alert.severity),
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              Text(
                formatAlertDuration(now.difference(alert.since)),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.2,
                ),
              ),
              Text(
                formatAlertStart(alert.since, now),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.2,
                ),
              ),
            ],
          ),
          AcknowledgeButton(onPressed: onAcknowledge),
        ],
      ),
    );
  }
}

/// 26px square, accent-outlined so it never reads as part of the row's text.
class AcknowledgeButton extends StatelessWidget {
  const AcknowledgeButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.check,
    this.label = 'Acknowledge',
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // No Tooltip: these panels hang off the card's MenuAnchor subtree, where
    // tooltips corrupt the Windows accessibility tree (see projector_card).
    return Semantics(
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          hoverColor: colors.secondaryContainer,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: colors.primary),
          ),
        ),
      ),
    );
  }
}

/// A quiet line for an acknowledged alert at the bottom of a panel.
class AcknowledgedAlertLine extends StatelessWidget {
  const AcknowledgedAlertLine({
    super.key,
    required this.alert,
    required this.now,
    this.prefix,
  });

  static const double height = 22;

  final ActiveAlert alert;
  final DateTime now;

  /// Bold text before the rule, e.g. the projector name in a project-wide
  /// list.
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          spacing: 8,
          children: [
            Icon(
              AlertPalette.iconData(alert.severity),
              size: 15,
              color: AlertPalette.icon(alert.severity),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (prefix != null)
                      TextSpan(
                        text: '$prefix ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    TextSpan(
                      text: '${alert.rule.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: alert.value),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            Text(
              formatAlertDuration(now.difference(alert.since)),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
