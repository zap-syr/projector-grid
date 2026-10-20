import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/event_log_rows.dart';
import '../../domain/event_log_view.dart';
import '../../domain/log_event.dart';
import '../providers/app_settings_provider.dart';
import '../providers/event_log_provider.dart';
import '../providers/event_log_request_provider.dart';
import '../providers/workspace_provider.dart';
import 'common/confirm_dialog.dart';
import 'common/dialog_parts.dart';
import 'event_log/event_log_batch_row.dart';
import 'event_log/event_log_header.dart';
import 'event_log/event_log_row.dart';
import 'event_log/event_log_row_actions.dart';

/// The event log, docked under the views (plan §7k): a grip, the header
/// with the filter chips and search, the column header and the rows.
class EventLogPanel extends ConsumerStatefulWidget {
  const EventLogPanel({super.key, required this.maxHeight});

  /// The most the panel may take: the window minus the room kept for the
  /// view above it.
  final double maxHeight;

  static const double gripHeight = 6;

  /// The grip, the header, the column header and one row.
  static const double minHeight = 120.0;

  @override
  ConsumerState<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends ConsumerState<EventLogPanel> {
  EventLogFilter _filter = EventLogFilter.all;
  final _searchController = TextEditingController();
  late final _searchFocus = FocusNode(
    debugLabel: 'event-log-search',
    onKeyEvent: _onSearchKey,
  );
  String _query = '';

  /// The height while the grip is dragged; null otherwise, when the saved
  /// height is shown.
  double? _dragHeight;
  bool? _narrow;

  int? _copiedCount;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    // The panel is often built by the very request that opened it.
    if (ref.read(eventLogRequestProvider) case final request?) {
      _apply(request);
      // A provider can't change while the tree is building.
      Future.microtask(ref.read(eventLogRequestProvider.notifier).handled);
    }
  }

  void _apply(EventLogRequest request) {
    _searchController.text = request.query;
    _query = request.query;
    _dropSearchCloses();
    _filter = request.alertsOnly ? EventLogFilter.alerts : EventLogFilter.all;
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  final _scroll = ScrollController();

  /// Follow (plan §7k.4): on, the list stays at the newest event (the
  /// top). Scrolling down turns it off and holds the list as it was in
  /// [_frozen], so new events wait in a pill instead of moving the rows
  /// under the reader; scrolling back to the top turns it on again.
  bool _follow = true;
  List<LogEvent>? _frozen;

  final _liveRows = _RowsMemo();
  final _frozenRows = _RowsMemo();

  void _stopFollowing() => setState(() {
    _follow = false;
    _frozen = ref.read(eventLogProvider);
  });

  /// Back to the newest event, following again.
  void _followNow() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _resumeFollowing();
  }

  void _resumeFollowing() => setState(() {
    _follow = true;
    _frozen = null;
  });

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.depth != 0) return false;
    if (_follow && n.metrics.pixels > 0) {
      _stopFollowing();
    } else if (!_follow && n.metrics.pixels <= n.metrics.minScrollExtent) {
      // Scrolled back to the top: the reader is looking at the newest
      // again, so the held rows give way to the live ones (owner,
      // 2026-10-20), as the pill or the button would. No jump: the list is
      // already there, and a jump mid-drag would cut the drag off.
      _resumeFollowing();
    }
    return false;
  }

  /// The rows shown under [_filter] and [_query] that came in since the
  /// list was held: the *N new events* pill.
  int _newRowCount(List<LogEvent> live, List<LogRow> liveRows) {
    final frozen = _frozen!;
    var since = frozen.isEmpty
        ? live.length
        : live.indexWhere((e) => identical(e, frozen.first));
    if (since < 0) since = live.length;
    if (since == 0) return 0;
    final fresh = Set<LogEvent>.identity()..addAll(live.take(since));
    return visibleRows(
      liveRows,
      _filter,
      _query,
    ).where((r) => r.events.any(fresh.contains)).length;
  }

  /// Esc empties a search; on an empty one it goes on up.
  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        _searchController.text.isEmpty) {
      return KeyEventResult.ignored;
    }
    _setQuery('');
    return KeyEventResult.handled;
  }

  void _setQuery(String query) {
    if (_searchController.text != query) _searchController.text = query;
    setState(() {
      _query = query;
      _dropSearchCloses();
    });
  }

  /// Rows opened or closed by a click, by [rowOpenKey]. A row without an
  /// entry is open while the search matches one of its projector lines.
  final Map<String, bool> _openOverride = {};

  bool _isOpen(LogRow row) =>
      rowOpens(row) &&
      (_openOverride[rowOpenKey(row)] ?? rowOpenedBySearch(row, _query));

  void _toggle(LogRow row) =>
      setState(() => _openOverride[rowOpenKey(row)!] = !_isOpen(row));

  /// A row closed against the search stays closed only for that search; a
  /// row opened by hand stays open.
  void _dropSearchCloses() => _openOverride.removeWhere((_, open) => !open);

  void _retry(BatchLogRow row) => ref
      .read(workspaceProvider.notifier)
      .retryFailed(row.failedNodeIds, row.batch.command);

  void _showAll() {
    _searchController.text = '';
    setState(() {
      _query = '';
      _filter = EventLogFilter.all;
      _dropSearchCloses();
    });
  }

  /// Copies [text] ([count] rows); the button shows a check for a second
  /// instead of a SnackBar.
  void _copy(int count, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _copiedTimer?.cancel();
    setState(() => _copiedCount = count);
    _copiedTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copiedCount = null);
    });
  }

  Future<void> _confirmClear(int count) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Clear the event log?',
      subtitle: count == 1
          ? 'The event is removed. Copy it first if you need it.'
          : 'All $count events are removed. Copy them first if you need them.',
      confirmLabel: 'Clear',
    );
    if (confirmed) ref.read(eventLogProvider.notifier).clear();
  }

  /// The lines an open [row] lists under it.
  List<_ListItem> _linesOf(LogRow row) {
    final lines = switch (row) {
      BatchLogRow(:final lines) => [
        for (final l in lines) (last) => _BatchLineItem(l, last: last),
      ],
      GroupLogRow(:final lines) => [
        for (final m in lines) (last) => _GroupLineItem(m, last: last),
      ],
      LensRunLogRow() => [
        for (final t in row.totals) (last) => _LensLineItem(t, last: last),
      ],
      _ => <_ListItem Function(bool)>[],
    };
    return [for (final (i, l) in lines.indexed) l(i == lines.length - 1)];
  }

  /// The hover actions of a row or line: *Retry failed* on a batch with
  /// failures, *Open alerts* on alert rows, *Locate* where there is one
  /// projector, *Copy row*.
  List<Widget> _actions({
    String? ip,
    bool alert = false,
    VoidCallback? retry,
    String Function()? copy,
  }) => [
    if (retry != null)
      EventLogTextAction(
        key: const ValueKey('event-log-retry-failed'),
        label: 'Retry failed',
        onPressed: retry,
      ),
    if (alert) const EventLogOpenAlertsButton(),
    if (ip != null) EventLogLocateButton(ip: ip),
    if (copy != null) EventLogCopyRowButton(text: copy),
  ];

  Widget _buildItem(
    _ListItem item, {
    required DateTime now,
    required bool showSource,
    required bool narrow,
  }) {
    String Function() copyOf(LogRow row) =>
        () => logRowCopyText(row, DateTime.now());
    return switch (item) {
      _RowItem(row: final SingleLogRow row) => EventLogRow(
        event: row.event,
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(
          ip: row.event.projectorIp,
          alert: row.type == LogEventType.alert,
          copy: copyOf(row),
        ),
      ),
      _RowItem(row: final RepeatLogRow row) => EventLogRow(
        event: row.latest,
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        countText: repeatCountText(row, now),
        actions: _actions(
          ip: row.latest.projectorIp,
          alert: row.type == LogEventType.alert,
          copy: copyOf(row),
        ),
      ),
      _RowItem(row: final BatchLogRow row) => EventLogBatchRow(
        key: ValueKey('event-log-batch-${row.batch.id}'),
        row: row,
        open: _isOpen(row),
        onToggle: () => _toggle(row),
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        // Only once every reply is in: retrying mid-flight would send
        // twice to a projector whose answer is still on its way.
        actions: _actions(
          retry: row.done && row.failed > 0 ? () => _retry(row) : null,
          copy: copyOf(row),
        ),
      ),
      _RowItem(row: final GroupLogRow row) => EventLogGroupRow(
        row: row,
        open: _isOpen(row),
        onToggle: () => _toggle(row),
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(
          alert: row.type == LogEventType.alert,
          copy: copyOf(row),
        ),
      ),
      _RowItem(row: final LensRunLogRow row) => EventLogLensRunRow(
        row: row,
        open: _isOpen(row),
        onToggle: () => _toggle(row),
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(ip: row.single?.projectorIp, copy: copyOf(row)),
      ),
      _BatchLineItem(:final event, :final last) => EventLogBatchLine(
        event: event,
        last: last,
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(
          ip: event.projectorIp,
          copy: () => logCopyLine(event, DateTime.now()),
        ),
      ),
      _GroupLineItem(:final event, :final last) => EventLogGroupLine(
        event: event,
        last: last,
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(
          ip: event.projectorIp,
          copy: () => logCopyLine(event, DateTime.now()),
        ),
      ),
      _LensLineItem(:final total, :final last) => EventLogLensLine(
        total: total,
        last: last,
        now: now,
        query: _query,
        showSource: showSource,
        narrow: narrow,
        actions: _actions(ip: total.latest.projectorIp),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(eventLogRequestProvider, (_, request) {
      if (request == null) return;
      setState(() => _apply(request));
      ref.read(eventLogRequestProvider.notifier).handled();
    });
    final savedHeight = ref.watch(
      appSettingsProvider.select((s) => s.eventLogHeight),
    );
    final allEvents = ref.watch(eventLogProvider);
    if (allEvents.isEmpty) {
      // Cleared: nothing is held any more.
      _follow = true;
      _frozen = null;
    }
    final allRows = _liveRows.of(allEvents);
    final frozen = _frozen;
    final shownRows = frozen == null ? allRows : _frozenRows.of(frozen);
    final rows = visibleRows(shownRows, _filter, _query);
    final counts = rowFilterCounts(allRows);
    final newRows = frozen == null ? 0 : _newRowCount(allEvents, allRows);
    final items = <_ListItem>[
      for (final r in rows) ...[_RowItem(r), if (_isOpen(r)) ..._linesOf(r)],
    ];
    final now = DateTime.now();
    final cs = Theme.of(context).colorScheme;
    final height = eventLogPanelHeight(
      _dragHeight ?? savedHeight,
      min: EventLogPanel.minHeight,
      max: widget.maxHeight,
    );

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final narrow = _narrow = eventLogNarrow(width, wasNarrow: _narrow);
          final showSource = width >= eventLogSourceColumnBelow;
          return ColoredBox(
            color: cs.surface,
            child: Column(
              children: [
                _Grip(
                  onStart: () => _dragHeight = height,
                  onDrag: (dy) => setState(() {
                    _dragHeight = eventLogPanelHeight(
                      (_dragHeight ?? height) - dy,
                      min: EventLogPanel.minHeight,
                      max: widget.maxHeight,
                    );
                  }),
                  onEnd: () {
                    final h = _dragHeight;
                    if (h == null) return;
                    ref.read(appSettingsProvider.notifier).setEventLogHeight(h);
                    setState(() => _dragHeight = null);
                  },
                ),
                EventLogHeader(
                  narrow: narrow,
                  filter: _filter,
                  counts: counts,
                  onFilter: (f) => setState(() => _filter = f),
                  search: _searchController,
                  searchFocus: _searchFocus,
                  onSearch: _setQuery,
                  follow: _follow,
                  onFollow: _followNow,
                  copiedCount: _copiedCount,
                  onCopy: rows.isEmpty
                      ? null
                      : () => _copy(rows.length, logCopyText(rows, now)),
                  onClear: allEvents.isEmpty
                      ? null
                      : () => _confirmClear(allRows.length),
                  onClose: () =>
                      ref.read(appSettingsProvider.notifier).setShowLogs(false),
                ),
                Expanded(
                  child: allEvents.isEmpty
                      ? const _EmptyState()
                      : rows.isEmpty
                      ? _NoMatchState(
                          description: noMatchDescription(_filter, _query),
                          onShowAll: _showAll,
                        )
                      : Column(
                          children: [
                            EventLogColumnHeader(
                              showSource: showSource,
                              narrow: narrow,
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  NotificationListener<
                                    ScrollUpdateNotification
                                  >(
                                    onNotification: _onScroll,
                                    child: ListView.builder(
                                      key: const ValueKey('event-log-list'),
                                      controller: _scroll,
                                      itemCount: items.length,
                                      itemExtent: EventLogColumns.rowHeight,
                                      itemBuilder: (_, i) => _buildItem(
                                        items[i],
                                        now: now,
                                        showSource: showSource,
                                        narrow: narrow,
                                      ),
                                    ),
                                  ),
                                  if (newRows > 0)
                                    Positioned(
                                      top: 8,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: _NewEventsPill(
                                          count: newRows,
                                          onPressed: _followNow,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One line of the list: a row, or a projector line of an open row.
sealed class _ListItem {
  const _ListItem();
}

class _RowItem extends _ListItem {
  const _RowItem(this.row);

  final LogRow row;
}

class _BatchLineItem extends _ListItem {
  const _BatchLineItem(this.event, {required this.last});

  final LogEvent event;
  final bool last;
}

class _GroupLineItem extends _ListItem {
  const _GroupLineItem(this.event, {required this.last});

  final LogEvent event;
  final bool last;
}

class _LensLineItem extends _ListItem {
  const _LensLineItem(this.total, {required this.last});

  final LensRunTotal total;
  final bool last;
}

/// The rows of the last event list it was given: the panel rebuilds on
/// hover, copy and search changes that don't change the events.
class _RowsMemo {
  List<LogEvent>? _events;
  List<LogRow> _rows = const [];

  List<LogRow> of(List<LogEvent> events) {
    if (!identical(events, _events)) {
      _events = events;
      _rows = buildLogRows(events);
    }
    return _rows;
  }
}

/// *5 new events* at the top of the list while Follow is off; a click goes
/// back to the newest event and follows again.
class _NewEventsPill extends StatelessWidget {
  const _NewEventsPill({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Material(
      key: const ValueKey('event-log-new-events'),
      color: cs.primaryContainer,
      elevation: 6,
      shape: StadiumBorder(
        side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Container(
          height: 32,
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(Icons.arrow_upward, size: 16, color: cs.onPrimaryContainer),
              Text(
                '$count new ${count == 1 ? 'event' : 'events'}',
                style: t.description.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The resize handle on top of the panel.
class _Grip extends StatelessWidget {
  const _Grip({
    required this.onStart,
    required this.onDrag,
    required this.onEnd,
  });

  final VoidCallback onStart;
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey('event-log-grip'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onStart(),
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => onEnd(),
      onVerticalDragCancel: onEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: EventLogPanel.gripHeight,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred in whatever height the panel has; scrolls rather than
/// overflowing at the minimum height.
class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return _CenteredState(
      children: [
        const DialogIconTile(Icons.format_list_bulleted),
        const SizedBox(height: 10),
        Text(
          'No events yet',
          style: t.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Commands, connection changes, OSC and alerts appear here as '
          'they happen',
          style: t.description,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.description, required this.onShowAll});

  final String description;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return _CenteredState(
      children: [
        Text(
          'No events match',
          style: t.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(description, style: t.description, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        TextButton(onPressed: onShowAll, child: const Text('Show all')),
      ],
    );
  }
}
