import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/custom_command.dart';
import '../providers/custom_commands_provider.dart';

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

  String get _slug => _nameCtrl.text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  bool get _isDuplicate {
    if (_nameCtrl.text.trim().isEmpty) return false;
    final commands = ref.read(customCommandsProvider);
    return commands.any((c) =>
        c.oscSlug == _slug &&
        (widget.existing == null || c.id != widget.existing!.id));
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _cmdCtrl.text.trim().isNotEmpty &&
      !_isDuplicate;

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
    final slug = _slug;
    final title = widget.existing == null ? 'Add Command' : 'Edit Command';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title bar ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: _isDuplicate ? 'Name already used' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    autofocus: true,
                    onSubmitted: (_) => _isValid ? _submit() : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cmdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Command',
                      hintText: 'e.g. PON, OSH:1, VXX:LNSI1=+00001',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _isValid ? _submit() : null,
                  ),
                  const SizedBox(height: 20),
                  // Fixed-height OSC address preview — always rendered
                  // to keep dialog size stable while the user types.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_ethernet,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            slug.isNotEmpty
                                ? '/pgrid/all/custom/$slug'
                                : 'OSC address will appear here',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: slug.isNotEmpty
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: _isValid ? _submit : null,
                        child: Text(
                          widget.existing == null ? 'Add' : 'Save',
                        ),
                      ),
                    ],
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
