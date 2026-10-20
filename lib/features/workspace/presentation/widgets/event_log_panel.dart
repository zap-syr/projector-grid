import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/event_log_view.dart';
import '../providers/app_settings_provider.dart';
import '../providers/event_log_provider.dart';
import '../providers/event_log_request_provider.dart';
import 'common/confirm_dialog.dart';
import 'common/dialog_parts.dart';
import 'event_log/event_log_header.dart';
import 'event_log/event_log_row.dart';

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
    _filter = request.alertsOnly ? EventLogFilter.alerts : EventLogFilter.all;
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
    setState(() => _query = query);
  }

  void _showAll() {
    _searchController.text = '';
    setState(() {
      _query = '';
      _filter = EventLogFilter.all;
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
    final rows = visibleEvents(allEvents, _filter, _query);
    final counts = eventFilterCounts(allEvents);
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
                  copiedCount: _copiedCount,
                  onCopy: rows.isEmpty
                      ? null
                      : () => _copy(rows.length, logCopyText(rows, now)),
                  onClear: allEvents.isEmpty
                      ? null
                      : () => _confirmClear(allEvents.length),
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
                              child: ListView.builder(
                                itemCount: rows.length,
                                itemExtent: EventLogColumns.rowHeight,
                                itemBuilder: (_, i) => EventLogRow(
                                  event: rows[i],
                                  now: now,
                                  query: _query,
                                  showSource: showSource,
                                  narrow: narrow,
                                ),
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
