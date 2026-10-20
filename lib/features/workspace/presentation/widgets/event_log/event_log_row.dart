import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/event_log_view.dart';
import '../../../domain/log_event.dart';
import '../common/dialog_parts.dart';
import 'event_log_row_actions.dart';

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

/// The frame every row of the log shares: the bottom hairline and, for an
/// error or warning, a faint tint and a 3 px edge in its colour. [cells]
/// are laid out in the columns; [actions] show on hover over the row's
/// right end, so they never move a column.
class EventLogRowFrame extends StatefulWidget {
  const EventLogRowFrame({
    super.key,
    required this.severity,
    required this.cells,
    this.background,
    this.actions = const [],
  });

  final LogSeverity severity;
  final List<Widget> cells;

  /// The fill when the severity gives none (a batch's projector lines).
  final Color? background;

  /// The hover actions (*Locate*, *Open alerts*, *Copy row*, …).
  final List<Widget> actions;

  @override
  State<EventLogRowFrame> createState() => _EventLogRowFrameState();
}

class _EventLogRowFrameState extends State<EventLogRowFrame> {
  bool _hover = false;

  void _setHover(bool hover) {
    if (_hover != hover) setState(() => _hover = hover);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final severity = widget.severity;
    final edge = switch (severity) {
      LogSeverity.error => cs.error,
      LogSeverity.warning => sc.warning,
      _ => null,
    };
    final overlay = _hover && widget.actions.isNotEmpty
        ? EventLogRowActions(children: widget.actions)
        : null;
    final frame = Container(
      decoration: BoxDecoration(
        color:
            edge?.withValues(
              alpha: severity == LogSeverity.error ? 0.07 : 0.06,
            ) ??
            widget.background,
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
            child: Row(children: widget.cells),
          ),
          if (overlay != null)
            Positioned(
              right: EventLogColumns.sidePadding - 6,
              top: 0,
              bottom: 0,
              child: Center(child: overlay),
            ),
        ],
      ),
    );
    if (widget.actions.isEmpty) return frame;
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: frame,
    );
  }
}

/// A soft neutral pill after the message: a repeat's *14 times, last
/// 21:02:41*, a lens run's *8 steps, last 16:39:17*.
class EventLogCountPill extends StatelessWidget {
  const EventLogCountPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: t.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: t.secondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
      ),
    );
  }
}

/// The Time column.
class EventLogTimeCell extends StatelessWidget {
  const EventLogTimeCell(this.text, {super.key, this.quiet = false});

  final String text;

  /// In the tertiary colour, as a batch's projector lines show it.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      width: EventLogColumns.time,
      child: Text(
        text,
        style: quiet ? t.monoSmall.copyWith(color: t.tertiary) : t.monoSmall,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
      ),
    );
  }
}

/// The narrow column of the severity icon.
class EventLogIconCell extends StatelessWidget {
  const EventLogIconCell(this.icon, {super.key});

  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: EventLogColumns.severity,
    child: Align(alignment: Alignment.centerLeft, child: icon),
  );
}

/// IP and model on one baseline: the mono IP is taller than the model, and
/// centred the model sat higher.
class EventLogIpModel extends StatelessWidget {
  const EventLogIpModel({
    super.key,
    required this.ip,
    required this.model,
    required this.query,
  });

  final String ip;
  final String? model;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final model = this.model;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        HighlightedText(ip, query: query, style: t.mono),
        if (model != null && model.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: HighlightedText(model, query: query, style: t.description),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }
}

/// The Source column: the event type's icon and word.
class EventLogSourceCell extends StatelessWidget {
  const EventLogSourceCell(this.type, {super.key});

  final LogEventType type;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      width: EventLogColumns.source,
      child: Row(
        children: [
          Icon(logSourceIcon(type), size: 16, color: t.secondary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              logSourceLabel(type),
              style: t.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A command's name and, after it in `description`, where it came from
/// (*from the control bar*).
class EventLogCommandText extends StatelessWidget {
  const EventLogCommandText({
    super.key,
    required this.message,
    required this.source,
    required this.query,
  });

  final String message;
  final CommandSource? source;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final source = this.source;
    // Its own width, so the pills after it follow the text.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: HighlightedText(message, query: query, style: t.body),
        ),
        if (source != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: HighlightedText(
              source.label,
              query: query,
              style: t.description,
            ),
          ),
        ],
      ],
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
    this.message,
    this.countText,
    this.pills = const [],
    this.actions = const [],
  });

  final LogEvent event;
  final DateTime now;
  final String query;
  final bool showSource;
  final bool narrow;

  /// Shown instead of the event's message (a lens run's *Lens Shift*).
  final String? message;

  /// A folded row's soft pill: *14 times, last 21:02:41*.
  final String? countText;

  /// Pills after the count (a lens run's outcomes).
  final List<Widget> pills;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final ip = event.projectorIp;
    final model = event.projectorName;
    final message = this.message ?? event.message;
    final sender = event.oscSender;
    final countText = this.countText;

    return EventLogRowFrame(
      severity: event.severity,
      actions: actions,
      cells: [
        EventLogTimeCell(formatLogTime(event.timestamp, now)),
        EventLogIconCell(EventLogSeverityIcon(event.severity)),
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
              : EventLogIpModel(ip: ip, model: model, query: query),
        ),
        if (showSource) EventLogSourceCell(event.type),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: event.source != null
                    ? EventLogCommandText(
                        message: message,
                        source: event.source,
                        query: query,
                      )
                    : sender != null
                    ? EventLogOscText(
                        address: message,
                        sender: sender,
                        query: query,
                      )
                    : HighlightedText(message, query: query, style: t.body),
              ),
              if (countText != null) ...[
                const SizedBox(width: 8),
                EventLogCountPill(countText),
              ],
              for (final p in pills) ...[const SizedBox(width: 8), p],
            ],
          ),
        ),
      ],
    );
  }
}

/// An OSC address line: the address in mono and who sent it
/// (*from 10.0.0.20*) in `description`.
class EventLogOscText extends StatelessWidget {
  const EventLogOscText({
    super.key,
    required this.address,
    required this.sender,
    required this.query,
  });

  final String address;
  final String sender;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: HighlightedText(address, query: query, style: t.mono),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: HighlightedText(
            oscSenderLabel(sender),
            query: query,
            style: t.description,
          ),
        ),
      ],
    );
  }
}

/// The severity of an event as an icon: red error, amber warning, green
/// success, grey info.
class EventLogSeverityIcon extends StatelessWidget {
  const EventLogSeverityIcon(this.severity, {super.key});

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
