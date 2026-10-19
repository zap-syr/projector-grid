import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/schedule_labels.dart';
import '../../../domain/scheduled_task.dart';
import '../common/dialog_parts.dart';
import '../custom_tooltip.dart';

const _maxDots = 5;
const _dot = 8.0;
const _dotOverlap = 3.0;

/// Who a task is sent to, on a list card: `All projectors`, one group's dot
/// and name, or for two and more groups up to five stacked dots and
/// `N groups` with the names in a tooltip. `No target` once its groups are
/// all deleted.
class TargetChip extends StatelessWidget {
  const TargetChip({super.key, required this.task, required this.groups});

  final ScheduledTask task;
  final List<ProjectorGroup> groups;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final targets = task.target == ScheduleTarget.group
        ? targetGroupsOf(task.targetGroupIds, groups)
        : const <ProjectorGroup>[];
    final label = targetLabel(task.target, task.targetGroupIds, groups);
    final style = t.caption.copyWith(
      color: targets.isEmpty && task.target == ScheduleTarget.group
          ? t.tertiary
          : t.secondary,
      height: 1.1,
    );

    final Widget content;
    if (targets.length >= 2) {
      // The dots get the room of five and the count that of two digits,
      // so 2 groups and 30 groups make a chip of the same width.
      const dotsWidth = _maxDots * _dot - (_maxDots - 1) * _dotOverlap;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: dotsWidth,
            height: _dot + 3,
            child: _StackedDots(
              colors: [for (final g in targets.take(_maxDots)) Color(g.color)],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    '00 groups',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: style,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (targets.length == 1) ...[
            _Dot(color: Color(targets.single.color)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      );
    }

    final chip = Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: content,
    );
    if (targets.length < 2) return chip;
    return CustomTooltip(
      message: '${targets.length} groups',
      detail: targets.map((g) => g.name).join(', '),
      child: chip,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.ring});

  final Color color;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ring == null
            ? null
            : Border.all(
                color: ring!,
                strokeAlign: BorderSide.strokeAlignOutside,
                width: 1.5,
              ),
      ),
    );
  }
}

/// Dots overlapping right to left; each has a ring in the chip's colour so
/// the one under it reads as separate.
class _StackedDots extends StatelessWidget {
  const _StackedDots({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final ring = DialogSurfaces.of(context).soft;
    const step = _dot - _dotOverlap;
    final width = _dot + (colors.length - 1) * step;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width,
        height: _dot,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, c) in colors.indexed)
              Positioned(
                left: i * step,
                child: _Dot(color: c, ring: i == 0 ? null : ring),
              ),
          ],
        ),
      ),
    );
  }
}
