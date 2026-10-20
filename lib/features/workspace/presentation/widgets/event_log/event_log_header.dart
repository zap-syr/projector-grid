import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/event_log_view.dart';
import '../../../domain/log_event.dart';
import '../common/bar_chip.dart';
import '../common/dialog_parts.dart';
import '../custom_tooltip.dart';
import 'event_log_row.dart';

/// The log's 56 px header (plan §7k.1): icon tile and title, the filter
/// chips, *Search log*, then Follow, Copy, Clear and Close. [narrow] drops the
/// title text, steps the chips down to icon and count and narrows the
/// search; nothing is dropped.
class EventLogHeader extends StatelessWidget {
  const EventLogHeader({
    super.key,
    required this.narrow,
    required this.filter,
    required this.counts,
    required this.onFilter,
    required this.search,
    required this.searchFocus,
    required this.onSearch,
    required this.follow,
    required this.onFollow,
    required this.copiedCount,
    required this.onCopy,
    required this.onClear,
    required this.onClose,
  });

  /// The search's widest: in the full header 36 px less than before
  /// Follow came, so the header needs no more room than it did.
  static const double searchWidth = 204;
  static const double searchWidthNarrow = 160;

  static const double height = 56;

  final bool narrow;
  final EventLogFilter filter;
  final Map<EventLogFilter, int> counts;
  final ValueChanged<EventLogFilter> onFilter;
  final TextEditingController search;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;

  /// Whether the list follows the newest event (plan §7k.4).
  final bool follow;
  final VoidCallback onFollow;

  /// Rows just copied, while Copy shows its check; null otherwise.
  final int? copiedCount;

  /// Null disables the button (nothing to copy or clear).
  final VoidCallback? onCopy;
  final VoidCallback? onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final gap = narrow ? 6.0 : 8.0;
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 0, narrow ? 6 : 10, 0),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          const DialogIconTile(Icons.format_list_bulleted, size: 30),
          if (!narrow) ...[
            const SizedBox(width: 10),
            Text('Event log', style: t.cardTitle, maxLines: 1),
          ],
          SizedBox(width: narrow ? 8 : 16),
          Row(
            key: const ValueKey('event-log-filters'),
            spacing: 6,
            children: [
              for (final f in EventLogFilter.values)
                _LogFilterChip(
                  filter: f,
                  count: counts[f] ?? 0,
                  selected: filter == f,
                  iconOnly: narrow,
                  onPressed: () => onFilter(f),
                ),
            ],
          ),
          SizedBox(width: gap),
          // The search takes what is left, up to its width, at the right.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: narrow ? searchWidthNarrow : searchWidth,
                ),
                child: _SearchField(
                  controller: search,
                  focusNode: searchFocus,
                  onChanged: onSearch,
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: cs.outlineVariant,
          ),
          const SizedBox(width: 2),
          _HeaderButton(
            key: const ValueKey('event-log-follow'),
            icon: Icons.vertical_align_top,
            tooltip: 'Follow new events',
            selected: follow,
            onPressed: onFollow,
          ),
          _HeaderButton(
            key: const ValueKey('event-log-copy'),
            icon: copiedCount == null ? Icons.copy_outlined : Icons.check,
            tooltip: copiedCount == null
                ? 'Copy'
                : 'Copied $copiedCount ${copiedCount == 1 ? 'event' : 'events'}',
            onPressed: onCopy,
          ),
          _HeaderButton(
            key: const ValueKey('event-log-clear'),
            icon: Icons.delete_outline,
            tooltip: 'Clear',
            onPressed: onClear,
          ),
          _HeaderButton(
            key: const ValueKey('event-log-close'),
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _LogFilterChip extends StatelessWidget {
  const _LogFilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.iconOnly,
    required this.onPressed,
  });

  final EventLogFilter filter;
  final int count;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onPressed;

  static const double _mark = 14;

  /// All keeps its name even when narrow: it has no icon of its own.
  bool get _showLabel => !iconOnly || filter == EventLogFilter.all;

  /// The chip's mark: Alerts' red dot, the type's icon, none for All.
  Widget? _markOf(BuildContext context, Color fg) {
    Widget icon(LogEventType type) =>
        Icon(logSourceIcon(type), size: _mark, color: fg);
    return switch (filter) {
      EventLogFilter.all => null,
      EventLogFilter.alerts => SizedBox.square(
        dimension: _mark,
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      EventLogFilter.commands => icon(LogEventType.command),
      EventLogFilter.connection => icon(LogEventType.connectivity),
      EventLogFilter.osc => icon(LogEventType.osc),
      EventLogFilter.web => icon(LogEventType.web),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = selected ? cs.onPrimaryContainer : t.secondary;
    final label = filter.label;
    final chip = BarChip(
      key: ValueKey('event-log-filter-${filter.name}'),
      selected: selected,
      padding: iconOnly ? 9 : BarChip.defaultPadding,
      // A chip with nothing behind it stays in place, dimmed; a selected
      // one that empties stays selected.
      onPressed: count == 0 ? null : onPressed,
      children: [
        ?_markOf(context, fg),
        if (_showLabel)
          Text(
            label,
            style: t.description.copyWith(
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        Text(
          '$count',
          style: t.caption.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: selected ? cs.onPrimaryContainer : t.tertiary,
          ),
        ),
      ],
    );
    return Semantics(
      label: _showLabel ? null : label,
      selected: selected,
      child: _showLabel ? chip : CustomTooltip(message: label, child: chip),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('event-log-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: plainFieldStyle,
      decoration: dialogFieldDecoration(
        context,
        hintText: 'Search log',
        prefixIcon: Icons.search,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 4),
          // The clear button keeps its slot while the field is empty.
          child: Visibility(
            visible: controller.text.isNotEmpty,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: SizedBox.square(
              dimension: 32,
              child: IconButton(
                key: const ValueKey('event-log-search-clear'),
                tooltip: 'Clear search',
                iconSize: 16,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(''),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 36 px icon button of the header with its tooltip. [selected] fills
/// it in the primary container, the state colour (Follow while on).
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomTooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        isSelected: selected,
        style: selected
            ? IconButton.styleFrom(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            : null,
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      ),
    );
  }
}
