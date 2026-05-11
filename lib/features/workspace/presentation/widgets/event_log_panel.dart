import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/log_event.dart';
import 'custom_tooltip.dart';
import '../providers/app_settings_provider.dart';
import '../providers/event_log_provider.dart';

enum _LogFilter { all, errors, commands, connectivity, osc }

class EventLogPanel extends ConsumerStatefulWidget {
  const EventLogPanel({super.key, required this.maxHeight});

  final double maxHeight;

  static const double minHeight = 100.0;
  static const double defaultHeight = 240.0;

  @override
  ConsumerState<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends ConsumerState<EventLogPanel> {
  _LogFilter _activeFilter = _LogFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late double _height;

  @override
  void initState() {
    super.initState();
    _height = EventLogPanel.defaultHeight.clamp(
      EventLogPanel.minHeight,
      widget.maxHeight,
    );
  }

  @override
  void didUpdateWidget(EventLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_height > widget.maxHeight) {
      setState(() => _height = widget.maxHeight);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _matchesTypeFilter(LogEvent e, _LogFilter f) => switch (f) {
        _LogFilter.all => true,
        _LogFilter.errors =>
          e.severity == LogSeverity.error || e.severity == LogSeverity.warning,
        _LogFilter.commands => e.type == LogEventType.command,
        _LogFilter.connectivity => e.type == LogEventType.connectivity,
        _LogFilter.osc => e.type == LogEventType.osc,
      };

  List<LogEvent> _filterEvents(List<LogEvent> events) {
    return events.where((e) {
      if (!_matchesTypeFilter(e, _activeFilter)) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (e.projectorIp?.toLowerCase().contains(q) ?? false) ||
          (e.projectorName?.toLowerCase().contains(q) ?? false) ||
          e.message.toLowerCase().contains(q);
    }).toList();
  }

  int _countForFilter(List<LogEvent> events, _LogFilter f) =>
      events.where((e) => _matchesTypeFilter(e, f)).length;

  static String _filterLabel(_LogFilter f) => switch (f) {
        _LogFilter.all => 'All',
        _LogFilter.errors => 'Errors',
        _LogFilter.commands => 'Commands',
        _LogFilter.connectivity => 'Connectivity',
        _LogFilter.osc => 'OSC',
      };

  void _copyToClipboard(List<LogEvent> events, BuildContext context) {
    final buf = StringBuffer();
    for (final e in events) {
      final h = e.timestamp.hour.toString().padLeft(2, '0');
      final m = e.timestamp.minute.toString().padLeft(2, '0');
      final s = e.timestamp.second.toString().padLeft(2, '0');
      final ip = e.projectorIp ?? '–';
      final name = e.projectorName != null ? ' (${e.projectorName})' : '';
      buf.writeln('[$h:$m:$s] [${e.severity.name.toUpperCase()}] [$ip]$name ${e.message}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${events.length} ${events.length == 1 ? 'event' : 'events'} copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(eventLogProvider);
    final filtered = _filterEvents(allEvents);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: _height,
      child: Column(
        children: [
          // ── Resize handle ─────────────────────────────────────────────
          GestureDetector(
            onVerticalDragUpdate: (d) {
              setState(() {
                _height = (_height - d.delta.dy).clamp(
                  EventLogPanel.minHeight,
                  widget.maxHeight,
                );
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: Container(
                height: 6,
                color: cs.surfaceContainerHighest,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Filter / toolbar bar ──────────────────────────────────────
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  'EVENT LOG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                // Filter tabs
                for (final f in _LogFilter.values)
                  _FilterTab(
                    label: _filterLabel(f),
                    count: _countForFilter(allEvents, f),
                    active: _activeFilter == f,
                    onTap: () => setState(() => _activeFilter = f),
                  ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 160,
                  height: 22,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.fromLTRB(28, 0, 8, 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide:
                            BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide:
                            BorderSide(color: cs.primary, width: 1.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 28, minHeight: 22),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 2),
                _IconBtn(
                  icon: Icons.copy_outlined,
                  tooltip: 'Copy visible events to clipboard',
                  onPressed:
                      filtered.isEmpty ? null : () => _copyToClipboard(filtered, context),
                ),
                _IconBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Clear all events',
                  onPressed: allEvents.isEmpty
                      ? null
                      : () => ref.read(eventLogProvider.notifier).clear(),
                ),
                _IconBtn(
                  icon: Icons.close,
                  tooltip: 'Close log panel',
                  onPressed: () =>
                      ref.read(appSettingsProvider.notifier).setShowLogs(false),
                ),
              ],
            ),
          ),

          // ── Log list ──────────────────────────────────────────────────
          Expanded(
            child: ColoredBox(
              color: cs.surface,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        allEvents.isEmpty
                            ? 'No events yet'
                            : 'No events match current filter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemExtent: 26,
                      itemBuilder: (ctx, i) => _LogRow(event: filtered[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter tab ────────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          count > 0 ? '$label  $count' : label,
          style: TextStyle(
            fontSize: 11,
            color: active
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.55),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Compact icon button ───────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 14),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    );
  }
}

// ── Log row ───────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final LogEvent event;

  const _LogRow({required this.event});

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  static Color _severityColor(LogSeverity s) => switch (s) {
        LogSeverity.error => const Color(0xFFEF5350),
        LogSeverity.warning => const Color(0xFFFFB300),
        LogSeverity.info => const Color(0xFF42A5F5),
        LogSeverity.success => const Color(0xFF66BB6A),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurface.withValues(alpha: 0.45);
    final color = _severityColor(event.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Timestamp
          SizedBox(
            width: 60,
            child: Text(
              _formatTime(event.timestamp),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: dim,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Severity dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          // IP address
          SizedBox(
            width: 106,
            child: Text(
              event.projectorIp ?? '–',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Name (dimmed)
          SizedBox(
            width: 110,
            child: Text(
              event.projectorName ?? '–',
              style: TextStyle(fontSize: 11, color: dim),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              event.message,
              style: TextStyle(
                fontSize: 11,
                color: event.severity == LogSeverity.error
                    ? color.withValues(alpha: 0.9)
                    : cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
