import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/event_log_view.dart';
import '../../../domain/log_event.dart';

/// Column widths of the log's table, shared by the column header and the
/// rows so they line up.
class EventLogColumns {
  EventLogColumns._();

  static const double rowHeight = 34;
  static const double headerHeight = 24;
  static const double sidePadding = 16;

  /// Wide enough for the dated form (`19 Oct 23:58:04`), so the column
  /// never changes width at midnight.
  static const double time = 128;
  static const double severity = 28;
  static const double projector = 250;
  static const double projectorNarrow = 200;
  static const double source = 140;
}

/// The icon of an event type, used by the Source column and the chips.
IconData logSourceIcon(LogEventType type) => switch (type) {
  LogEventType.command => Icons.terminal,
  LogEventType.osc => Icons.sensors,
  LogEventType.connectivity => Icons.link,
  LogEventType.alert => Icons.notifications_none,
  LogEventType.web => Icons.language,
};

/// *Time*, *Projector*, *Source*, *Event* under the log's header.
class EventLogColumnHeader extends StatelessWidget {
  const EventLogColumnHeader({
    super.key,
    required this.showSource,
    required this.narrow,
  });

  final bool showSource;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = AppText.of(context).label;
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, style: style, maxLines: 1),
    );
    return Container(
      height: EventLogColumns.headerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: EventLogColumns.sidePadding,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          cell('Time', EventLogColumns.time),
          const SizedBox(width: EventLogColumns.severity),
          cell(
            'Projector',
            narrow
                ? EventLogColumns.projectorNarrow
                : EventLogColumns.projector,
          ),
          if (showSource) cell('Source', EventLogColumns.source),
          Expanded(child: Text('Event', style: style, maxLines: 1)),
        ],
      ),
    );
  }
}

/// One event: time, severity icon, projector, source and message. Error
/// and warning rows get a faint tint and a 3 px edge in their colour; the
/// message keeps the primary text colour.
class EventLogRow extends StatelessWidget {
  const EventLogRow({
    super.key,
    required this.event,
    required this.now,
    required this.query,
    required this.showSource,
    required this.narrow,
  });

  final LogEvent event;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final t = AppText.of(context);
    final edge = switch (event.severity) {
      LogSeverity.error => cs.error,
      LogSeverity.warning => sc.warning,
      _ => null,
    };
    final ip = event.projectorIp;
    final model = event.projectorName;

    return Container(
      decoration: BoxDecoration(
        color: edge?.withValues(
          alpha: event.severity == LogSeverity.error ? 0.07 : 0.06,
        ),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Stack(
        children: [
          if (edge != null)
            Positioned(
              left: 0,
              top: 5,
              bottom: 5,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: edge,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EventLogColumns.sidePadding,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: EventLogColumns.time,
                  child: Text(
                    formatLogTime(event.timestamp, now),
                    style: t.monoSmall,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                  ),
                ),
                SizedBox(
                  width: EventLogColumns.severity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SeverityIcon(event.severity),
                  ),
                ),
                SizedBox(
                  width: narrow
                      ? EventLogColumns.projectorNarrow
                      : EventLogColumns.projector,
                  child: ip == null
                      ? Text(
                          model ?? 'App',
                          style: t.description.copyWith(color: t.tertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      // On one baseline: the mono IP is taller than the
                      // model, and centred the model sat higher.
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            HighlightedText(ip, query: query, style: t.mono),
                            if (model != null && model.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: HighlightedText(
                                  model,
                                  query: query,
                                  style: t.description,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                          ],
                        ),
                ),
                if (showSource)
                  SizedBox(
                    width: EventLogColumns.source,
                    child: Row(
                      children: [
                        Icon(
                          logSourceIcon(event.type),
                          size: 16,
                          color: t.secondary,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            logSourceLabel(event.type),
                            style: t.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: HighlightedText(
                    event.message,
                    query: query,
                    style: t.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon(this.severity);

  final LogSeverity severity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final (icon, color, label) = switch (severity) {
      LogSeverity.error => (Icons.error, cs.error, 'Error'),
      LogSeverity.warning => (Icons.warning_rounded, sc.warning, 'Warning'),
      LogSeverity.success => (
        Icons.check_circle_outline,
        sc.success,
        'Success',
      ),
      LogSeverity.info => (Icons.info_outline, cs.outline, 'Info'),
    };
    return Icon(icon, size: 16, color: color, semanticLabel: label);
  }
}

/// [text] on one line with every occurrence of [query] highlighted.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final ranges = searchMatchRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final mark = style.copyWith(
      backgroundColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: 0.22),
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: mark));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
