import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_errors.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import 'alert_panel_parts.dart';
import 'alert_row.dart';
import 'alert_scroll_area.dart';
import 'hover_panel.dart';

/// The Monitoring table's Errors cell when the projector reports errors:
/// the codes as tags in their severity colour, critical first, and on hover
/// a panel with what the codes don't say (each error's name and how long it
/// has been active).
class MonitoringErrorsCell extends ConsumerWidget {
  const MonitoringErrorsCell({super.key, required this.node});

  // Row metrics, shared by the layout and by the measuring that decides how
  // many tags fit.
  static const double _padding = 6;
  static const double _iconSize = 13;
  static const double _iconGap = 6;
  static const double _tagGap = 4;
  static const _plusStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  final ProjectorNode node;

  /// [style] over the inherited text style, as a `Text` on screen gets it
  /// (the table sets its own font and size), rounded up so sub-pixel
  /// differences can't add up past the edge.
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When each error's alert started; empty while the rule is off.
    final since = ref.watch(
      alertsProvider.select(
        (alerts) => {
          for (final a in alerts.values)
            if (a.nodeId == node.id && a.rule == AlertRule.error)
              a.item: a.since,
        },
      ),
    );
    final items = sortProjectorErrors(
      decodeProjectorErrors(node.errors),
      (id) => since[id],
    );
    final top = items.first.severity;
    final palette = AlertPalette.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return HoverPanel(
      width: _ErrorsPanel.width,
      panel: (_) => _ErrorsPanel(items: items, since: since),
      // Whole tags only, as many as this column's width takes; the rest go
      // into +N, so a narrow column never cuts a code in half.
      builder: (context, active) => LayoutBuilder(
        builder: (context, constraints) {
          double plusWidth(int hidden) =>
              _textWidth(context, '+$hidden', _plusStyle);
          final inner = constraints.maxWidth - 2 * _padding;
          final shown = tagsThatFit(
            tagWidths: [
              for (final e in items)
                _textWidth(context, e.id, _CodeTag.style) +
                    2 * _CodeTag.padding,
            ],
            available: inner - _iconSize - _iconGap,
            gap: _tagGap,
            plusWidth: plusWidth,
          );
          final hidden = items.length - shown;
          // Narrower still, the count matters more than the icon.
          final showIcon =
              shown > 0 || _iconSize + _iconGap + plusWidth(hidden) <= inner;
          return Semantics(
            label: '${items.length} ${items.length == 1 ? 'error' : 'errors'}',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _padding,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.06)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              // The measuring above already keeps the row inside the cell;
              // whatever a column too narrow for even "+N" leaves over is
              // clipped quietly instead of flagged as an overflow. Sized to
              // the row, so the hover highlight hugs it.
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                constrainedAxis: Axis.vertical,
                clipBehavior: Clip.hardEdge,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      Icon(
                        AlertPalette.iconData(top),
                        size: _iconSize,
                        color: AlertPalette.icon(top),
                      ),
                      const SizedBox(width: _iconGap),
                    ],
                    for (final (i, e) in items.take(shown).indexed) ...[
                      if (i > 0) const SizedBox(width: _tagGap),
                      _CodeTag(e.id, color: palette.text(e.severity)),
                    ],
                    if (hidden > 0) ...[
                      if (shown > 0) const SizedBox(width: _tagGap),
                      Text(
                        '+$hidden',
                        style: _plusStyle.copyWith(color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CodeTag extends StatelessWidget {
  const _CodeTag(this.code, {required this.color});

  /// Horizontal padding and text style, also used to measure a tag.
  static const double padding = 5;
  static const style = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: padding, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(code, style: style.copyWith(color: color)),
  );
}

/// The errors, one row each; no header, the table row already names the
/// projector.
class _ErrorsPanel extends StatelessWidget {
  const _ErrorsPanel({required this.items, required this.since});

  static const double width = 340;
  static const double _rowHeight = 36;

  /// Eight rows, then it scrolls.
  static const double _maxListHeight = 8 * _rowHeight + 7 * 3;

  final List<ProjectorErrorItem> items;
  final Map<String, DateTime> since;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AlertPalette.of(context);
    final now = DateTime.now();
    final muted = colors.onSurfaceVariant.withValues(alpha: 0.75);

    return AlertPanelSurface(
      width: width,
      child: AlertScrollArea(
        maxHeight: _maxListHeight,
        entries: [
          for (final e in items)
            (
              height: _rowHeight,
              counts: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 0, 10, 0),
                decoration: BoxDecoration(
                  color: palette.item,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          AlertPalette.icon(e.severity).withValues(alpha: 0.17),
                          palette.item,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        AlertPalette.iconData(e.severity),
                        size: 14,
                        color: AlertPalette.icon(e.severity),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.name ?? 'Unknown error',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.text(e.severity),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.id,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        switch (since[e.id]) {
                          final s? => formatAlertDuration(now.difference(s)),
                          null => '',
                        },
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
