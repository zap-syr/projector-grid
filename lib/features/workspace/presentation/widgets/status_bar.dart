import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/monitoring_filter.dart';
import '../../domain/status_bar_view.dart';
import '../providers/app_settings_provider.dart';
import '../providers/poll_status_provider.dart';
import '../providers/status_summary_provider.dart';
import '../providers/workspace_provider.dart';
import 'custom_tooltip.dart';
import 'monitoring/monitoring_actions.dart';
import 'status_bar_alerts_button.dart';
import 'status_bar_item.dart';
import 'status_bar_osc.dart';
import 'status_bar_web_clients.dart';

/// The status bar (plan §7l): projectors with the health meter and the
/// Online / Offline counts, the alerts, and on the right OSC, Web and the
/// time of the last poll. When the full bar doesn't fit with the current
/// values ([statusBarNarrow]), the words step down to icons and counts, the
/// names going to the tooltips.
class StatusBar extends ConsumerStatefulWidget {
  const StatusBar({super.key});

  static const double height = 36;

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  /// The mode last laid out, for focus only: the hidden bar is kept out of
  /// Tab traversal. The layout itself picks the mode in the same frame.
  bool _narrowShown = false;

  void _onMode(bool narrow) {
    if (narrow != _narrowShown) setState(() => _narrowShown = narrow);
  }

  Widget _row(bool narrow) => ExcludeFocus(
    excluding: narrow != _narrowShown,
    child: Row(
      // A hidden OSC or Web item still gets its gap, but only left of the
      // divider, where nothing shows it.
      spacing: 4,
      children: [
        _Projectors(narrow: narrow),
        const StatusBarDivider(),
        _CountButtons(narrow: narrow),
        const StatusBarDivider(),
        StatusBarAlertsButton(narrow: narrow),
        const Spacer(),
        StatusBarOsc(narrow: narrow),
        StatusBarWebClients(narrow: narrow),
        const StatusBarDivider(),
        _Updated(narrow: narrow),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: StatusBar.height,
      padding: const EdgeInsets.only(left: 16, right: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: DefaultTextStyle.merge(
        style: AppText.of(context).description,
        child: _FullOrNarrow(
          full: _row(false),
          narrow: _row(true),
          onMode: _onMode,
        ),
      ),
    );
  }
}

enum _BarSlot { full, narrow }

/// Lays out and shows [full] while its items fit the width with the current
/// values, else [narrow] (owner, 2026-10-20), deciding in the layout itself
/// so a value that grows never shows a frame of overflow. Both stay built;
/// only the shown one is painted, hit and in the semantics tree.
class _FullOrNarrow
    extends SlottedMultiChildRenderObjectWidget<_BarSlot, RenderBox> {
  const _FullOrNarrow({
    required this.full,
    required this.narrow,
    required this.onMode,
  });

  final Widget full;
  final Widget narrow;

  /// After a layout that changed the mode: true for narrow.
  final ValueChanged<bool> onMode;

  @override
  Iterable<_BarSlot> get slots => _BarSlot.values;

  @override
  Widget? childForSlot(_BarSlot slot) => switch (slot) {
    _BarSlot.full => full,
    _BarSlot.narrow => narrow,
  };

  @override
  SlottedRenderObjectElement<_BarSlot, RenderBox> createElement() =>
      _FullOrNarrowElement(this);

  @override
  _RenderFullOrNarrow createRenderObject(BuildContext context) =>
      _RenderFullOrNarrow(onMode);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullOrNarrow renderObject,
  ) => renderObject.onMode = onMode;
}

class _FullOrNarrowElement
    extends SlottedRenderObjectElement<_BarSlot, RenderBox> {
  _FullOrNarrowElement(super.widget);

  // Finders and the inspector see only the bar on screen.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = (renderObject as _RenderFullOrNarrow).shownSlot;
    visitChildren((e) {
      if (e.slot == shown) visitor(e);
    });
  }
}

class _RenderFullOrNarrow extends RenderBox
    with SlottedContainerRenderObjectMixin<_BarSlot, RenderBox> {
  _RenderFullOrNarrow(this.onMode);

  ValueChanged<bool> onMode;
  bool? _narrow;

  _BarSlot get shownSlot => _narrow ?? false ? _BarSlot.narrow : _BarSlot.full;

  RenderBox get _shown => childForSlot(shownSlot)!;

  @override
  void performLayout() {
    final was = _narrow;
    final fullWidth = childForSlot(_BarSlot.full)!
        .getMaxIntrinsicWidth(constraints.maxHeight);
    final narrow = _narrow = statusBarNarrow(
      constraints.maxWidth,
      fullWidth: fullWidth,
      wasNarrow: was,
    );
    final child = _shown..layout(constraints, parentUsesSize: true);
    size = child.size;
    if (narrow != (was ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onMode(narrow));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(_shown, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(_shown);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _shown.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _shown.getMaxIntrinsicHeight(width);
}

/// *Projectors 18* and the health meter; a tooltip only while a projector
/// has a failed login (then the count is more than Online + Offline), or in
/// the narrow bar for the name.
class _Projectors extends ConsumerWidget {
  const _Projectors({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(statusSummaryProvider);
    final meter = HealthMeter(
      online: s.online,
      wrongLogin: s.wrongLogin,
      offline: s.offline,
    );
    final count = StatusBarCount(s.total);
    final content = Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: narrow
            ? [meter, count]
            : [const Text('Projectors'), count, meter],
      ),
    );
    final wrong = s.wrongLogin;
    if (wrong > 0) {
      return CustomTooltip(
        message: '$wrong wrong login',
        detail: 'Check the login in Edit Projector',
        placement: TooltipPlacement.bottom,
        child: content,
      );
    }
    if (narrow) {
      return CustomTooltip(
        message: '${s.total} projectors',
        placement: TooltipPlacement.bottom,
        child: content,
      );
    }
    return content;
  }
}

/// 84×6, rounded: green online, amber wrong login, red offline, in
/// proportion; an empty grey track without projectors.
class HealthMeter extends StatelessWidget {
  const HealthMeter({
    super.key,
    required this.online,
    required this.wrongLogin,
    required this.offline,
  });

  static const Size size = Size(84, 6);

  final int online;
  final int wrongLogin;
  final int offline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final parts = [
      (const ValueKey('meter-online'), online, sc.success),
      (const ValueKey('meter-wrong-login'), wrongLogin, sc.warning),
      (const ValueKey('meter-offline'), offline, cs.error),
    ].where((p) => p.$2 > 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: size.width,
        height: size.height,
        color: cs.surfaceContainerHighest,
        child: Row(
          // Stretched: an empty ColoredBox under a Row's loose height
          // takes 0 px, and the meter showed only its grey track.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 1,
          children: [
            for (final (key, n, color) in parts)
              Expanded(
                key: key,
                flex: n,
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

/// Online and Offline: each a button to Monitoring with that quick filter.
class _CountButtons extends ConsumerWidget {
  const _CountButtons({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(statusSummaryProvider);
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    void show(MonitoringQuickFilter quick) => showQuickFilterInMonitoring(
      ProviderScope.containerOf(context, listen: false),
      quick,
    );
    const click = 'Click to show them in Monitoring';

    Widget item({
      required Key key,
      required String label,
      required int count,
      required Color dot,
      required MonitoringQuickFilter quick,
      required String tooltip,
      WidgetBuilder? body,
    }) => StatusBarItem(
      key: key,
      narrow: narrow,
      dimmed: count == 0,
      onTap: () => show(quick),
      tooltip: tooltip,
      tooltipBody: count == 0
          ? null
          : body ?? (_) => const TooltipFooter(click),
      semanticLabel: '$label $count',
      children: [
        StatusBarDot(color: dot),
        if (!narrow) Text(label),
        StatusBarCount(count),
      ],
    );

    final allOffline = s.offline > 0 && s.offline == s.total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        item(
          key: const ValueKey('status-online'),
          label: 'Online',
          count: s.online,
          dot: sc.success,
          quick: MonitoringQuickFilter.online,
          tooltip: '${s.online} online',
        ),
        item(
          key: const ValueKey('status-offline'),
          label: 'Offline',
          count: s.offline,
          dot: cs.error,
          quick: MonitoringQuickFilter.offline,
          tooltip: allOffline
              ? 'All ${s.offline} offline'
              : '${s.offline} offline',
          body: (_) => const _OfflineTooltipBody(),
        ),
      ],
    );
  }
}

/// The Offline tooltip's list, watched only while the tooltip is open.
class _OfflineTooltipBody extends ConsumerWidget {
  const _OfflineTooltipBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.read(workspaceProvider.notifier).groups;
    final tip = ref.watch(
      workspaceProvider.select((nodes) => offlineTooltip(nodes, groups)),
    );
    final t = AppText.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tip.note case final note?) Text(note, style: t.description),
        for (final r in tip.rows) TooltipRow(mono: r.ip, text: r.model),
        if (tip.more case final more?)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(more, style: t.description),
          ),
        const TooltipFooter('Click to show them in Monitoring'),
      ],
    );
  }
}

/// *Updated 21:04:12*: the time always stays and only the clock becomes a
/// spinner while a poll runs, so the bar never changes width. Its own
/// widget, so a poll starting or ending rebuilds only this.
class _Updated extends ConsumerWidget {
  const _Updated({required this.narrow});

  final bool narrow;

  static String _time(DateTime? t) {
    if (t == null) return '--:--:--';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poll = ref.watch(pollStatusProvider);
    final interval = ref.watch(
      appSettingsProvider.select((s) => s.pollingIntervalSeconds),
    );
    final t = AppText.of(context);
    final time = _time(poll.lastCompletedAt);
    return StatusBarItem(
      key: const ValueKey('status-updated'),
      narrow: narrow,
      tooltip: poll.lastCompletedAt == null
          ? 'Not updated yet'
          : 'Updated $time',
      tooltipDetail: 'Polling every $interval s',
      children: [
        SizedBox.square(
          dimension: 14,
          child: poll.isPolling
              // The spinner's AnimationController repaints every frame
              // while a poll runs; the boundary keeps that from
              // re-rasterizing the whole window.
              ? const RepaintBoundary(
                  child: Padding(
                    padding: EdgeInsets.all(1),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(Icons.schedule, size: 14, color: t.secondary),
        ),
        // One paragraph, so the mono time sits on the word's baseline.
        Text.rich(
          TextSpan(
            children: [
              if (!narrow) const TextSpan(text: 'Updated  '),
              TextSpan(
                text: time,
                style: t.monoSmall.copyWith(color: t.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
