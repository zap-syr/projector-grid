import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/alignment_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/toolbar_counts_provider.dart';
import '../providers/workspace_provider.dart';
import 'add_projector_dialog.dart';
import 'alignment_banner.dart';
import 'common/dialog_parts.dart';
import 'common/segmented_tabs.dart';
import 'custom_tooltip.dart';
import 'manage_groups_dialog.dart';
import 'scheduled_tasks/scheduled_tasks_dialog.dart';

/// Below this window width the tool buttons drop their labels.
const double toolbarCompactBelow = 880;

/// Above this window width they get them back. The band in between keeps
/// whichever mode the toolbar is in, so resizing across the edge can't
/// flicker between the two.
const double toolbarFullAbove = 920;

/// Whether the toolbar is compact at [windowWidth]. Chosen from the window,
/// not from the toolbar's measured content, so a badge or a label can never
/// switch the mode. [wasCompact] is the current mode (null on first build,
/// when the band splits at its middle).
bool toolbarCompact(double windowWidth, {bool? wasCompact}) {
  if (windowWidth < toolbarCompactBelow) return true;
  if (windowWidth > toolbarFullAbove) return false;
  return wasCompact ??
      windowWidth < (toolbarCompactBelow + toolbarFullAbove) / 2;
}

/// The main toolbar (plan §7f): the filled Add projectors pill, the tool
/// buttons (Groups, Scheduled tasks, Alignment) and the view switch.
class MainToolbar extends ConsumerStatefulWidget {
  const MainToolbar({super.key});

  static const double height = 52;

  @override
  ConsumerState<MainToolbar> createState() => _MainToolbarState();
}

class _MainToolbarState extends ConsumerState<MainToolbar> {
  bool? _compact;

  @override
  Widget build(BuildContext context) {
    final compact = _compact = toolbarCompact(
      MediaQuery.sizeOf(context).width,
      wasCompact: _compact,
    );
    final isMonitoringView = ref.watch(
      appSettingsProvider.select((s) => s.isMonitoringView),
    );
    final alignmentActive = ref.watch(
      alignmentProvider.select((s) => s.active || s.busy),
    );
    // Small derived providers, so a polling tick that changes neither count
    // doesn't rebuild the toolbar.
    final groupCount = ref.watch(groupCountProvider);
    final tasks = ref.watch(scheduledTasksSummaryProvider);

    final cs = Theme.of(context).colorScheme;
    final background = cs.surface;
    final ctrl = Platform.isMacOS ? '⌘' : 'Ctrl';

    final tools = <Widget>[
      _ToolButton(
        key: const ValueKey('toolbar-groups'),
        icon: Icons.layers_outlined,
        label: 'Groups',
        compact: compact,
        toolbarColor: background,
        badge: groupCount,
        tooltip: 'Groups',
        detail: switch (groupCount) {
          0 => 'No groups',
          1 => '1 group',
          _ => '$groupCount groups',
        },
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const ManageGroupsDialog(),
        ),
      ),
      _ToolButton(
        key: const ValueKey('toolbar-tasks'),
        icon: Icons.schedule,
        label: 'Scheduled tasks',
        compact: compact,
        toolbarColor: background,
        badge: tasks.active,
        tooltip: 'Scheduled tasks',
        detail: tasks.active == 0
            ? 'No active tasks'
            : [
                '${tasks.active} active',
                if (tasks.nextRun != null) 'next run ${tasks.nextRun}',
              ].join(', '),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const ScheduledTasksDialog(),
        ),
      ),
      _ToolButton(
        key: const ValueKey('toolbar-alignment'),
        icon: Icons.center_focus_strong,
        label: 'Alignment',
        compact: compact,
        toolbarColor: background,
        active: alignmentActive,
        tooltip: alignmentActive
            ? 'Exit Alignment mode'
            : 'Enter Alignment mode',
        shortcut: [ctrl, 'L'],
        onPressed: () => toggleAlignmentMode(ref),
      ),
    ];

    return Container(
      height: MainToolbar.height,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            // The row fits the smallest window (800) in compact mode. If a
            // bigger text scale or another font ever makes it wider, it is
            // clipped at the view switch rather than overflowing or
            // scrolling (plan §7f.2: extra tools would then go to a menu).
            child: UnconstrainedBox(
              alignment: Alignment.centerLeft,
              constrainedAxis: Axis.vertical,
              clipBehavior: Clip.hardEdge,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddProjectorsButton(
                    onPressed: () => _openAddProjectors(context),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: cs.outlineVariant,
                  ),
                  for (final tool in tools) ...[const SizedBox(width: 6), tool],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedTabs<bool>(
            key: const ValueKey('toolbar-view-switch'),
            expand: false,
            tabs: const [
              SegmentedTab(
                value: false,
                label: 'Controls',
                icon: Icons.grid_view,
              ),
              SegmentedTab(
                value: true,
                label: 'Monitoring',
                icon: Icons.table_chart_outlined,
              ),
            ],
            selected: isMonitoringView,
            onChanged: (v) =>
                ref.read(appSettingsProvider.notifier).setMonitoringView(v),
          ),
        ],
      ),
    );
  }

  void _openAddProjectors(BuildContext context) {
    final existingIps = ref
        .read(workspaceProvider)
        .map((n) => n.ipAddress)
        .toList();
    showDialog(
      context: context,
      builder: (context) => AddProjectorDialog(
        existingIps: existingIps,
        onAddProjectors: (projectors) {
          ref.read(workspaceProvider.notifier).addProjectors(projectors);
        },
      ),
    );
  }
}

/// The toolbar's one filled action, always labelled.
class _AddProjectorsButton extends StatelessWidget {
  const _AddProjectorsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return FilledButton.icon(
      key: const ValueKey('toolbar-add'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        fixedSize: const Size.fromHeight(36),
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: t.body.copyWith(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add projectors'),
    );
  }
}

/// A tool button without an outline: icon + label, or icon only in compact
/// mode. [active] (Alignment on) fills it with the primary container and
/// changes nothing else, so its width stays the same.
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.compact,
    required this.toolbarColor,
    required this.tooltip,
    required this.onPressed,
    this.detail,
    this.shortcut,
    this.badge = 0,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  /// The toolbar's fill, so the badge's ring matches the button around it.
  final Color toolbarColor;
  final String tooltip;
  final String? detail;
  final List<String>? shortcut;
  final VoidCallback onPressed;

  /// Count shown on the icon's corner; zero shows none.
  final int badge;
  final bool active;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final base = widget.active ? cs.primaryContainer : widget.toolbarColor;
    final hoverInk = widget.active ? cs.onPrimaryContainer : cs.onSurface;
    // Opaque, so the badge's ring can take exactly this colour.
    final fill = _hovered
        ? Color.alphaBlend(hoverInk.withValues(alpha: 0.06), base)
        : base;
    final iconColor = widget.active ? cs.onPrimaryContainer : t.secondary;
    final labelColor = widget.active ? cs.onPrimaryContainer : t.primary;

    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, size: 18, color: iconColor),
        // Over the icon, outside the row's layout: a count appearing,
        // changing or disappearing never moves anything (§7f.3).
        if (widget.badge > 0)
          Positioned(
            top: -7,
            right: -9,
            child: _CountBadge(count: widget.badge, ring: fill),
          ),
      ],
    );

    return CustomTooltip(
      message: widget.tooltip,
      detail: widget.detail,
      shortcut: widget.shortcut,
      placement: TooltipPlacement.bottom,
      child: Semantics(
        label: widget.compact ? widget.label : null,
        button: true,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.transparent,
            onHover: (h) => setState(() => _hovered = h),
            onTap: widget.onPressed,
            child: SizedBox(
              height: 36,
              width: widget.compact ? 38 : null,
              child: widget.compact
                  ? Center(child: icon)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(width: 8),
                          Text(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            style: t.body.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small neutral count on a tool button's icon: at least 17 px, `9+` above
/// nine, with a 2 px ring in the colour behind it to cut it out of the icon.
/// Neutral, never blue: a state colour (the missed-run amber of plan §4.8)
/// would only swap the two colours below.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.ring});

  final int count;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      key: const ValueKey('toolbar-badge'),
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: DialogSurfaces.of(context).soft,
        shape: StadiumBorder(
          side: BorderSide(
            color: ring,
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: t.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: t.primary,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
