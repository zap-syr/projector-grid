import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/alert_rule.dart';
import '../../domain/alerts.dart';
import '../../domain/projector_node.dart';
import '../providers/alerts_provider.dart';
import '../providers/workspace_provider.dart';
import 'common/status_pill.dart';
import 'custom_tooltip.dart';
import 'projector_status_style.dart';

/// The quick status popover beside the one selected card (Space): the state
/// you need before sending a command, without leaving the canvas. Placed by
/// [anchor] (the card's rect) inside [bounds] (the canvas viewport), both
/// in the overlay's coordinates: on the card's right, or its left when the
/// right has no room, with an arrow at the card's middle.
class QuickStatusPopover extends StatelessWidget {
  const QuickStatusPopover({
    super.key,
    required this.anchor,
    required this.bounds,
    required this.nodeId,
    required this.onRemotePreview,
    required this.onShowInMonitoring,
  });

  static const double width = 340;
  static const double _gap = 10;
  static const double _margin = 8;
  static const Size _arrowSize = Size(8, 16);

  final Rect anchor;
  final Rect bounds;
  final String nodeId;
  final VoidCallback onRemotePreview;
  final VoidCallback onShowInMonitoring;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roomRight = anchor.right + _gap + width <= bounds.right - _margin;
    final roomLeft = anchor.left - _gap - width >= bounds.left + _margin;
    final onRight = roomRight || !roomLeft;
    return CustomMultiChildLayout(
      delegate: _PopoverLayout(
        anchor: anchor,
        bounds: bounds,
        onRight: onRight,
      ),
      children: [
        LayoutId(
          id: _Part.bubble,
          child: SizedBox(
            key: const ValueKey('quick-status'),
            width: width,
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: QuickStatusContent(
                  nodeId: nodeId,
                  onRemotePreview: onRemotePreview,
                  onShowInMonitoring: onShowInMonitoring,
                ),
              ),
            ),
          ),
        ),
        LayoutId(
          id: _Part.arrow,
          child: CustomPaint(
            size: _arrowSize,
            painter: _ArrowPainter(
              pointsLeft: onRight,
              fill: cs.surfaceContainerHigh,
              border: cs.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}

enum _Part { bubble, arrow }

class _PopoverLayout extends MultiChildLayoutDelegate {
  _PopoverLayout({
    required this.anchor,
    required this.bounds,
    required this.onRight,
  });

  final Rect anchor;
  final Rect bounds;
  final bool onRight;

  @override
  void performLayout(Size size) {
    const margin = QuickStatusPopover._margin;
    const gap = QuickStatusPopover._gap;
    const arrow = QuickStatusPopover._arrowSize;
    final bubble = layoutChild(
      _Part.bubble,
      BoxConstraints.loose(
        Size(QuickStatusPopover.width, max(0, bounds.height - 2 * margin)),
      ),
    );
    final left = onRight
        ? anchor.right + gap
        : anchor.left - gap - bubble.width;
    final double top = (anchor.center.dy - bubble.height / 2).clamp(
      bounds.top + margin,
      max(bounds.top + margin, bounds.bottom - margin - bubble.height),
    );
    positionChild(_Part.bubble, Offset(left, top));

    layoutChild(_Part.arrow, BoxConstraints.tight(arrow));
    // One pixel into the bubble so the arrow covers its border there.
    final arrowLeft = onRight
        ? left - arrow.width + 1
        : left + bubble.width - 1;
    final double arrowTop = (anchor.center.dy - arrow.height / 2).clamp(
      top + 12,
      max(top + 12, top + bubble.height - 12 - arrow.height),
    );
    positionChild(_Part.arrow, Offset(arrowLeft, arrowTop));
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.bounds != bounds || old.onRight != onRight;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.pointsLeft,
    required this.fill,
    required this.border,
  });

  final bool pointsLeft;
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseX = pointsLeft ? w : 0.0;
    final tipX = pointsLeft ? 0.0 : w;
    final edge = Path()
      ..moveTo(baseX, 0)
      ..lineTo(tipX, h / 2)
      ..lineTo(baseX, h);
    canvas.drawPath(Path.from(edge)..close(), Paint()..color = fill);
    canvas.drawPath(
      edge,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.pointsLeft != pointsLeft || old.fill != fill || old.border != border;
}

/// One projector's alerts, compared by content so the popover rebuilds only
/// when they change, not on every alerts update.
@immutable
class _NodeAlerts {
  const _NodeAlerts(this.list);

  final List<ActiveAlert> list;

  @override
  bool operator ==(Object other) =>
      other is _NodeAlerts && listEquals(other.list, list);

  @override
  int get hashCode => Object.hashAll(list);
}

/// What the popover shows: model, IP and group; power, shutter, input with the
/// signal pill, temperatures and the active alerts. Watches only its own
/// node, so a polling tick elsewhere doesn't rebuild it.
class QuickStatusContent extends ConsumerWidget {
  const QuickStatusContent({
    super.key,
    required this.nodeId,
    required this.onRemotePreview,
    required this.onShowInMonitoring,
  });

  /// Alerts listed before the rest is summed up in one line.
  static const int maxAlerts = 3;

  final String nodeId;
  final VoidCallback onRemotePreview;
  final VoidCallback onShowInMonitoring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(workspaceProvider.notifier);
    final data = ref.watch(
      workspaceProvider.select((nodes) {
        final node = nodes.where((n) => n.id == nodeId).firstOrNull;
        if (node == null) return null;
        final group = notifier.groups
            .where((g) => g.id == node.groupId)
            .firstOrNull;
        return (node: node, groupName: group?.name, groupColor: group?.color);
      }),
    );
    final alerts = ref.watch(
      alertsProvider.select(
        (all) => _NodeAlerts(
          sortAlerts(all.values.where((a) => a.nodeId == nodeId)),
        ),
      ),
    );
    if (data == null) return const SizedBox.shrink();
    final node = data.node;
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withValues(alpha: 0.6),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One line: model and IP, the group in the top right corner
        // (owner, 2026-10-21); none without a group.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: SizedBox(
            height: 22,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(node.ipAddress, style: t.monoSmall),
                    ],
                  ),
                ),
                if (data.groupName case final name?) ...[
                  const SizedBox(width: 8),
                  // Narrower than its own cap, so the model keeps room.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: GroupPill(
                      name: name,
                      color: Color(data.groupColor!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        divider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusRow(
                label: 'Power',
                child: _PowerValue(node: node),
              ),
              _StatusRow(
                label: 'Shutter',
                child: _ShutterValue(node: node),
              ),
              _StatusRow(
                label: 'Input',
                child: Row(
                  spacing: 8,
                  children: [
                    Flexible(
                      child: Text(
                        node.input,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SignalPill(node: node),
                  ],
                ),
              ),
              _StatusRow(
                label: 'Temperature',
                child: Row(
                  children: [
                    _Temperature(
                      label: 'Intake',
                      value: node.intakeTemp,
                      severity: _severityOf(alerts, AlertRule.intakeTemp),
                    ),
                    const SizedBox(width: 12),
                    _Temperature(
                      label: 'Exhaust',
                      value: node.exhaustTemp,
                      severity: _severityOf(alerts, AlertRule.exhaustTemp),
                    ),
                  ],
                ),
              ),
              if (alerts.list.isEmpty)
                _StatusRow(
                  label: 'Alerts',
                  child: Text(
                    'None',
                    style: t.body.copyWith(color: t.tertiary),
                  ),
                )
              else ...[
                for (final a in alerts.list.take(maxAlerts)) _AlertLine(a),
                if (alerts.list.length > maxAlerts)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      '${alerts.list.length - maxAlerts} more in Monitoring',
                      style: t.description,
                    ),
                  ),
              ],
            ],
          ),
        ),
        divider,
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            spacing: 6,
            children: [
              // Short labels, so both fit the 340 px popover; the same
              // words as the Monitoring panel's actions.
              _Action(
                key: const ValueKey('quick-status-show-in-monitoring'),
                icon: Icons.table_chart_outlined,
                label: 'Monitoring',
                tooltip: 'Show in Monitoring',
                onPressed: onShowInMonitoring,
              ),
              _Action(
                icon: Icons.monitor_outlined,
                label: 'Preview',
                tooltip: 'Remote Preview',
                onPressed: onRemotePreview,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The temperature's colour follows its alert, not the raw threshold, as
  /// in Monitoring (hysteresis, a rule switched off).
  static AlertSeverity? _severityOf(_NodeAlerts alerts, AlertRule rule) =>
      alerts.list
          .where((a) => a.rule == rule && !a.recovered)
          .firstOrNull
          ?.severity;
}

/// A footer action, tonal like the Monitoring panel's.
class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.tonalIcon(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
    // Equal halves of the footer, as in the mockup.
    return Expanded(
      child: tooltip == null
          ? button
          : CustomTooltip(message: tooltip!, child: button),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppText.of(context).description),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// An icon and a word in one status colour.
class _IconValue extends StatelessWidget {
  const _IconValue({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: color),
        Text(
          label,
          style: AppText.of(context).body
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

bool _reachable(ProjectorNode node) =>
    node.connectionStatus == ConnectionStatus.connected ||
    node.connectionStatus == ConnectionStatus.unprotected;

class _PowerValue extends StatelessWidget {
  const _PowerValue({required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context) {
    final style = ProjectorStatusStyle.of(context);
    return switch (cardHeaderTone(node)) {
      CardHeaderTone.offline => _IconValue(
        icon: Icons.power_off,
        label: 'Offline',
        color: style.toneColor(CardHeaderTone.offline),
      ),
      CardHeaderTone.loginFailed => _IconValue(
        icon: Icons.lock_outline,
        label: 'Login failed',
        color: style.toneColor(CardHeaderTone.loginFailed),
      ),
      _ => _IconValue(
        icon: Icons.power_settings_new,
        label: ProjectorStatusStyle.powerLabel(node.powerStatus),
        color: style.powerColor(node.powerStatus),
      ),
    };
  }
}

class _ShutterValue extends StatelessWidget {
  const _ShutterValue({required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context) {
    if (!_reachable(node)) {
      final t = AppText.of(context);
      return Text('Unknown', style: t.body.copyWith(color: t.tertiary));
    }
    return _IconValue(
      icon: ProjectorStatusStyle.shutterIcon(node.shutterStatus),
      label: ProjectorStatusStyle.shutterLabel(node.shutterStatus),
      color: ProjectorStatusStyle.of(context).shutterColor(node),
    );
  }
}

class _Temperature extends StatelessWidget {
  const _Temperature({
    required this.label,
    required this.value,
    required this.severity,
  });

  final String label;
  final String value;
  final AlertSeverity? severity;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final color = switch (severity) {
      AlertSeverity.critical => Theme.of(context).colorScheme.error,
      AlertSeverity.warning => AppStatusColors.of(context).warning,
      null => t.primary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 6,
      children: [
        Text(label, style: t.caption),
        Text(
          value,
          style: t.body.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine(this.alert);

  final ActiveAlert alert;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final color = alert.recovered
        ? AppStatusColors.of(context).success
        : alert.severity == AlertSeverity.critical
        ? Theme.of(context).colorScheme.error
        : AppStatusColors.of(context).warning;
    final icon = alert.recovered
        ? Icons.check_circle
        : alert.severity == AlertSeverity.critical
        ? Icons.error
        : Icons.warning;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 16, color: color),
          Expanded(
            child: Text(
              alert.rule.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              alert.displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.description,
            ),
          ),
        ],
      ),
    );
  }
}
