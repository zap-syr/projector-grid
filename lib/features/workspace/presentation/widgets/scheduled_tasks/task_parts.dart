import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/task_draft.dart';
import '../common/dialog_parts.dart';

/// How the editor's sections change the draft: by a function of the
/// current one, so two edits in one frame (a field committing on blur as
/// another control is clicked) both land.
typedef DraftEdit = void Function(TaskDraft Function(TaskDraft draft) update);

/// `1 Command`, `2 Target`, `3 When`: a numbered section heading. The number
/// turns red while the section keeps the task from being saved.
class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.number,
    required this.label,
    this.error = false,
  });

  final int number;
  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Row(
      children: [
        // Neutral like the section tiles: a blue circle would be blue only
        // to stand out (visual rules §5).
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: error ? cs.errorContainer : DialogSurfaces.of(context).soft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: t.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: error ? cs.error : cs.primary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: t.label.copyWith(color: error ? cs.error : null)),
      ],
    );
  }
}

/// A radio choice drawn as a tile: All projectors / Groups. The selected
/// border is painted over the tile, so selecting it doesn't change its size.
class TaskOptionTile extends StatelessWidget {
  const TaskOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;

  /// Null disables the tile (no groups in the project).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final surfaces = DialogSurfaces.of(context);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(12);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: enabled,
      child: Material(
        color: selected
            ? Color.alphaBlend(
                cs.primary.withValues(alpha: 0.08),
                surfaces.field,
              )
            : surfaces.field,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !enabled
                          ? t.disabled
                          : selected
                          ? cs.primary
                          : cs.outline,
                      width: selected ? 5 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: enabled ? null : t.disabled,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.description.copyWith(
                          color: enabled ? null : t.disabled,
                        ),
                      ),
                    ],
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

/// A rounded on/off chip: a target group (with its colour dot) or a day
/// preset. On is filled with the primary container. The weight doesn't
/// change with the state, so a row of chips never reflows on a click.
class TaskToggleChip extends StatelessWidget {
  const TaskToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
    this.height = 30,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected
            ? cs.primaryContainer
            : cs.outline.withValues(alpha: 0.6),
      ),
    );
    return Semantics(
      toggled: selected,
      child: Material(
        color: selected
            ? cs.primaryContainer
            : DialogSurfaces.of(context).field,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.only(
              left: dotColor == null ? 12 : 9,
              right: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.description.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onPrimaryContainer : t.secondary,
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

/// One round weekday toggle (32 px): filled primary when on.
class DayToggle extends StatelessWidget {
  const DayToggle({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final shape = CircleBorder(
      side: BorderSide(
        color: selected ? cs.primary : cs.outline.withValues(alpha: 0.6),
      ),
    );
    return Semantics(
      label: tooltip,
      toggled: selected,
      child: Material(
        color: selected ? cs.primary : DialogSurfaces.of(context).field,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 32,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: t.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : t.secondary,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
