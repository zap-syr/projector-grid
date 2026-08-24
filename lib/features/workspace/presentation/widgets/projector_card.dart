import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import '../providers/selection_provider.dart';

class ProjectorCard extends ConsumerStatefulWidget {
  final ProjectorNode node;
  final ProjectorGroup? group;
  final bool isDragging;
  final double zoom;
  final VoidCallback onTap;
  final GestureDragDownCallback onPanDown;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onColorCorrection;
  final VoidCallback onBrightnessControl;
  final VoidCallback onGeometryCorrection;
  final VoidCallback? onSelectGroup;
  final List<Widget> Function() buildGroupMenuItems;

  const ProjectorCard({
    super.key,
    required this.node,
    this.group,
    required this.isDragging,
    required this.zoom,
    required this.onTap,
    required this.onPanDown,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onEdit,
    required this.onDelete,
    required this.onColorCorrection,
    required this.onBrightnessControl,
    required this.onGeometryCorrection,
    required this.onSelectGroup,
    required this.buildGroupMenuItems,
  });

  @override
  ConsumerState<ProjectorCard> createState() => _ProjectorCardState();
}

class _ProjectorCardState extends ConsumerState<ProjectorCard> {
  final _menuController = MenuController();
  bool _isHovered = false;
  double? _lastZoom;

  void _closeAndRun(VoidCallback action) {
    _menuController.close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final group = widget.group;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = ref.watch(
      selectionProvider.select((ids) => ids.contains(node.id)),
    );

    // Status colors
    final powerColor = node.powerStatus == PowerStatus.on
        ? Colors.green
        : Colors.red;
    final shutterColor = node.shutterStatus == ShutterStatus.open
        ? Colors.green
        : Colors.red;
    final connectionColor = switch (node.connectionStatus) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.unprotected => Colors.green,
      ConnectionStatus.unauthorized => Colors.amber,
      ConnectionStatus.offline => Colors.red,
    };

    // Zoom changes rescale left/top just like a real position change would,
    // but should snap instantly rather than ease like an actual drag-snap
    // correction — otherwise every card visibly "jumps" on every zoom step.
    final zoomChanged = widget.zoom != _lastZoom;
    _lastZoom = widget.zoom;

    return AnimatedPositioned(
      duration: (widget.isDragging || zoomChanged)
          ? Duration.zero
          : const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      left: node.x * widget.zoom,
      top: node.y * widget.zoom,
      child: Transform.scale(
        scale: widget.zoom,
        alignment: Alignment.topLeft,
        child: MenuAnchor(
          controller: _menuController,
          consumeOutsideTap: true,
          menuChildren: [
            MenuItemButton(
              onPressed: () => _closeAndRun(widget.onEdit),
              leadingIcon: const Icon(Icons.edit_outlined),
              child: const Text('Edit'),
            ),
            MenuItemButton(
              onPressed: () => _closeAndRun(widget.onBrightnessControl),
              leadingIcon: const Icon(Icons.brightness_6),
              child: const Text('Brightness Control'),
            ),
            MenuItemButton(
              onPressed: () => _closeAndRun(widget.onColorCorrection),
              leadingIcon: const Icon(Icons.tune),
              child: const Text('Color Correction'),
            ),
            MenuItemButton(
              onPressed: () => _closeAndRun(widget.onGeometryCorrection),
              leadingIcon: const Icon(Icons.grid_4x4_outlined),
              child: const Text('Geometry Correction'),
            ),
            MenuItemButton(
              onPressed: () => _closeAndRun(() {
                final url = 'http://${node.ipAddress}';
                if (Platform.isWindows) {
                  Process.run('cmd', ['/c', 'start', url]);
                } else if (Platform.isMacOS) {
                  Process.run('open', [url]);
                } else if (Platform.isLinux) {
                  Process.run('xdg-open', [url]);
                }
              }),
              leadingIcon: const Icon(Icons.open_in_browser),
              child: const Text('Open in Browser'),
            ),
            const Divider(height: 1),
            MenuItemButton(
              onPressed: widget.onSelectGroup != null
                  ? () => _closeAndRun(widget.onSelectGroup!)
                  : null,
              leadingIcon: const Icon(Icons.select_all),
              child: const Text('Select in Group'),
            ),
            SubmenuButton(
              menuChildren: widget.buildGroupMenuItems(),
              leadingIcon: const Icon(Icons.workspaces_outlined),
              child: const Text('Assign to Group'),
            ),
            const Divider(height: 1),
            MenuItemButton(
              onPressed: () => _closeAndRun(widget.onDelete),
              leadingIcon: Builder(
                builder: (context) => Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              child: Builder(
                builder: (context) => Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              onPanDown: widget.onPanDown,
              onPanUpdate: widget.onPanUpdate,
              onPanEnd: widget.onPanEnd,
              onSecondaryTapUp: (details) {
                _menuController.open(
                  position: details.localPosition * widget.zoom,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 120,
                    height: 100,
                    padding: EdgeInsets.all(isSelected ? 0 : 1),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : (_isHovered
                                  ? colorScheme.primary.withValues(alpha: 0.85)
                                  : colorScheme.outline),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar with optional group color stripe overlaid
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.power_settings_new,
                                    size: 14,
                                    color: powerColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.visibility,
                                    size: 14,
                                    color: shutterColor,
                                  ),
                                  const SizedBox(width: 4),
                                  if (node.errors != 'NO ERRORS' &&
                                      node.errors != '-')
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                  const Spacer(),
                                  if (node.connectionStatus ==
                                      ConnectionStatus.unauthorized)
                                    const Icon(
                                      Icons.lock_outline,
                                      size: 12,
                                      color: Colors.amber,
                                    ),
                                  if (node.connectionStatus ==
                                      ConnectionStatus.unprotected)
                                    const Icon(
                                      Icons.lock_open,
                                      size: 12,
                                      color: Colors.blue,
                                    ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: connectionColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Group color stripe overlay
                            if (group != null)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Color(group.color),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(7),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        // Content area
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Text(
                            node.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            right: 8.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            node.ipAddress,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Group label
                  if (group != null)
                    SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          group.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Color(group.color),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
