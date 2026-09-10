import 'package:flutter/material.dart';

import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import 'preview_viewport.dart';

/// Opens the Remote Preview dialog for [nodes] — one projector shows a single
/// viewport, several show a grid (§5.2 of REMOTE_PREVIEW_PLAN.md). Modal for
/// now; the same body moves into a real OS window once Flutter's windowing API
/// stabilises (§5.3).
void showRemotePreviewDialog(
  BuildContext context,
  List<ProjectorNode> nodes, {
  Map<String, ProjectorGroup> groups = const {},
}) {
  if (nodes.isEmpty) return;
  showDialog<void>(
    context: context,
    builder: (_) => RemotePreviewDialog(nodes: nodes, groups: groups),
  );
}

class RemotePreviewDialog extends StatelessWidget {
  const RemotePreviewDialog({
    super.key,
    required this.nodes,
    this.groups = const {},
  });

  final List<ProjectorNode> nodes;
  final Map<String, ProjectorGroup> groups;

  bool get _isMulti => nodes.length > 1;

  ProjectorGroup? _groupOf(ProjectorNode n) =>
      n.groupId != null ? groups[n.groupId] : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(16),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Text(_title(), style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
        ],
      ),
      content: _isMulti ? _grid() : _single(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _title() {
    if (_isMulti) return 'Remote Preview — ${nodes.length} projectors';
    final n = nodes.first;
    final group = _groupOf(n);
    final tail = group != null ? ' · ${group.name}' : '';
    return 'Remote Preview — ${n.name} · ${n.ipAddress}$tail';
  }

  Widget _single() => SizedBox(
    width: 640,
    child: PreviewViewport(node: nodes.first, group: _groupOf(nodes.first)),
  );

  Widget _grid() {
    // 2 up to four projectors, 3 beyond; more than two rows scrolls.
    final cols = nodes.length <= 4 ? 2 : 3;
    const cell = 300.0;
    const spacing = 8.0;
    final rows = (nodes.length / cols).ceil().clamp(1, 2);
    // 16:9 plane + caption strip.
    final cellHeight = cell * 9 / 16 + 28;

    return SizedBox(
      width: cols * cell + (cols - 1) * spacing,
      height: rows * cellHeight + (rows - 1) * spacing,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: cell / cellHeight,
        ),
        itemCount: nodes.length,
        itemBuilder: (_, i) => PreviewViewport(
          node: nodes[i],
          group: _groupOf(nodes[i]),
          showCaption: true,
        ),
      ),
    );
  }
}
