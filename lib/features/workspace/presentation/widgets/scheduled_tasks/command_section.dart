import 'package:flutter/material.dart';

import '../../../domain/scheduled_commands.dart';
import '../../../domain/task_draft.dart';
import '../common/dialog_parts.dart';
import 'command_field.dart';
import 'command_picker.dart';
import 'task_parts.dart';

const _panelDuration = Duration(milliseconds: 200);

/// Section 1: the command field, the picker panel that opens under it, and
/// the Name + Command string fields of a typed command. The panel grows
/// inside the editor (the editor body scrolls), not over it.
class CommandSection extends StatefulWidget {
  const CommandSection({
    super.key,
    required this.draft,
    required this.catalog,
    required this.errors,
    required this.onChanged,
  });

  final TaskDraft draft;
  final List<ScheduledCommand> catalog;

  /// The draft's errors to show (empty until the first save attempt).
  final Set<DraftError> errors;
  final DraftEdit onChanged;

  @override
  State<CommandSection> createState() => _CommandSectionState();
}

class _CommandSectionState extends State<CommandSection> {
  late final _name = TextEditingController(text: widget.draft.stringName);
  late final _string = TextEditingController(text: widget.draft.stringCommand);
  final _nameFocus = FocusNode();
  bool _open = false;

  @override
  void dispose() {
    _name.dispose();
    _string.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _pick(ScheduledCommand c) {
    setState(() => _open = false);
    widget.onChanged((d) => d.copyWith(command: c, useCommandString: false));
  }

  void _useString() {
    setState(() => _open = false);
    widget.onChanged((d) => d.copyWith(useCommandString: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final errors = widget.errors;
    final nameError = errors.contains(DraftError.commandName);
    final stringError = errors.contains(DraftError.commandString);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskSectionHeader(
          number: 1,
          label: 'Command',
          error:
              errors.contains(DraftError.command) || nameError || stringError,
        ),
        const SizedBox(height: 10),
        CommandField(
          command: draft.command,
          useCommandString: draft.useCommandString,
          open: _open,
          error: errors.contains(DraftError.command),
          onTap: () => setState(() => _open = !_open),
        ),
        AnimatedSize(
          duration: _panelDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CommandPicker(
                    catalog: widget.catalog,
                    selected: draft.useCommandString ? null : draft.command,
                    onPick: _pick,
                    onCommandString: _useString,
                    onClose: () => setState(() => _open = false),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedSize(
          duration: _panelDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: draft.useCommandString
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Name',
                          error: nameError,
                          // The error takes the help line's place, so the
                          // row keeps its height.
                          help: FieldHelp(
                            nameError ? DraftError.commandName.message : '',
                            tone: nameError
                                ? FieldHelpTone.error
                                : FieldHelpTone.muted,
                          ),
                          child: TextField(
                            key: const ValueKey('command-string-name'),
                            controller: _name,
                            focusNode: _nameFocus,
                            style: plainFieldStyle,
                            decoration: dialogFieldDecoration(
                              context,
                              error: nameError,
                            ),
                            onChanged: (v) => widget.onChanged(
                              (d) => d.copyWith(stringName: v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Command string',
                          error: stringError,
                          help: FieldHelp(
                            stringError ? DraftError.commandString.message : '',
                            tone: stringError
                                ? FieldHelpTone.error
                                : FieldHelpTone.muted,
                          ),
                          child: TextField(
                            key: const ValueKey('command-string-value'),
                            controller: _string,
                            style: monoFieldStyle,
                            decoration: dialogFieldDecoration(
                              context,
                              hintText: 'OSH:1',
                              error: stringError,
                            ),
                            onChanged: (v) => widget.onChanged(
                              (d) => d.copyWith(stringCommand: v),
                            ),
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
