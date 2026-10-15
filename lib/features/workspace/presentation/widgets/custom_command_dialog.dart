import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/custom_command.dart';
import '../providers/custom_commands_provider.dart';
import 'common/dialog_parts.dart';
import 'common/scroll_fade.dart';
import 'dialog_title_bar.dart';

class CustomCommandDialog extends ConsumerStatefulWidget {
  final CustomCommand? existing; // null = add mode

  const CustomCommandDialog({super.key, this.existing});

  @override
  ConsumerState<CustomCommandDialog> createState() =>
      _CustomCommandDialogState();
}

class _CustomCommandDialogState extends ConsumerState<CustomCommandDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cmdCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _cmdCtrl = TextEditingController(text: widget.existing?.command ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    super.dispose();
  }

  String get _slug => CustomCommand.slugOf(_nameCtrl.text);

  /// The other command that already answers on this name's OSC address.
  /// Compared by slug, not name: two different names can share an address.
  CustomCommand? get _takenBy {
    if (_nameCtrl.text.trim().isEmpty) return null;
    final slug = _slug;
    for (final c in ref.read(customCommandsProvider)) {
      if (c.oscSlug == slug &&
          (widget.existing == null || c.id != widget.existing!.id)) {
        return c;
      }
    }
    return null;
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _cmdCtrl.text.trim().isNotEmpty &&
      _takenBy == null;

  void _submit() {
    final notifier = ref.read(customCommandsProvider.notifier);
    final ok = widget.existing == null
        ? notifier.add(_nameCtrl.text, _cmdCtrl.text)
        : notifier.update(widget.existing!.id, _nameCtrl.text, _cmdCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final takenBy = _takenBy;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogTitleBar(
              icon: Icons.code,
              title: isEdit ? 'Edit Command' : 'Add Command',
            ),
            Flexible(
              child: ScrollFade(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The error replaces the help line rather than adding
                      // one, so the dialog never changes height.
                      LabeledField(
                        label: 'Name',
                        error: takenBy != null,
                        help: takenBy == null
                            ? const FieldHelp(
                                'Shown on the button and used for the OSC '
                                'address',
                              )
                            : const FieldHelp(
                                'Another command already has this OSC address',
                                tone: FieldHelpTone.error,
                              ),
                        child: TextField(
                          controller: _nameCtrl,
                          autofocus: true,
                          style: plainFieldStyle,
                          decoration: dialogFieldDecoration(
                            context,
                            hintText: 'e.g. Dynamic contrast',
                            error: takenBy != null,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _isValid ? _submit() : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Command',
                        help: const FieldHelp(
                          'Sent as is to the selected projectors, in '
                          'NTCONTROL form',
                        ),
                        child: TextField(
                          controller: _cmdCtrl,
                          style: monoFieldStyle,
                          decoration: dialogFieldDecoration(
                            context,
                            hintText: 'OSH:1',
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _isValid ? _submit() : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _OscAddressesCard(slug: _slug, takenBy: takenBy),
                    ],
                  ),
                ),
              ),
            ),
            DialogFooter(
              // A show controller still pointing at the old address stops
              // working after a rename.
              message: isEdit
                  ? const Text('Renaming changes the OSC address')
                  : null,
              actionLabel: isEdit ? 'Save' : 'Add command',
              actionIcon: isEdit ? null : Icons.add,
              onAction: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The two addresses OSC accepts for this command, always at full height so
/// nothing moves while the name is typed.
class _OscAddressesCard extends StatelessWidget {
  const _OscAddressesCard({required this.slug, required this.takenBy});

  final String slug;
  final CustomCommand? takenBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final taken = takenBy != null;
    final muted = cs.onSurfaceVariant.withValues(alpha: 0.6);
    final addressStyle = AppTheme.mono(
      TextStyle(
        fontSize: 12.5,
        color: taken ? muted : cs.onSurface,
        decoration: taken ? TextDecoration.lineThrough : null,
        decorationColor: muted,
      ),
    );

    Widget address(List<InlineSpan> spans) => Text.rich(
      slug.isEmpty
          ? TextSpan(
              text: 'Type a name to get the address',
              style: TextStyle(color: muted),
            )
          : TextSpan(children: spans),
      style: addressStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    Widget row(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        value,
      ],
    );

    return DialogCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'OSC addresses',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  taken ? 'Taken by "${takenBy!.name}"' : 'Follow the name',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: taken ? cs.error : muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(
            'All projectors',
            address([TextSpan(text: '/pgrid/all/custom/$slug')]),
          ),
          const SizedBox(height: 8),
          row(
            'One group',
            address([
              const TextSpan(text: '/pgrid/group/'),
              TextSpan(
                text: '{group-name}',
                style: taken ? null : TextStyle(color: cs.primary),
              ),
              TextSpan(text: '/custom/$slug'),
            ]),
          ),
        ],
      ),
    );
  }
}
