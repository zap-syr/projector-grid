import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/event_log_rows.dart';
import '../../../domain/event_log_view.dart';
import '../../../domain/log_event.dart';
import '../common/status_pill.dart';
import 'event_log_row.dart';

/// A row that opens to projector lines under it: a chevron, the target
/// (`Stage, 6 projectors`) and [event] in the Event column. A click on
/// the row or the chevron opens or closes it.
class EventLogFoldRow extends StatelessWidget {
  const EventLogFoldRow({
    super.key,
    required this.severity,
    required this.timestamp,
    required this.type,
    required this.target,
    required this.event,
    required this.open,
    required this.onToggle,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final LogSeverity severity;
  final DateTime timestamp;
  final LogEventType type;
  final String target;
  final Widget event;
  final bool open;
  final VoidCallback onToggle;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: EventLogRowFrame(
          severity: severity,
          actions: actions,
          cells: [
            EventLogTimeCell(formatLogTime(timestamp, now)),
            EventLogIconCell(EventLogSeverityIcon(severity)),
            SizedBox(
              width: narrow
                  ? EventLogColumns.projectorNarrow
                  : EventLogColumns.projector,
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_more : Icons.chevron_right,
                    key: const ValueKey('event-log-batch-chevron'),
                    size: 16,
                    color: t.secondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: HighlightedText(
                      target,
                      query: query,
                      style: t.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            if (showSource) EventLogSourceCell(type),
            Expanded(child: event),
          ],
        ),
      ),
    );
  }
}

/// The outcome pills of a command row, in their status colours.
class EventLogOutcomePills extends StatelessWidget {
  const EventLogOutcomePills(this.pills, {super.key});

  final List<(CommandOutcome, String)> pills;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final t = AppText.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final (outcome, label) in pills)
          StatusPill(
            label: label,
            color: switch (outcome) {
              CommandOutcome.sent => sc.success,
              CommandOutcome.failed => cs.error,
              CommandOutcome.skipped => t.secondary,
            },
          ),
      ],
    );
  }
}

/// A command and where it came from, then its pills, the pills following
/// the text.
class _CommandWithPills extends StatelessWidget {
  const _CommandWithPills({
    required this.message,
    required this.source,
    required this.query,
    this.countText,
    required this.pills,
  });

  final String message;
  final CommandSource? source;
  final String query;
  final String? countText;
  final List<(CommandOutcome, String)> pills;

  @override
  Widget build(BuildContext context) {
    final countText = this.countText;
    return Row(
      children: [
        Flexible(
          child: EventLogCommandText(
            message: message,
            source: source,
            query: query,
          ),
        ),
        if (countText != null) ...[
          const SizedBox(width: 8),
          EventLogCountPill(countText),
        ],
        if (pills.isNotEmpty) ...[
          const SizedBox(width: 8),
          EventLogOutcomePills(pills),
        ],
      ],
    );
  }
}

/// A command sent to several projectors (plan §7k.3): the target, the
/// command with where it came from and the result as pills. Opened, it
/// lists the projector lines.
class EventLogBatchRow extends StatelessWidget {
  const EventLogBatchRow({
    super.key,
    required this.row,
    required this.open,
    required this.onToggle,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final BatchLogRow row;
  final bool open;
  final VoidCallback onToggle;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => EventLogFoldRow(
    severity: row.severity,
    timestamp: row.timestamp,
    type: LogEventType.command,
    target: row.batch.target,
    open: open,
    onToggle: onToggle,
    now: now,
    query: query,
    showSource: showSource,
    narrow: narrow,
    actions: actions,
    event: _CommandWithPills(
      message: row.commandName,
      source: row.source,
      query: query,
      pills: batchPills(row),
    ),
  );
}

/// The same kind of event from several projectors at once (plan §7k.2):
/// *20 projectors*, *Came online*. Opened, each projector with its own
/// text.
class EventLogGroupRow extends StatelessWidget {
  const EventLogGroupRow({
    super.key,
    required this.row,
    required this.open,
    required this.onToggle,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final GroupLogRow row;
  final bool open;
  final VoidCallback onToggle;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => EventLogFoldRow(
    severity: row.severity,
    timestamp: row.timestamp,
    type: row.type,
    target: row.target,
    open: open,
    onToggle: onToggle,
    now: now,
    query: query,
    showSource: showSource,
    narrow: narrow,
    actions: actions,
    event: HighlightedText(
      row.kind.title,
      query: query,
      style: AppText.of(context).body,
    ),
  );
}

/// Lens Shift steps folded into one row (plan §7k.2): *Lens Shift from
/// the control bar*, *8 steps, last 16:39:17*. To several projectors it
/// opens like a batch, each projector once with its totals.
class EventLogLensRunRow extends StatelessWidget {
  const EventLogLensRunRow({
    super.key,
    required this.row,
    required this.open,
    required this.onToggle,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final LensRunLogRow row;
  final bool open;
  final VoidCallback onToggle;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final count = lensRunCountText(row, now);
    final single = row.single;
    if (single != null) {
      return EventLogRow(
        event: single,
        now: now,
        query: query,
        showSource: showSource,
        narrow: narrow,
        message: lensRunTitle,
        countText: count,
        pills: [
          if (lensRunPills(row) case final pills when pills.isNotEmpty)
            EventLogOutcomePills(pills),
        ],
        actions: actions,
      );
    }
    return EventLogFoldRow(
      severity: row.severity,
      timestamp: row.timestamp,
      type: LogEventType.command,
      target: row.batchTarget!,
      open: open,
      onToggle: onToggle,
      now: now,
      query: query,
      showSource: showSource,
      narrow: narrow,
      actions: actions,
      event: _CommandWithPills(
        message: lensRunTitle,
        source: row.source,
        query: query,
        countText: count,
        pills: lensRunPills(row),
      ),
    );
  }
}

/// One projector under an opened row, on a tree line: IP and model, then
/// [icon] and [text].
class EventLogTreeLine extends StatelessWidget {
  const EventLogTreeLine({
    super.key,
    required this.event,
    required this.icon,
    required this.text,
    required this.textColor,
    required this.last,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  /// The projector's line: its IP, model and time.
  final LogEvent event;
  final Widget icon;
  final String text;
  final Color textColor;

  /// The row's last line: the tree line ends here.
  final bool last;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  static const double _indent = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final ip = event.projectorIp ?? '';

    return EventLogRowFrame(
      // The line's own result is in its icon and text; only the row above
      // carries a severity edge.
      severity: LogSeverity.info,
      background: cs.onSurface.withValues(alpha: 0.025),
      actions: actions,
      cells: [
        EventLogTimeCell(formatLogTime(event.timestamp, now), quiet: true),
        EventLogIconCell(icon),
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
            text,
            query: query,
            style: t.body.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}

/// One projector of an open batch: green *Sent*, red *Failed* with the
/// reason or grey *Skipped* with the reason.
class EventLogBatchLine extends StatelessWidget {
  const EventLogBatchLine({
    super.key,
    required this.event,
    required this.last,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final LogEvent event;
  final bool last;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return EventLogTreeLine(
      event: event,
      icon: EventLogOutcomeIcon(event.outcome ?? CommandOutcome.sent),
      text: event.message,
      textColor: event.outcome == CommandOutcome.failed
          ? cs.error
          : t.secondary,
      last: last,
      now: now,
      query: query,
      showSource: showSource,
      narrow: narrow,
      actions: actions,
    );
  }
}

/// One projector of an open group, with its own text (*Back after 3 s*).
class EventLogGroupLine extends StatelessWidget {
  const EventLogGroupLine({
    super.key,
    required this.event,
    required this.last,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final LogEvent event;
  final bool last;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => EventLogTreeLine(
    event: event,
    icon: EventLogSeverityIcon(event.severity),
    text: event.groupDetail ?? event.message,
    textColor: AppText.of(context).secondary,
    last: last,
    now: now,
    query: query,
    showSource: showSource,
    narrow: narrow,
    actions: actions,
  );
}

/// One projector of an open lens run, with its totals (*12 sent, 1
/// failed*).
class EventLogLensLine extends StatelessWidget {
  const EventLogLensLine({
    super.key,
    required this.total,
    required this.last,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
    this.actions = const [],
  });

  final LensRunTotal total;
  final bool last;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return EventLogTreeLine(
      event: total.latest,
      icon: EventLogOutcomeIcon(
        total.failed > 0
            ? CommandOutcome.failed
            : total.sent > 0
            ? CommandOutcome.sent
            : CommandOutcome.skipped,
      ),
      text: lensTotalText(total),
      textColor: total.failed > 0 ? cs.error : t.secondary,
      last: last,
      now: now,
      query: query,
      showSource: showSource,
      narrow: narrow,
      actions: actions,
    );
  }
}

/// A command's result at one projector as an icon.
class EventLogOutcomeIcon extends StatelessWidget {
  const EventLogOutcomeIcon(this.outcome, {super.key});

  final CommandOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final (icon, color, label) = switch (outcome) {
      CommandOutcome.failed => (Icons.error, cs.error, 'Failed'),
      CommandOutcome.skipped => (
        Icons.remove_circle_outline,
        cs.outline,
        'Skipped',
      ),
      CommandOutcome.sent => (Icons.check_circle_outline, sc.success, 'Sent'),
    };
    return Icon(icon, size: 16, color: color, semanticLabel: label);
  }
}

/// The tree line from the row's chevron down to a projector line: a trunk
/// through the row (half of it on the last line) and an elbow into the
/// line.
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
