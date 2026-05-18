import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_group.dart';
import '../../domain/scheduled_task.dart';
import '../providers/custom_commands_provider.dart';
import '../providers/scheduled_tasks_provider.dart';
import '../providers/workspace_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Command catalog
// ─────────────────────────────────────────────────────────────────────────────

class _CommandEntry {
  final String label;
  final String command;
  const _CommandEntry(this.label, this.command);

  @override
  bool operator ==(Object other) =>
      other is _CommandEntry && other.command == command;

  @override
  int get hashCode => command.hashCode;
}

class _CommandGroup {
  final String label;
  final List<_CommandEntry> entries;
  const _CommandGroup(this.label, this.entries);
}

const _builtInGroups = <_CommandGroup>[
  _CommandGroup('Power', [
    _CommandEntry('Power On', 'PON'),
    _CommandEntry('Power Standby', 'POF'),
  ]),
  _CommandGroup('Shutter', [
    _CommandEntry('Shutter Open', 'OSH:0'),
    _CommandEntry('Shutter Close', 'OSH:1'),
  ]),
  _CommandGroup('Input', [
    _CommandEntry('HDMI 1', 'IIS:HD1'),
    _CommandEntry('HDMI 2', 'IIS:HD2'),
    _CommandEntry('SDI 1', 'IIS:SD1'),
    _CommandEntry('SDI 2', 'IIS:SD2'),
    _CommandEntry('Digital Link', 'IIS:DL1'),
    _CommandEntry('DVI-D', 'IIS:DVI'),
    _CommandEntry('DisplayPort', 'IIS:DP1'),
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Schedule summary helpers
// ─────────────────────────────────────────────────────────────────────────────

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _fmtHM(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────────────────────────────────────────
// Main list dialog
// ─────────────────────────────────────────────────────────────────────────────

class ScheduledTasksDialog extends ConsumerWidget {
  const ScheduledTasksDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(scheduledTasksProvider);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 540,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Text('Scheduled Tasks', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _ScheduledTaskEditorDialog(),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.18),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No scheduled tasks yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click Add Task to create one',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (ctx, i) =>
                          _TaskRow(task: tasks[i]),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tasks only run while the app is open',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.38),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task list row
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRow extends ConsumerWidget {
  final ScheduledTask task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(scheduledTasksProvider.notifier);
    final dimmed = !task.enabled;
    final dimColor = theme.colorScheme.onSurface.withValues(alpha: 0.42);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Switch(
        value: task.enabled,
        onChanged: (_) => notifier.toggleEnabled(task.id),
      ),
      title: Text(
        task.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: dimmed ? dimColor : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ScheduledTaskEditorDialog(existing: task),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(scheduledTasksProvider.notifier).remove(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduledTaskEditorDialog extends ConsumerStatefulWidget {
  final ScheduledTask? existing;
  const _ScheduledTaskEditorDialog({this.existing});

  @override
  ConsumerState<_ScheduledTaskEditorDialog> createState() =>
      _ScheduledTaskEditorDialogState();
}

class _ScheduledTaskEditorDialogState
    extends ConsumerState<_ScheduledTaskEditorDialog> {
  bool _commandMissing = false;
  bool _isCustomCommand = false;
  bool _customLabelError = false;
  bool _customCommandError = false;
  bool _groupMissing = false;
  bool _dateMissing = false;
  bool _noWeekdaysError = false;

  late _CommandEntry? _selectedCommand;
  late final TextEditingController _customLabelController;
  late final TextEditingController _customCommandController;
  late ScheduleTarget _target;
  String? _targetGroupId;
  late ScheduleType _scheduleType;
  DateTime? _selectedDate;
  late int _hour;
  late int _minute;
  late Set<int> _selectedWeekdays;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _target = t?.target ?? ScheduleTarget.all;
    _targetGroupId = t?.targetGroupId;
    _scheduleType = t?.scheduleType ?? ScheduleType.daily;
    _selectedDate = t?.oneTimeAt;

    if (t?.timeOfDay != null) {
      final parts = t!.timeOfDay!.split(':');
      _hour = int.tryParse(parts[0]) ?? 8;
      _minute = int.tryParse(parts[1]) ?? 0;
    } else if (t?.oneTimeAt != null) {
      _hour = t!.oneTimeAt!.hour;
      _minute = t.oneTimeAt!.minute;
    } else {
      _hour = 8;
      _minute = 0;
    }

    _selectedWeekdays = t?.weekdays != null
        ? Set<int>.from(t!.weekdays!)
        : {1, 2, 3, 4, 5};

    _customLabelController = TextEditingController();
    _customCommandController = TextEditingController();

    if (t != null) {
      final allBuiltin =
          _builtInGroups.expand((g) => g.entries).map((e) => e.command);
      final customCmds = ref.read(customCommandsProvider);
      final allCustom = customCmds.map((c) => c.command);
      final allKnown = {...allBuiltin, ...allCustom};

      if (allKnown.contains(t.command)) {
        _isCustomCommand = false;
        _selectedCommand = _CommandEntry(t.commandLabel, t.command);
      } else {
        _isCustomCommand = true;
        _selectedCommand = null;
        _customLabelController.text = t.commandLabel;
        _customCommandController.text = t.command;
      }
    } else {
      _isCustomCommand = false;
      _selectedCommand = null;
    }
  }

  @override
  void dispose() {
    _customLabelController.dispose();
    _customCommandController.dispose();
    super.dispose();
  }

  List<_CommandGroup> _allCommandGroups() {
    final customs = ref.read(customCommandsProvider);
    return [
      ..._builtInGroups,
      if (customs.isNotEmpty)
        _CommandGroup(
          'Custom',
          customs.map((c) => _CommandEntry(c.name, c.command)).toList(),
        ),
    ];
  }

  String _autoName() {
    final cmdLabel = _isCustomCommand
        ? _customLabelController.text.trim()
        : (_selectedCommand?.label ?? 'Command');

    final targetLabel = _target == ScheduleTarget.all
        ? 'All Projectors'
        : _resolveGroupName(_targetGroupId);

    final schedPart = switch (_scheduleType) {
      ScheduleType.once => _selectedDate != null
          ? 'Once ${_fmtDate(_selectedDate!)} ${_fmtHM(_hour, _minute)}'
          : 'Once',
      ScheduleType.daily => 'Daily ${_fmtHM(_hour, _minute)}',
      ScheduleType.weekly => _selectedWeekdays.isEmpty
          ? 'Weekly ${_fmtHM(_hour, _minute)}'
          : '${(List<int>.from(_selectedWeekdays)..sort()).map((d) => _weekdayAbbr[d - 1]).join(', ')} ${_fmtHM(_hour, _minute)}',
    };

    return '$cmdLabel - $targetLabel - $schedPart';
  }

  String _resolveGroupName(String? groupId) {
    if (groupId == null) return 'Group';
    try {
      return ref
          .read(workspaceProvider.notifier)
          .groups
          .firstWhere((g) => g.id == groupId)
          .name;
    } catch (_) {
      return 'Group';
    }
  }

  void _save() {
    var valid = true;

    if (_isCustomCommand) {
      final labelEmpty = _customLabelController.text.trim().isEmpty;
      final cmdEmpty = _customCommandController.text.trim().isEmpty;
      setState(() {
        _customLabelError = labelEmpty;
        _customCommandError = cmdEmpty;
        _commandMissing = false;
      });
      if (labelEmpty || cmdEmpty) valid = false;
    } else {
      setState(() => _commandMissing = _selectedCommand == null);
      if (_selectedCommand == null) valid = false;
    }

    setState(() {
      _groupMissing =
          _target == ScheduleTarget.group && _targetGroupId == null;
      _dateMissing =
          _scheduleType == ScheduleType.once && _selectedDate == null;
      _noWeekdaysError =
          _scheduleType == ScheduleType.weekly && _selectedWeekdays.isEmpty;
    });

    if (_groupMissing || _dateMissing || _noWeekdaysError) valid = false;
    if (!valid) return;

    final cmdLabel = _isCustomCommand
        ? _customLabelController.text.trim()
        : _selectedCommand!.label;
    final cmdString = _isCustomCommand
        ? _customCommandController.text.trim()
        : _selectedCommand!.command;

    final timeOfDay =
        _scheduleType != ScheduleType.once ? _fmtHM(_hour, _minute) : null;

    final oneTimeAt = _scheduleType == ScheduleType.once
        ? DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _hour,
            _minute,
          )
        : null;

    final task = ScheduledTask(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _autoName(),
      command: cmdString,
      commandLabel: cmdLabel,
      target: _target,
      targetGroupId: _target == ScheduleTarget.group ? _targetGroupId : null,
      scheduleType: _scheduleType,
      oneTimeAt: oneTimeAt,
      timeOfDay: timeOfDay,
      weekdays: _scheduleType == ScheduleType.weekly
          ? (List<int>.from(_selectedWeekdays)..sort())
          : null,
      enabled: _scheduleType == ScheduleType.once
          ? (widget.existing?.lastRunAt != null ? true : (widget.existing?.enabled ?? true))
          : (widget.existing?.enabled ?? true),
      lastRunAt: _scheduleType == ScheduleType.once
          ? null
          : widget.existing?.lastRunAt,
    );

    final notifier = ref.read(scheduledTasksProvider.notifier);
    if (widget.existing != null) {
      notifier.update(task);
    } else {
      notifier.add(task);
    }
    Navigator.pop(context);
  }

  // ── Command dropdown (DropdownMenu — Material 3) ──────────────────────────
  //
  // Matches the _DropdownRow pattern from control_bar.dart:
  //   expandedInsets: EdgeInsets.zero → menu fills the anchor field's width
  //   enableFilter: false             → no search/filter input
  //   requestFocusOnTap: false        → standard desktop focus on click
  //   menuHeight: 300                 → capped list with auto-scroll
  //
  // Error state is communicated via a red enabledBorder + a Text widget below,
  // since DropdownMenu does not expose a FormField errorText slot.
  //
  // The final entry '__custom_inline__' triggers an AnimatedSize expansion
  // with two TextFields for entering an ad-hoc command label + raw string.

  Widget _commandDropdown() {
    final theme = Theme.of(context);
    final groups = _allCommandGroups();

    final entries = <DropdownMenuEntry<String>>[];
    for (final group in groups) {
      entries.add(DropdownMenuEntry<String>(
        value: '__grp_${group.label}',
        label: group.label.toUpperCase(),
        enabled: false,
        style: MenuItemButton.styleFrom(
          disabledForegroundColor: theme.colorScheme.primary,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ));
      for (final entry in group.entries) {
        entries.add(DropdownMenuEntry<String>(
          value: entry.command,
          label: entry.label,
        ));
      }
    }
    entries.add(DropdownMenuEntry<String>(
      value: '__grp_custom_header__',
      label: 'CUSTOM',
      enabled: false,
      style: MenuItemButton.styleFrom(
        disabledForegroundColor: theme.colorScheme.primary,
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    ));
    entries.add(DropdownMenuEntry<String>(
      value: '__custom_inline__',
      label: 'Custom Command...',
    ));

    final allCommands = groups.expand((g) => g.entries).map((e) => e.command);
    final safeValue = _isCustomCommand
        ? '__custom_inline__'
        : (allCommands.contains(_selectedCommand?.command)
            ? _selectedCommand!.command
            : null);

    final borderColor =
        _commandMissing ? theme.colorScheme.error : theme.colorScheme.outline;
    final focusBorderColor =
        _commandMissing ? theme.colorScheme.error : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownMenu<String>(
          requestFocusOnTap: false,
          enableFilter: false,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 300,
          hintText: 'Select a command...',
          initialSelection: safeValue,
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
          dropdownMenuEntries: entries,
          onSelected: (value) {
            if (value == null || value.startsWith('__grp_')) return;
            if (value == '__custom_inline__') {
              setState(() {
                _isCustomCommand = true;
                _selectedCommand = null;
                _commandMissing = false;
              });
              return;
            }
            for (final grp in groups) {
              for (final entry in grp.entries) {
                if (entry.command == value) {
                  setState(() {
                    _selectedCommand = entry;
                    _isCustomCommand = false;
                    _customLabelController.clear();
                    _customCommandController.clear();
                    _customLabelError = false;
                    _customCommandError = false;
                    _commandMissing = false;
                  });
                  return;
                }
              }
            }
          },
        ),
        if (_commandMissing)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'Select a command',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  // ── Group dropdown (DropdownMenu — Material 3) ────────────────────────────

  Widget _groupDropdown(List<ProjectorGroup> wsGroups) {
    final theme = Theme.of(context);

    final borderColor =
        _groupMissing ? theme.colorScheme.error : theme.colorScheme.outline;
    final focusBorderColor =
        _groupMissing ? theme.colorScheme.error : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownMenu<String>(
          requestFocusOnTap: false,
          enableFilter: false,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 300,
          hintText: 'Select a group...',
          initialSelection: _targetGroupId,
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
          dropdownMenuEntries: wsGroups.map((g) {
            return DropdownMenuEntry<String>(
              value: g.id,
              label: g.name,
              leadingIcon: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(g.color),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
          onSelected: (id) {
            if (id == null) return;
            setState(() {
              _targetGroupId = id;
              _groupMissing = false;
            });
          },
        ),
        if (_groupMissing)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'Select a group',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────

  static const double _labelWidth = 100;

  Widget _row(String label, Widget child, {bool alignTop = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 10.0 : 0),
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _errorText(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          msg,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    ref.watch(workspaceProvider);
    final wsGroups = ref.read(workspaceProvider.notifier).groups;
    final hasGroups = wsGroups.isNotEmpty;
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.88;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 520, maxHeight: maxDialogHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(
                isEditing ? 'Edit Task' : 'New Scheduled Task',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Command — DropdownMenu<String>, expandedInsets: zero
                    _row(
                      'Command',
                      _commandDropdown(),
                      alignTop: _commandMissing,
                    ),

                    // Custom Command inline fields — top-level so labels align
                    // with the rest of the form's _labelWidth column.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _isCustomCommand
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row(
                                  'Name',
                                  TextField(
                                    controller: _customLabelController,
                                    decoration: InputDecoration(
                                      hintText: 'Command name',
                                      hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.35),
                                      ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      errorText: _customLabelError
                                          ? 'Name is required'
                                          : null,
                                      errorStyle: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_customLabelError) {
                                        setState(
                                            () => _customLabelError = false);
                                      }
                                    },
                                  ),
                                  alignTop: _customLabelError,
                                ),
                                _row(
                                  'String',
                                  TextField(
                                    controller: _customCommandController,
                                    decoration: InputDecoration(
                                      hintText: 'Command string',
                                      hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.35),
                                      ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      errorText: _customCommandError
                                          ? 'Command is required'
                                          : null,
                                      errorStyle: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_customCommandError) {
                                        setState(
                                            () => _customCommandError = false);
                                      }
                                    },
                                  ),
                                  alignTop: _customCommandError,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Target
                    _row(
                      'Target',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ChoicePill(
                                label: 'All Projectors',
                                selected: _target == ScheduleTarget.all,
                                onTap: () => setState(() {
                                  _target = ScheduleTarget.all;
                                  _groupMissing = false;
                                }),
                              ),
                              const SizedBox(width: 8),
                              _ChoicePill(
                                label: 'Specific Group',
                                selected: _target == ScheduleTarget.group,
                                enabled: hasGroups,
                                tooltip: !hasGroups
                                    ? 'No groups in this project'
                                    : null,
                                onTap: hasGroups
                                    ? () => setState(() {
                                          _target = ScheduleTarget.group;
                                          _groupMissing = false;
                                        })
                                    : null,
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Visibility(
                              visible: _target == ScheduleTarget.group,
                              maintainState: true,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _groupDropdown(wsGroups),
                              ),
                            ),
                          ),
                        ],
                      ),
                      alignTop: true,
                    ),

                    // Schedule type
                    _row(
                      'Schedule',
                      SegmentedButton<ScheduleType>(
                        segments: const [
                          ButtonSegment(
                            value: ScheduleType.once,
                            label: Text('Once'),
                          ),
                          ButtonSegment(
                            value: ScheduleType.daily,
                            label: Text('Daily'),
                          ),
                          ButtonSegment(
                            value: ScheduleType.weekly,
                            label: Text('Weekly'),
                          ),
                        ],
                        selected: {_scheduleType},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() {
                          _scheduleType = s.first;
                          _dateMissing = false;
                          _noWeekdaysError = false;
                        }),
                      ),
                    ),

                    // Time — static row, never shifts regardless of schedule type
                    _row(
                      'Time',
                      Row(
                        children: [
                          _TimeField(
                            initialValue: _hour,
                            max: 23,
                            label: 'HH',
                            onChanged: (v) => setState(() => _hour = v),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          _TimeField(
                            initialValue: _minute,
                            max: 59,
                            label: 'MM',
                            onChanged: (v) => setState(() => _minute = v),
                          ),
                        ],
                      ),
                    ),

                    // Dynamic section — fixed minHeight so footer stays put
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date (Once only)
                          if (_scheduleType == ScheduleType.once)
                            _row(
                              'Date',
                              _HybridDateField(
                                value: _selectedDate,
                                hasError: _dateMissing,
                                onPicked: (dt) => setState(() {
                                  _selectedDate = dt;
                                  _dateMissing = false;
                                }),
                              ),
                              alignTop: _dateMissing,
                            ),

                          // Days (Weekly only)
                          if (_scheduleType == ScheduleType.weekly)
                            _row(
                              'Days',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(7, (i) {
                                      final day = i + 1;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                            right: i < 6 ? 5 : 0),
                                        child: _DayButton(
                                          label: _weekdayAbbr[i],
                                          selected: _selectedWeekdays
                                              .contains(day),
                                          onTap: () => setState(() {
                                            if (_selectedWeekdays
                                                .contains(day)) {
                                              _selectedWeekdays.remove(day);
                                            } else {
                                              _selectedWeekdays.add(day);
                                            }
                                            _noWeekdaysError =
                                                _selectedWeekdays.isEmpty;
                                          }),
                                        ),
                                      );
                                    }),
                                  ),
                                  if (_noWeekdaysError)
                                    _errorText('Select at least one day'),
                                ],
                              ),
                              alignTop: true,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Save Task'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hybrid date field
//
// Uses OverlayPortal for lifecycle-safe overlay management.
// CalendarDatePicker is wrapped in TooltipVisibility(visible: false) to
// suppress the internal Tooltip widgets on the month-navigation arrows.
// Those tooltips trigger markNeedsLayout during the paint phase, which causes
// RenderFollowerLayer assertions. Disabling tooltip visibility eliminates
// the source of that paint-phase layout request entirely.
// ─────────────────────────────────────────────────────────────────────────────

class _HybridDateField extends StatefulWidget {
  final DateTime? value;
  final bool hasError;
  final void Function(DateTime) onPicked;

  const _HybridDateField({
    required this.value,
    required this.onPicked,
    this.hasError = false,
  });

  @override
  State<_HybridDateField> createState() => _HybridDateFieldState();
}

class _HybridDateFieldState extends State<_HybridDateField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  final _portalController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  bool _openUpward = false;

  static String _toDisplay(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.year}';

  static DateTime? _parse(String text) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (m == null || d == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000) return null;
    try {
      final dt = DateTime(y, m, d);
      if (dt.month != m || dt.day != d) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  DateTime _clampedInitial() {
    final first = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final last = DateTime.now().add(const Duration(days: 365 * 5));
    final date = widget.value ?? DateTime.now();
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value != null ? _toDisplay(widget.value!) : '',
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_HybridDateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        widget.value != null &&
        !_focusNode.hasFocus) {
      _ctrl.text = _toDisplay(widget.value!);
    }
  }

  @override
  void dispose() {
    // OverlayPortal tears down its overlay child automatically when this
    // widget is disposed — no manual removal or setState call needed.
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    if (_portalController.isShowing) {
      _portalController.hide();
    } else {
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        final bottom = ro.localToGlobal(Offset(0, ro.size.height));
        _openUpward =
            (MediaQuery.of(context).size.height - bottom.dy) < 340.0;
      }
      _portalController.show();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = _portalController.isShowing;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (ctx) => Stack(
          children: [
            // Dismiss barrier
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _portalController.hide();
                  setState(() {});
                },
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Calendar panel
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: _openUpward
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: _openUpward
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset:
                  _openUpward ? const Offset(0, -4) : const Offset(0, 4),
              showWhenUnlinked: false,
              child: RepaintBoundary(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: SizedBox(
                    width: 300,
                    // TooltipVisibility(visible: false) suppresses the
                    // internal Tooltip widgets on CalendarDatePicker's month
                    // navigation arrows. Those tooltips call markNeedsLayout
                    // during the paint phase, triggering RenderFollowerLayer
                    // assertions. This is the definitive fix.
                    child: TooltipVisibility(
                      visible: false,
                      child: CalendarDatePicker(
                        initialDate: _clampedInitial(),
                        firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                        onDateChanged: (dt) {
                          widget.onPicked(dt);
                          _ctrl.text = _toDisplay(dt);
                          _portalController.hide();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [_DateInputFormatter()],
          decoration: InputDecoration(
            hintText: 'MM/DD/YYYY',
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: widget.hasError ? 'Please enter a date' : null,
            errorStyle: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.error,
            ),
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: isOpen
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: _toggleCalendar,
              ),
            ),
          ),
          onChanged: (text) {
            final dt = _parse(text);
            if (dt != null) widget.onPicked(dt);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date input formatter — auto-inserts slashes for MM/DD/YYYY
// ─────────────────────────────────────────────────────────────────────────────

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final digits = value.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    final count = digits.length.clamp(0, 8);
    for (int i = 0; i < count; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day toggle button — fixed 40×40, border/fill selection state
// ─────────────────────────────────────────────────────────────────────────────

class _DayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? primary
                  : theme.colorScheme.outline.withValues(alpha: 0.45),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice pill — All Projectors / Specific Group selector
// ─────────────────────────────────────────────────────────────────────────────

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ChoicePill({
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final active = enabled && onTap != null;

    Widget pill = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected && active
            ? primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected && active
              ? primary
              : theme.colorScheme.outline
                  .withValues(alpha: active ? 0.55 : 0.25),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: !active
              ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
              : selected
                  ? primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );

    if (tooltip != null) {
      pill = Tooltip(message: tooltip!, child: pill);
    }

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: pill,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time text field — typed HH or MM with clamp on focus-lost
// ─────────────────────────────────────────────────────────────────────────────

class _TimeField extends StatefulWidget {
  final int initialValue;
  final int max;
  final String label;
  final ValueChanged<int> onChanged;

  const _TimeField({
    required this.initialValue,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toString().padLeft(2, '0'),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TimeField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue.toString().padLeft(2, '0');
    }
  }

  void _commit() {
    final v = int.tryParse(_controller.text.trim()) ?? 0;
    final clamped = v.clamp(0, widget.max);
    _controller.text = clamped.toString().padLeft(2, '0');
    widget.onChanged(clamped);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          counterText: '',
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
