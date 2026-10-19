import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/scheduled_task.dart';
import '../../../domain/task_draft.dart';
import '../common/dialog_parts.dart';
import '../common/segmented_tabs.dart';
import 'date_field.dart';
import 'task_parts.dart';
import 'time_field.dart';

const _dayShort = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _presets = <(String, Set<int>)>[
  ('Weekdays', {1, 2, 3, 4, 5}),
  ('Weekend', {6, 7}),
  ('Every day', {1, 2, 3, 4, 5, 6, 7}),
];
const _dayGap = 6.0;
const _daysWidth = 7 * 32 + 6 * _dayGap;
const _dividerWidth = 1 + 2 * 12.0;

/// Section 3: Repeat and Time (and Date for a one-time task) in one row,
/// then for a weekly task the days and their presets.
class WhenSection extends StatelessWidget {
  const WhenSection({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final TaskDraft draft;
  final Set<DraftError> errors;
  final DraftEdit onChanged;

  @override
  Widget build(BuildContext context) {
    final dateError =
        errors.contains(DraftError.date) ||
        errors.contains(DraftError.datePast);
    final daysError = errors.contains(DraftError.days);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskSectionHeader(
          number: 3,
          label: 'When',
          error: dateError || daysError,
        ),
        const SizedBox(height: 10),
        // A Wrap, so Date and Time go under Repeat in a narrow window.
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            // Not a LabeledField: it stretches its child, and the tabs take
            // their own width here.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Repeat', style: AppText.of(context).label),
                const SizedBox(height: 6),
                SegmentedTabs<ScheduleType>(
                  key: const ValueKey('repeat'),
                  expand: false,
                  selected: draft.scheduleType,
                  onChanged: (v) =>
                      onChanged((d) => d.copyWith(scheduleType: v)),
                  tabs: const [
                    SegmentedTab(value: ScheduleType.once, label: 'Once'),
                    SegmentedTab(value: ScheduleType.daily, label: 'Daily'),
                    SegmentedTab(value: ScheduleType.weekly, label: 'Weekly'),
                  ],
                ),
              ],
            ),
            if (draft.scheduleType == ScheduleType.once)
              SizedBox(
                width: 170,
                child: LabeledField(
                  label: 'Date',
                  error: dateError,
                  child: TaskDateField(
                    key: const ValueKey('task-date'),
                    value: draft.date,
                    error: dateError,
                    onChanged: (date) => onChanged(
                      (d) => date == null
                          ? d.copyWith(clearDate: true)
                          : d.copyWith(date: date),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 120,
              child: LabeledField(
                label: 'Time',
                child: TaskTimeField(
                  key: const ValueKey('task-time'),
                  hour: draft.hour,
                  minute: draft.minute,
                  onChanged: (h, m) =>
                      onChanged((d) => d.copyWith(hour: h, minute: m)),
                ),
              ),
            ),
          ],
        ),
        if (draft.scheduleType == ScheduleType.weekly) ...[
          const SizedBox(height: 14),
          LabeledField(
            label: 'Days',
            error: daysError,
            child: _Days(
              days: draft.weekdays,
              onToggle: (day) => onChanged(
                (d) => d.copyWith(
                  weekdays: d.weekdays.contains(day)
                      ? (Set.of(d.weekdays)..remove(day))
                      : {...d.weekdays, day},
                ),
              ),
              onPreset: (days) => onChanged((d) => d.copyWith(weekdays: days)),
            ),
          ),
        ],
      ],
    );
  }
}

/// The seven day toggles and the presets: beside them behind a divider
/// when the row has room, under them when it doesn't.
class _Days extends StatelessWidget {
  const _Days({
    required this.days,
    required this.onToggle,
    required this.onPreset,
  });

  final Set<int> days;
  final ValueChanged<int> onToggle;
  final ValueChanged<Set<int>> onPreset;

  /// Width of the three preset chips laid out in a row, measured in the
  /// ambient font (the style alone carries no family).
  double _presetsWidth(BuildContext context, TextStyle style) {
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    var width = (_presets.length - 1) * _dayGap;
    for (final (label, _) in _presets) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: merged),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      width += painter.width + 24;
      painter.dispose();
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final toggles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: _dayGap),
          DayToggle(
            label: _dayShort[d - 1],
            tooltip: _dayNames[d - 1],
            selected: days.contains(d),
            onTap: () => onToggle(d),
          ),
        ],
      ],
    );
    // A Wrap: under the toggles it may still be wider than the editor.
    final presets = Wrap(
      spacing: _dayGap,
      runSpacing: _dayGap,
      children: [
        for (final (label, preset) in _presets)
          TaskToggleChip(
            label: label,
            height: 28,
            selected: setEquals(days, preset),
            onTap: () => onPreset(Set.of(preset)),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final chipStyle = t.description.copyWith(fontWeight: FontWeight.w600);
        final oneRow =
            _daysWidth + _dividerWidth + _presetsWidth(context, chipStyle) <=
            box.maxWidth;
        if (!oneRow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [toggles, const SizedBox(height: 8), presets],
          );
        }
        return Row(
          children: [
            toggles,
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: cs.outlineVariant,
            ),
            presets,
          ],
        );
      },
    );
  }
}
