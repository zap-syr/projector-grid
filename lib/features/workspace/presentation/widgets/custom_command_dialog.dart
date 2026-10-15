import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/custom_command.dart';
import '../providers/custom_commands_provider.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                      _Field(
                        label: 'Name',
                        help:
                            'Shown on the button and used for the OSC address',
                        error: takenBy == null
                            ? null
                            : 'Another command already has this OSC address',
                        child: TextField(
                          controller: _nameCtrl,
                          autofocus: true,
                          decoration: _decoration(
                            context,
                            hint: 'e.g. Dynamic contrast',
                            error: takenBy != null,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _isValid ? _submit() : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: 'Command',
                        help: 'Sent as is to the selected projectors, in NTCONTROL form',
                        child: TextField(
                          controller: _cmdCtrl,
                          style: AppTheme.mono(
                            theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                          decoration: _decoration(
                            context,
                            hint: 'OSH:1',
                            error: false,
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: isEdit
                          // A show controller still pointing at the old
                          // address stops working after a rename.
                          ? Text(
                              'Renaming changes the OSC address',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                color: cs.onSurfaceVariant,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    if (isEdit)
                      FilledButton(
                        onPressed: _isValid ? _submit : null,
                        child: const Text('Save'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _isValid ? _submit : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add command'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    required bool error,
  }) {
    final cs = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerLowest,
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: error ? border(cs.error, 2) : border(cs.outline, 1),
      focusedBorder: error ? border(cs.error, 2) : border(cs.primary, 2),
    );
  }
}

/// A label above a field and one help line under it. The error replaces the
/// help line rather than adding one, so the dialog never changes height.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.help,
    required this.child,
    this.error,
  });

  final String label;
  final String help;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: hasError ? cs.error : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Row(
            children: [
              if (hasError) ...[
                Icon(Icons.error_outline, size: 14, color: cs.error),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  error ?? help,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasError ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
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
