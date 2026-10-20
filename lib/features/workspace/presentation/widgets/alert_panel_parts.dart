import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alerts.dart';
import 'alert_scroll_area.dart';
import 'common/dialog_parts.dart';
import 'common/severity_pill.dart';
import 'custom_tooltip.dart';

/// The surface both alert panels sit on (plan §7m.1): the menus' surface
/// and border, radius 14, the popover's shadow, no inset, so the list and
/// the footer run edge to edge.
class AlertPanelSurface extends StatelessWidget {
  const AlertPanelSurface({
    super.key,
    required this.width,
    required this.child,
  });

  static const double radius = 14;

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: cs.outlineVariant),
    );
    return Container(
      width: width,
      decoration: ShapeDecoration(
        shape: shape,
        shadows: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // A Material for the text style and ink: the panels float in the
      // overlay, outside any page's Material.
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A panel's 52 px header: [title] in `cardTitle` with [note] after it,
/// then [actions] on the right.
class AlertPanelHeader extends StatelessWidget {
  const AlertPanelHeader({
    super.key,
    required this.title,
    this.note,
    this.actions = const [],
  });

  static const double height = 52;

  final String title;

  /// After the title: `4 active` in `description`, or the projector's IP.
  final Widget? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
        child: Row(
          spacing: 10,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.cardTitle,
              ),
            ),
            ?note,
            const Spacer(),
            if (actions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: actions,
              ),
          ],
        ),
      ),
    );
  }
}

/// A 32 px icon button of a panel header, named by a [CustomTooltip];
/// [selected] fills it with the primary container (Sort into project
/// groups while on).
class AlertPanelIconButton extends StatelessWidget {
  const AlertPanelIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected,
  });

  final IconData icon;
  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;

  /// Non-null makes it a toggle.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = selected ?? false;
    return CustomTooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: selected,
        label: label,
        container: true,
        excludeSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: IconButton.styleFrom(
            backgroundColor: on ? cs.primaryContainer : null,
            foregroundColor: on ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
    );
  }
}

/// The severity pills of [alerts] (plan §7m.3), the status bar's: critical
/// and warning filled with the unacknowledged count, outlined with the
/// total once all are acknowledged; green for the ones that are over.
class AlertCountPills extends StatelessWidget {
  const AlertCountPills(this.alerts, {super.key});

  final Iterable<ActiveAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final c = countAlerts(alerts);
    Widget? pill(SeverityPillKind kind, int open, int total) {
      if (total == 0) return null;
      return SeverityPill(
        kind: kind,
        count: open > 0 ? open : total,
        filled: open > 0,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        ?pill(SeverityPillKind.critical, c.critical, c.criticalTotal),
        ?pill(SeverityPillKind.warning, c.warning, c.warningTotal),
        if (c.recovered > 0)
          SeverityPill(kind: SeverityPillKind.recovered, count: c.recovered),
      ],
    );
  }
}

/// The fold chevron of group headers and sections: down while open.
class AlertChevron extends StatelessWidget {
  const AlertChevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.25 : 0,
    duration: const Duration(milliseconds: 120),
    child: Icon(
      Icons.chevron_right,
      size: 16,
      color: AppText.of(context).secondary,
    ),
  );
}

/// The fold of a panel's acknowledged alerts: a divider, then *Acknowledged
/// 3* in `label` (plan §7m.3).
class AcknowledgedHeader extends StatelessWidget {
  const AcknowledgedHeader({
    super.key,
    required this.count,
    required this.open,
    required this.onTap,
  });

  static const double height = 40;

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 5),
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                spacing: 8,
                children: [
                  AlertChevron(open: open),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Acknowledged '),
                        TextSpan(
                          text: '$count',
                          style: TextStyle(color: t.tertiary),
                        ),
                      ],
                    ),
                    style: t.label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A panel's list under its header and filters: a hairline above, padded,
/// taking what the window leaves (put it in a `Flexible`).
class AlertPanelList extends StatelessWidget {
  const AlertPanelList({
    super.key,
    required this.entries,
    required this.maxHeight,
  });

  /// Horizontal room the list takes off the panel's width (border and
  /// padding), so rows can be measured before layout.
  static const double inset = 2 + 2 * _padding;
  static const double _padding = 8;

  final List<AlertScrollEntry> entries;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    padding: const EdgeInsets.all(_padding),
    child: AlertScrollArea(entries: entries, maxHeight: maxHeight, gap: 4),
  );
}

/// A panel's 56 px footer, as the dialogs' (plan §7m.1): *Event log* on the
/// left, *Acknowledge all* filled on the right while [onAcknowledgeAll] is
/// set (something is unacknowledged), hidden otherwise.
class AlertPanelFooter extends StatelessWidget {
  const AlertPanelFooter({
    super.key,
    required this.onEventLog,
    this.onAcknowledgeAll,
  });

  static const double height = 56;

  final VoidCallback onEventLog;
  final VoidCallback? onAcknowledgeAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).card,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: const ValueKey('alerts-event-log'),
            onPressed: onEventLog,
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Event log'),
          ),
          const Spacer(),
          if (onAcknowledgeAll case final ack?)
            FilledButton.icon(
              key: const ValueKey('alerts-acknowledge-all'),
              onPressed: ack,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Acknowledge all'),
            ),
        ],
      ),
    );
  }
}

/// Nothing active (plan §7m.4): the green check tile in place of the list.
class AlertPanelNothingActive extends StatelessWidget {
  const AlertPanelNothingActive({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: AlertPanelNotice(
      icon: Icons.check_circle_outline,
      iconColor: AppStatusColors.of(context).success,
      title: 'No active alerts',
      text: 'Everything is within limits. Past alerts are in the event log',
    ),
  );
}

/// A panel's empty or filtered state (plan §7m.4): an optional icon tile, a
/// title, one line and an optional text button. [height] fixed, so it can
/// stand in the list as an entry.
class AlertPanelNotice extends StatelessWidget {
  const AlertPanelNotice({
    super.key,
    required this.title,
    required this.text,
    this.icon,
    this.iconColor,
    this.action,
  });

  /// With a tile; without one but with a button, the same room.
  static const double height = 136;

  final String title;
  final String text;
  final IconData? icon;

  /// The tile's icon colour; primary by default.
  final Color? iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon case final icon?) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DialogSurfaces.of(context).soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.description,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 6),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
