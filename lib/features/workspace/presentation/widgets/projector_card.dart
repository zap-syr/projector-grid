import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';

class ProjectorCard extends StatelessWidget {
  final ProjectorNode node;
  final double zoom;
  final VoidCallback onTap;
  final GestureDragDownCallback onPanDown;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onColorCorrection;

  const ProjectorCard({
    super.key,
    required this.node,
    required this.zoom,
    required this.onTap,
    required this.onPanDown,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onEdit,
    required this.onDelete,
    required this.onColorCorrection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Status colors
    final powerColor = node.powerStatus == PowerStatus.on ? Colors.green : Colors.red;
    final shutterColor = node.shutterStatus == ShutterStatus.open ? Colors.green : Colors.red;
    final connectionColor = node.connectionStatus == ConnectionStatus.connected ? Colors.green : Colors.red;

    return Positioned(
      left: node.x * zoom,
      top: node.y * zoom,
      child: Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: onTap,
          onPanDown: onPanDown,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onSecondaryTapDown: (details) {
            showMenu(
              context: context,
              position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy,
                details.globalPosition.dx,
                details.globalPosition.dy,
              ),
              items: const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'color', child: Text('Color Correction')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ).then((value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
              if (value == 'color') onColorCorrection();
            });
          },
          child: Container(
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
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: Row(
                    children: [
                      // Top left: Power and Shutter
                      Icon(Icons.power_settings_new, size: 14, color: powerColor),
                      const SizedBox(width: 4),
                      Icon(Icons.visibility, size: 14, color: shutterColor),
                      const Spacer(),
                      // Top right: Connection
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
        ),
      ),
    );
  }
}
