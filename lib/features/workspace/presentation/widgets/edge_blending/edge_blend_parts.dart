import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/blend_edge.dart';
import '../common/controls_card.dart';
import '../common/dialog_parts.dart';
import '../common/skeleton.dart';
import '../custom_tooltip.dart';
import 'edge_blend_state.dart';

/// Keys of the dialog's frame, for the layout tests.
const edgeBlendModeTilesKey = ValueKey('edge-blend-mode-tiles');
const edgeBlendTabsKey = ValueKey('edge-blend-tabs');
const edgeBlendCanvasCardKey = ValueKey('edge-blend-canvas-card');
const edgeBlendControlsCardKey = ValueKey('edge-blend-controls-card');

/// The colour of what a handle or slider moves (owner, 2026-10-14): Start
/// amber, Width primary, so the two lines of an edge never read as one;
/// the black border neutral.
Color edgePartColor(BuildContext context, EdgePart part) => switch (part) {
  EdgePart.start => AppStatusColors.of(context).warning,
  EdgePart.width => Theme.of(context).colorScheme.primary,
  EdgePart.border => Theme.of(context).colorScheme.onSurfaceVariant,
};

/// The small square before a Start or Width label, in its canvas colour.
class PartMark extends StatelessWidget {
  const PartMark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// A small frame with the edge's side drawn thick, so the four rows read
/// at a glance.
class EdgeSideIcon extends StatelessWidget {
  const EdgeSideIcon({super.key, required this.edge, required this.enabled});

  final BlendEdge edge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thin = BorderSide(
      color: enabled ? cs.onSurfaceVariant : cs.outline,
      width: 1.3,
    );
    final thick = BorderSide(
      color: enabled ? cs.primary : cs.outline,
      width: 3.2,
    );
    return Container(
      width: 18,
      height: 13,
      decoration: BoxDecoration(
        border: Border(
          top: edge == BlendEdge.upper ? thick : thin,
          bottom: edge == BlendEdge.lower ? thick : thin,
          left: edge == BlendEdge.left ? thick : thin,
          right: edge == BlendEdge.right ? thick : thin,
        ),
      ),
    );
  }
}

/// An icon toggle of the canvas header (Markers, Auto test pattern): its
/// name is in the tooltip, its state is the fill. [warning] puts an amber
/// dot on it and the reason in the tooltip.
class EdgeBlendToggle extends StatelessWidget {
  const EdgeBlendToggle({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onChanged,
    this.detail,
    this.warning,
  });

  final IconData icon;
  final String tooltip;
  final String? detail;
  final String? warning;
  final bool selected;

  /// Null disables the toggle.
  final ValueChanged<bool>? onChanged;

  static const double size = 34;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warning = this.warning;
    final onChanged = this.onChanged;
    final button = IconButton(
      isSelected: selected,
      icon: Icon(icon, size: 18),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(size)),
        minimumSize: const WidgetStatePropertyAll(Size.square(size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cs.primaryContainer : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? cs.onSurface.withValues(alpha: 0.38)
              : s.contains(WidgetState.selected)
              ? cs.onPrimaryContainer
              : cs.onSurfaceVariant,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.selected) && onChanged != null
                ? cs.primary
                : cs.outlineVariant,
          ),
        ),
      ),
      onPressed: onChanged == null ? null : () => onChanged(!selected),
    );
    return CustomTooltip(
      message: tooltip,
      detail: warning ?? detail,
      warning: warning != null,
      child: Badge(
        isLabelVisible: warning != null,
        smallSize: 7,
        backgroundColor: AppStatusColors.of(context).warning,
        child: button,
      ),
    );
  }
}

/// Pair mode's Link control on the facing edge's card: a labelled chip
/// (`Linked with B Left`). [onChanged] is null when Link isn't possible,
/// [tooltip] then says why.
typedef EdgeLinkControl = ({
  BlendEdge edge,
  bool on,
  String label,
  String tooltip,
  ValueChanged<bool>? onChanged,
});

class LinkChip extends StatelessWidget {
  const LinkChip({super.key, required this.link});

  final EdgeLinkControl link;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final onChanged = link.onChanged;
    final on = link.on;
    final fg = on ? cs.onPrimaryContainer : t.secondary;
    return CustomTooltip(
      message: link.tooltip,
      child: Material(
        color: on ? cs.primaryContainer : DialogSurfaces.of(context).soft,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged(!on),
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(on ? Icons.link : Icons.link_off, size: 14, color: fg),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    link.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab of the A / B switch at the top of a pair's controls card
/// (§7a.3), inside the dialogs' tab strip: the letter, the IP in mono and
/// whether that projector replies.
class ProjectorTabContent extends StatelessWidget {
  const ProjectorTabContent({
    super.key,
    required this.letter,
    required this.ip,
    required this.dot,
    required this.selected,
  });

  final String letter;
  final String ip;
  final Color dot;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SideLetterTile(letter: letter, active: selected),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            ip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.monoSmall.copyWith(
              color: selected ? t.primary : t.secondary,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

/// The `A` / `B` letter of a pair side, filled when it's the active one.
class SideLetterTile extends StatelessWidget {
  const SideLetterTile({super.key, required this.letter, required this.active});

  final String letter;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? cs.primary : DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        letter,
        style: t.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: active ? cs.onPrimary : t.secondary,
          height: 1,
        ),
      ),
    );
  }
}

/// A checkbox with `Interlocked` after it, for a level group's header.
class InterlockedCheck extends StatelessWidget {
  const InterlockedCheck({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return CustomTooltip(
      message: 'R, G and B move together',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: Checkbox(
                value: value,
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onChanged(v!),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Interlocked',
              style: t.description.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Off keeps the controls in place (and their State) but dims them and
/// takes no input: the projector accepts writes while Off, they just have
/// no effect, so this is only a cue.
class OffDim extends StatelessWidget {
  const OffDim({super.key, required this.off, required this.child});

  final bool off;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: off,
    child: AnimatedOpacity(
      opacity: off ? 0.38 : 1,
      duration: const Duration(milliseconds: 150),
      child: child,
    ),
  );
}

/// A projector that didn't answer a read: what happened and Retry.
class NoReplyView extends StatelessWidget {
  const NoReplyView({
    super.key,
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.body.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 2),
            Text(detail, textAlign: TextAlign.center, style: t.caption),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// The controls card before the active projector's values are in: a
/// header line and [rows] slider-sized blocks per group; it pulses while
/// they're being read and stands still after a failed read.
class EdgeBlendControlsSkeleton extends StatelessWidget {
  const EdgeBlendControlsSkeleton({
    super.key,
    required this.groups,
    required this.pulse,
    this.top,
  });

  /// Rows per group.
  final List<int> groups;
  final bool pulse;

  /// Above the groups: the A / B switch in a pair, which works while the
  /// active projector loads.
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    Widget group(int rows) {
      final blocks = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          const SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 96, height: 12),
            ),
          ),
          for (var i = 0; i < rows; i++)
            const SizedBox(
              height: 36,
              child: Row(
                children: [
                  Skeleton(width: 48, height: 12),
                  SizedBox(width: 16),
                  Expanded(child: Skeleton(height: 4, radius: 2)),
                  SizedBox(width: 16),
                  Skeleton(width: 72, height: 32, radius: 8),
                ],
              ),
            ),
        ],
      );
      return pulse ? SkeletonPulse(child: blocks) : blocks;
    }

    return ControlsCard(
      key: edgeBlendControlsCardKey,
      groups: [?top, for (final rows in groups) group(rows)],
    );
  }
}
