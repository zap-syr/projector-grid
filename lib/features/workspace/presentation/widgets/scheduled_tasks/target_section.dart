import 'package:flutter/material.dart';

import '../../../domain/projector_group.dart';
import '../../../domain/scheduled_task.dart';
import '../../../domain/task_draft.dart';
import 'task_parts.dart';

/// Section 2: All projectors or Groups, and under Groups the project's
/// groups as toggle chips, any number of them on.
class TargetSection extends StatelessWidget {
  const TargetSection({
    super.key,
    required this.draft,
    required this.groups,
    required this.projectorCount,
    required this.membersByGroup,
    required this.errors,
    required this.onChanged,
  });

  final TaskDraft draft;
  final List<ProjectorGroup> groups;
  final int projectorCount;
  final Map<String, int> membersByGroup;
  final Set<DraftError> errors;
  final DraftEdit onChanged;

  @override
  Widget build(BuildContext context) {
    final byGroups = draft.target == ScheduleTarget.group;
    final selected = groups.where((g) => draft.groupIds.contains(g.id));
    final reached = selected.fold<int>(
      0,
      (sum, g) => sum + (membersByGroup[g.id] ?? 0),
    );
    final groupsSubtitle = groups.isEmpty
        ? 'No groups in project'
        : byGroups
        ? '${selected.length} of ${groups.length} selected, '
              '$reached projector${reached == 1 ? '' : 's'}'
        : '${groups.length} in project';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskSectionHeader(
          number: 2,
          label: 'Target',
          error: errors.contains(DraftError.groups),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TaskOptionTile(
                key: const ValueKey('target-all'),
                title: 'All projectors',
                subtitle: '$projectorCount in project',
                selected: !byGroups,
                onTap: () =>
                    onChanged((d) => d.copyWith(target: ScheduleTarget.all)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TaskOptionTile(
                key: const ValueKey('target-groups'),
                title: 'Groups',
                subtitle: groupsSubtitle,
                selected: byGroups,
                onTap: groups.isEmpty
                    ? null
                    : () => onChanged(
                        (d) => d.copyWith(target: ScheduleTarget.group),
                      ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: byGroups && groups.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in groups)
                        TaskToggleChip(
                          key: ValueKey('target-group-${g.id}'),
                          label: g.name,
                          dotColor: Color(g.color),
                          selected: draft.groupIds.contains(g.id),
                          onTap: () => onChanged(
                            (d) => d.copyWith(
                              groupIds: d.groupIds.contains(g.id)
                                  ? (Set.of(d.groupIds)..remove(g.id))
                                  : {...d.groupIds, g.id},
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
