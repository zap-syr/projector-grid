import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';

class ProjectorCard extends StatefulWidget {
  final ProjectorNode node;
  final ProjectorGroup? group;
  final double zoom;
  final VoidCallback onTap;
  final GestureDragDownCallback onPanDown;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onColorCorrection;
  final VoidCallback onBrightnessControl;
  final List<Widget> Function() buildGroupMenuItems;

  const ProjectorCard({
    super.key,
    required this.node,
    this.group,
    required this.zoom,
    required this.onTap,
    required this.onPanDown,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onEdit,
    required this.onDelete,
    required this.onColorCorrection,
    required this.onBrightnessControl,
    required this.buildGroupMenuItems,
  });

  @override
  State<ProjectorCard> createState() => _ProjectorCardState();
}

class _ProjectorCardState extends State<ProjectorCard> {
  final _menuController = MenuController();

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

    // Status colors
    final powerColor = node.powerStatus == PowerStatus.on ? Colors.green : Colors.red;
    final shutterColor = node.shutterStatus == ShutterStatus.open ? Colors.green : Colors.red;
    final connectionColor = switch (node.connectionStatus) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.unauthorized => Colors.amber,
      ConnectionStatus.offline => Colors.red,
    };

    return Positioned(
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
          child: GestureDetector(
            onTap: widget.onTap,
            onPanDown: widget.onPanDown,
            onPanUpdate: widget.onPanUpdate,
            onPanEnd: widget.onPanEnd,
            onSecondaryTapUp: (details) {
              _menuController.open(position: details.localPosition * widget.zoom);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 100,
                  padding: EdgeInsets.all(node.isSelected ? 0 : 1),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: node.isSelected ? colorScheme.primary : theme.dividerColor,
                      width: node.isSelected ? 2 : 1,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.power_settings_new, size: 14, color: powerColor),
                                const SizedBox(width: 4),
                                Icon(Icons.visibility, size: 14, color: shutterColor),
                                const SizedBox(width: 4),
                                if (node.errors != 'NO ERRORS' && node.errors != '-')
                                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                                const Spacer(),
                                if (node.connectionStatus == ConnectionStatus.unauthorized)
                                  const Icon(Icons.lock_outline, size: 12, color: Colors.amber),
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
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Content area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                        child: Text(
                          node.ipAddress,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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
    );
  }
}
