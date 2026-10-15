import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_group.dart';
import '../providers/workspace_provider.dart';
import 'common/dialog_parts.dart';
import 'common/scroll_fade.dart';
import 'dialog_title_bar.dart';
import 'groups/group_row.dart';
import 'groups/new_group_card.dart';

export 'groups/new_group_dialog.dart' show showNewGroupDialog;

/// Manage Groups: a summary line with *New group*, the New group form when
/// open, and one card with a row per group that edits in place.
class ManageGroupsDialog extends ConsumerStatefulWidget {
  const ManageGroupsDialog({super.key});

  @override
  ConsumerState<ManageGroupsDialog> createState() => _ManageGroupsDialogState();
}

class _ManageGroupsDialogState extends ConsumerState<ManageGroupsDialog>
    with SingleTickerProviderStateMixin {
  late final _newForm = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _newFormCurve = CurvedAnimation(
    parent: _newForm,
    curve: Curves.easeOut,
  );
  final _scroll = ScrollController();

  /// The form stays built while it collapses; [_newClosing] keeps it from
  /// taking a second click meanwhile.
  bool _newOpen = false;
  bool _newClosing = false;

  /// A fresh form (empty name, next unused colour) each time it opens.
  int _newFormGeneration = 0;
  String? _editingId;
  String? _highlightId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _newFormCurve.dispose();
    _newForm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openNewForm() {
    setState(() {
      _newOpen = true;
      _newClosing = false;
      _newFormGeneration++;
    });
    _newForm.forward(from: 0);
  }

  Future<void> _closeNewForm() async {
    setState(() => _newClosing = true);
    await _newForm.reverse();
    if (!mounted) return;
    setState(() {
      _newOpen = false;
      _newClosing = false;
    });
  }

  void _onCreated(ProjectorGroup group) {
    _highlightTimer?.cancel();
    setState(() => _highlightId = group.id);
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _highlightId = null);
    });
    _closeNewForm();
    // New groups go to the end of the list, which may be scrolled away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groups = ref.watch(workspaceProvider.notifier).groups;
    final nodes = ref.watch(workspaceProvider);
    final counts = <String, int>{};
    for (final n in nodes) {
      final id = n.groupId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    final groupIds = {for (final g in groups) g.id};
    final assigned = nodes.where((n) => groupIds.contains(n.groupId)).length;
    final summary =
        '${groups.length} group${groups.length == 1 ? '' : 's'}, '
        '$assigned of ${nodes.length} '
        'projector${nodes.length == 1 ? '' : 's'} assigned';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DialogTitleBar(icon: Icons.layers, title: 'Manage Groups'),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _newOpen ? null : _openNewForm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New group'),
                    ),
                  ],
                ),
              ),
              // Above the scrolling list so the form can't scroll away.
              if (_newOpen)
                FadeTransition(
                  opacity: _newFormCurve,
                  child: SizeTransition(
                    sizeFactor: _newFormCurve,
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      ignoring: _newClosing,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: NewGroupCard(
                          key: ValueKey(_newFormGeneration),
                          onCancel: _closeNewForm,
                          onCreated: _onCreated,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: groups.isEmpty
                    ? (_newOpen ? const SizedBox.shrink() : const _EmptyState())
                    : ScrollFade(
                        child: Scrollbar(
                          controller: _scroll,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: DialogCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, g) in groups.indexed)
                                    GroupRow(
                                      key: ValueKey(g.id),
                                      group: g,
                                      first: i == 0,
                                      memberCount: counts[g.id] ?? 0,
                                      expanded: _editingId == g.id,
                                      highlighted: _highlightId == g.id,
                                      onToggle: () => setState(
                                        () => _editingId = _editingId == g.id
                                            ? null
                                            : g.id,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 40, color: muted),
            const SizedBox(height: 12),
            Text('No groups yet', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Create one, then assign projectors via the grid',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
