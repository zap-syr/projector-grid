import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import 'common/dialog_parts.dart';
import 'common/severity_pill.dart';
import 'custom_tooltip.dart';

/// Severity icons and colours of the alerts panels and the card badge. The
/// colours are the app's status colours (plan §7m.5), the same as the
/// [SeverityPill]s.
class AlertPalette {
  const AlertPalette._();

  static IconData iconData(AlertSeverity s, {bool filled = true}) =>
      switch ((s, filled)) {
        (AlertSeverity.critical, true) => Icons.error,
        (AlertSeverity.critical, false) => Icons.error_outline,
        (AlertSeverity.warning, true) => Icons.warning,
        (AlertSeverity.warning, false) => Icons.warning_amber,
      };

  /// Red, amber, or green for an alert that is over.
  static Color colorOf(BuildContext context, ActiveAlert a) =>
      SeverityPill.colorOf(
        context,
        a.recovered
            ? SeverityPillKind.recovered
            : SeverityPillKind.of(a.severity),
      );

  static IconData iconOf(ActiveAlert a, {bool filled = true}) => a.recovered
      ? (filled ? Icons.check_circle : Icons.check_circle_outline)
      : iconData(a.severity, filled: filled);
}

/// The message of an alert row with, for an alert that is over, its green
/// `, over at 21:03` tail (plan §7m.2).
TextSpan alertMessageSpan(
  BuildContext context,
  ActiveAlert a,
  DateTime now, {
  bool inAlertGroup = false,
}) {
  final over = alertOverAt(a, now);
  return TextSpan(
    text: alertMessage(a, inAlertGroup: inAlertGroup),
    children: [
      if (over != null) ...[
        const TextSpan(text: ', '),
        TextSpan(
          text: over,
          style: TextStyle(color: AppStatusColors.of(context).success),
        ),
      ],
    ],
  );
}

/// One unacknowledged alert (plan §7m.2): a soft row with the severity edge
/// and icon, the message in the primary text colour with the kind under it
/// (or, grouped by alert, the projector with the message under it), the
/// start time and a quiet Acknowledge.
class AlertRow extends StatefulWidget {
  const AlertRow({
    super.key,
    required this.alert,
    required this.now,
    required this.onAcknowledge,
    this.ip,
    this.model,
    this.limit,
  });

  /// A temperature alert's threshold for the start time's tooltip
  /// (`alertLimit`), null for the other rules.
  final String? limit;

  /// One line of message; [tallHeight] when it takes two. Fixed per row so
  /// the panels can count the rows hidden below the fold.
  static const double height = 52;
  static const double tallHeight = 70;

  final ActiveAlert alert;
  final DateTime now;
  final VoidCallback onAcknowledge;

  /// Grouped by alert, the projector leads the row: [ip] in mono and the
  /// [model] after it, the message under them.
  final String? ip;
  final String? model;

  // The row's fixed parts left and right of the text, in build order.
  static const double _edge = 3;
  static const double _lead = 12;
  static const double _icon = 18;
  static const double _gap = 10;
  static const double _timeGap = 6;
  static const double _end = 4;

  /// [height] or [tallHeight] for [alert] in a row [width] wide: whether
  /// its message wraps, measured in the theme's font (the [AppText] roles
  /// carry none, so the measure merges them onto the ambient body style).
  static double heightFor(
    BuildContext context, {
    required ActiveAlert alert,
    required DateTime now,
    required double width,
    bool withProjector = false,
  }) {
    final t = AppText.of(context);
    final ambient =
        Theme.of(context).textTheme.bodyMedium ??
        DefaultTextStyle.of(context).style;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final time = TextPainter(
      text: TextSpan(
        text: formatAlertStart(alert.since, now),
        style: ambient.merge(t.monoSmall),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final textWidth =
        width -
        _lead -
        _icon -
        _gap -
        _gap -
        time.width -
        _timeGap -
        AcknowledgeButton.size -
        _end;
    time.dispose();
    final message = TextPainter(
      text: TextSpan(
        style: ambient.merge(withProjector ? t.description : _messageStyle(t)),
        children: [
          alertMessageSpan(context, alert, now, inAlertGroup: withProjector),
        ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 2,
    )..layout(maxWidth: textWidth < 1 ? 1 : textWidth);
    final lines = message.computeLineMetrics().length;
    message.dispose();
    return lines > 1 ? tallHeight : height;
  }

  static TextStyle _messageStyle(AppText t) =>
      t.body.copyWith(fontWeight: FontWeight.w500);

  @override
  State<AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends State<AlertRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final alert = widget.alert;
    final color = AlertPalette.colorOf(context, alert);
    final soft = DialogSurfaces.of(context).soft;
    // Grouped by alert ([AlertRow.ip] set), the header names the rule.
    final message = alertMessageSpan(
      context,
      alert,
      widget.now,
      inAlertGroup: widget.ip != null,
    );

    final List<Widget> lines;
    if (widget.ip case final ip?) {
      lines = [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: ip, style: t.mono),
              if (widget.model case final model?)
                TextSpan(text: '  $model', style: t.description),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text.rich(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.description,
        ),
      ];
    } else {
      lines = [
        Text.rich(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AlertRow._messageStyle(t),
        ),
        Text(
          alertKind(alert.rule),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.description,
        ),
      ];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hover
              ? Color.alphaBlend(t.primary.withValues(alpha: 0.05), soft)
              : soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 9,
              bottom: 9,
              width: AlertRow._edge,
              child: DecoratedBox(
                key: const ValueKey('alert-row-edge'),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  const SizedBox(width: AlertRow._lead),
                  Icon(
                    AlertPalette.iconOf(alert),
                    size: AlertRow._icon,
                    color: color,
                  ),
                  const SizedBox(width: AlertRow._gap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 1,
                      children: lines,
                    ),
                  ),
                  const SizedBox(width: AlertRow._gap),
                  CustomTooltip(
                    message: formatAlertStarted(
                      alert.since,
                      widget.now,
                      limit: widget.limit,
                    ),
                    child: Text(
                      formatAlertStart(alert.since, widget.now),
                      key: const ValueKey('alert-row-time'),
                      style: t.monoSmall,
                    ),
                  ),
                  const SizedBox(width: AlertRow._timeGap),
                  AcknowledgeButton(onPressed: widget.onAcknowledge),
                  const SizedBox(width: AlertRow._end),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quiet 30 px Acknowledge of a row (check), or of a group or section
/// (double check, [label] naming what it takes): `secondary`, filled with
/// the primary container on hover, its name in a [CustomTooltip] (never a
/// Material tooltip, plan §7m.5).
class AcknowledgeButton extends StatefulWidget {
  const AcknowledgeButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.check,
    this.label = 'Acknowledge',
  });

  static const double size = 30;

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  State<AcknowledgeButton> createState() => _AcknowledgeButtonState();
}

class _AcknowledgeButtonState extends State<AcknowledgeButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomTooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        container: true,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (h) => setState(() => _hover = h),
            borderRadius: BorderRadius.circular(9),
            child: Ink(
              width: AcknowledgeButton.size,
              height: AcknowledgeButton.size,
              decoration: BoxDecoration(
                color: _hover ? cs.primaryContainer : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: _hover ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 30 px line of an acknowledged alert in a panel's fold (plan §7m.3):
/// the outlined severity icon, the projector's IP, the message and the
/// start time.
class AcknowledgedAlertLine extends StatelessWidget {
  const AcknowledgedAlertLine({
    super.key,
    required this.alert,
    required this.now,
    this.ip,
  });

  static const double height = 30;

  final ActiveAlert alert;
  final DateTime now;

  /// Left out in the one-projector panel, whose header names it.
  final String? ip;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 8, 0),
      // On one baseline: the mono IP and time sat off the message's line
      // when each was centred on its own.
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(
            AlertPalette.iconOf(alert, filled: false),
            size: 15,
            color: AlertPalette.colorOf(context, alert),
          ),
          if (ip case final ip?)
            Text(ip, style: t.monoSmall.copyWith(color: t.primary)),
          Expanded(
            child: Text.rich(
              alertMessageSpan(context, alert, now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description,
            ),
          ),
          Text(
            formatAlertStart(alert.since, now),
            style: t.monoSmall.copyWith(color: t.tertiary),
          ),
        ],
      ),
    );
  }
}
