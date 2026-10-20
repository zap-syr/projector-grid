import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/event_log_rows.dart';
import '../../../domain/event_log_view.dart';
import '../../../domain/log_event.dart';
import '../common/status_pill.dart';
import 'event_log_row.dart';

/// A command sent to several projectors (plan §7k.3): a chevron, the
/// target (`Stage, 6 projectors`), the command with where it came from and
/// the result as pills. A click opens the projector lines under it.
/// *Retry failed* shows on hover when some failed.
class EventLogBatchRow extends StatefulWidget {
  const EventLogBatchRow({
    super.key,
    required this.row,
    required this.open,
    required this.onToggle,
    required this.onRetry,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
  });

  final BatchLogRow row;
  final bool open;
  final VoidCallback onToggle;

  /// Sends the command again to the failed projectors.
  final VoidCallback onRetry;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;

  @override
  State<EventLogBatchRow> createState() => _EventLogBatchRowState();
}

class _EventLogBatchRowState extends State<EventLogBatchRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final t = AppText.of(context);
    final row = widget.row;
    // Only once every reply is in: retrying mid-flight would send twice to
    // a projector whose answer is still on its way.
    final canRetry = row.done && row.failed > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: EventLogRowFrame(
          severity: row.severity,
          overlay: canRetry && _hover
              ? _RetryButton(onPressed: widget.onRetry)
              : null,
          cells: [
            EventLogTimeCell(formatLogTime(row.timestamp, widget.now)),
            EventLogIconCell(EventLogSeverityIcon(row.severity)),
            SizedBox(
              width: widget.narrow
                  ? EventLogColumns.projectorNarrow
                  : EventLogColumns.projector,
              child: Row(
                children: [
                  Icon(
                    widget.open ? Icons.expand_more : Icons.chevron_right,
                    key: const ValueKey('event-log-batch-chevron'),
                    size: 16,
                    color: t.secondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: HighlightedText(
                      row.batch.target,
                      query: widget.query,
                      style: t.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            if (widget.showSource)
              const EventLogSourceCell(LogEventType.command),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: EventLogCommandText(
                      message: row.commandName,
                      source: row.source,
                      query: widget.query,
                    ),
                  ),
                  for (final (outcome, label) in batchPills(row)) ...[
                    const SizedBox(width: 8),
                    StatusPill(
                      label: label,
                      color: switch (outcome) {
                        CommandOutcome.sent => sc.success,
                        CommandOutcome.failed => cs.error,
                        CommandOutcome.skipped => t.secondary,
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The row's hover action, the short text button of Monitoring's rows.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      // Over the end of the row: its own fill keeps the pills under it from
      // showing through.
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        key: const ValueKey('event-log-retry-failed'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 28),
          fixedSize: const Size.fromHeight(28),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: t.description.copyWith(fontWeight: FontWeight.w500),
        ),
        child: const Text('Retry failed'),
      ),
    );
  }
}

/// One projector of an open batch, under a tree line: IP and model, then
/// green *Sent*, red *Failed* with the reason or grey *Skipped* with the
/// reason.
class EventLogBatchLine extends StatelessWidget {
  const EventLogBatchLine({
    super.key,
    required this.event,
    required this.last,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
  });

  final LogEvent event;

  /// The batch's last line: the tree line ends here.
  final bool last;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;

  static const double _indent = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final t = AppText.of(context);
    final (icon, color, label) = switch (event.outcome) {
      CommandOutcome.failed => (Icons.error, cs.error, 'Failed'),
      CommandOutcome.skipped => (
        Icons.remove_circle_outline,
        cs.outline,
        'Skipped',
      ),
      _ => (Icons.check_circle_outline, sc.success, 'Sent'),
    };
    final ip = event.projectorIp ?? '';

    return EventLogRowFrame(
      // The line's own result is in its icon and text; only the batch row
      // carries a severity edge.
      severity: LogSeverity.info,
      background: cs.onSurface.withValues(alpha: 0.025),
      cells: [
        EventLogTimeCell(formatLogTime(event.timestamp, now), quiet: true),
        EventLogIconCell(
          Icon(icon, size: 16, color: color, semanticLabel: label),
        ),
        SizedBox(
          width: narrow
              ? EventLogColumns.projectorNarrow
              : EventLogColumns.projector,
          height: EventLogColumns.rowHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _indent,
                child: CustomPaint(
                  painter: _TreeLinePainter(
                    color: cs.outline.withValues(alpha: 0.6),
                    last: last,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _indent),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: EventLogIpModel(
                    ip: ip,
                    model: event.projectorName,
                    query: query,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showSource) const SizedBox(width: EventLogColumns.source),
        Expanded(
          child: HighlightedText(
            event.message,
            query: query,
            style: t.body.copyWith(
              color: event.outcome == CommandOutcome.failed
                  ? cs.error
                  : t.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tree line from the batch's chevron down to a projector line: a
/// trunk through the row (half of it on the last line) and an elbow into
/// the line.
class _TreeLinePainter extends CustomPainter {
  _TreeLinePainter({required this.color, required this.last});

  final Color color;
  final bool last;

  // Under the chevron's centre (16 px icon).
  static const double _x = 8;
  static const double _radius = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final mid = size.height / 2;
    final elbow = Path()
      ..moveTo(_x, 0)
      ..lineTo(_x, mid - _radius)
      ..quadraticBezierTo(_x, mid, _x + _radius, mid)
      ..lineTo(_x + 12, mid);
    canvas.drawPath(elbow, paint);
    if (!last) {
      canvas.drawLine(
        Offset(_x, mid - _radius),
        Offset(_x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TreeLinePainter old) =>
      old.color != color || old.last != last;
}
