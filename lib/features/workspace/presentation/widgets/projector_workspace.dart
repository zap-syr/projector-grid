import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import 'projector_card.dart';

class SelectAllIntent extends Intent { const SelectAllIntent(); }
class DeselectAllIntent extends Intent { const DeselectAllIntent(); }

class ProjectorWorkspace extends ConsumerStatefulWidget {
  const ProjectorWorkspace({super.key});

  @override
  ConsumerState<ProjectorWorkspace> createState() => _ProjectorWorkspaceState();
}

class _ProjectorWorkspaceState extends ConsumerState<ProjectorWorkspace> {
  Offset? _selectionStart;
  Offset? _selectionCurrent;
  
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  
  final double _gridStep = 20.0;
  final double _workspaceWidth = 3000.0;
  final double _workspaceHeight = 3000.0;
  double _currentZoom = 1.0;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) {
    setState(() {
      _currentZoom = zoom.clamp(0.5, 2.0);
    });
  }

  bool get _isMultiSelect {
    return HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) => k == LogicalKeyboardKey.controlLeft || k == LogicalKeyboardKey.controlRight || k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);

    return Stack(
      children: [
        // The Scrollable Workspace
        Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): const SelectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA): const SelectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD): const DeselectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD): const DeselectAllIntent(),
          },
          child: Actions(
            actions: {
              SelectAllIntent: CallbackAction<SelectAllIntent>(onInvoke: (intent) => notifier.selectAll()),
              DeselectAllIntent: CallbackAction<DeselectAllIntent>(onInvoke: (intent) => notifier.deselectAll()),
            },
            child: Focus(
              autofocus: true,
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: GestureDetector(
                        onTap: () {
                          notifier.deselectAll();
                        },
                        onPanStart: (details) {
                          setState(() {
                            _selectionStart = details.localPosition / _currentZoom;
                            _selectionCurrent = details.localPosition / _currentZoom;
                          });
                          notifier.startMarqueeSelection(append: _isMultiSelect);
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _selectionCurrent = details.localPosition / _currentZoom;
                          });
                          if (_selectionStart != null && _selectionCurrent != null) {
                            final rect = Rect.fromPoints(_selectionStart!, _selectionCurrent!);
                            notifier.selectNodesInRect(rect, append: _isMultiSelect);
                          }
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _selectionStart = null;
                            _selectionCurrent = null;
                          });
                          notifier.endMarqueeSelection();
                        },
                        child: Container(
                          width: _workspaceWidth * _currentZoom,
                          height: _workspaceHeight * _currentZoom,
                          color: Colors.transparent, // Capture gestures
                          child: CustomPaint(
                            painter: GridPainter(Theme.of(context).dividerColor.withValues(alpha: 0.1), _gridStep * _currentZoom),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Render projector nodes
                                ...nodes.map((node) => ProjectorCard(
                                      key: ValueKey(node.id),
                                      node: node,
                                      zoom: _currentZoom,
                                      onTap: () {
                                        notifier.selectNodeOnTap(node.id, multiSelect: _isMultiSelect);
                                      },
                                      onPanDown: (details) {
                                        notifier.selectNodeOnDown(node.id, multiSelect: _isMultiSelect);
                                      },
                                      onPanUpdate: (details) {
                                        notifier.updateNodePosition(node.id, details.delta.dx, details.delta.dy);
                                      },
                                      onPanEnd: (details) {
                                        notifier.snapNodeToGrid(node.id);
                                      },
                                    )),

                                // Render selection marquee
                                if (_selectionStart != null && _selectionCurrent != null)
                                  Positioned.fromRect(
                                    rect: Rect.fromPoints(
                                      _selectionStart! * _currentZoom,
                                      _selectionCurrent! * _currentZoom,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 1,
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
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Zoom Controls overlay at bottom left
        Positioned(
          bottom: 16,
          left: 16,
          child: _ZoomControl(
            currentZoom: _currentZoom,
            onZoomChanged: _setZoom,
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final Color gridColor;
  final double step;

  GridPainter(this.gridColor, this.step);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor || oldDelegate.step != step;
  }
}

class _ZoomControl extends StatefulWidget {
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;

  const _ZoomControl({
    required this.currentZoom,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomControl> createState() => _ZoomControlState();
}

class _ZoomControlState extends State<_ZoomControl> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              onPressed: () {
                final newZoom = double.parse((widget.currentZoom - 0.1).toStringAsFixed(1));
                widget.onZoomChanged(newZoom.clamp(0.5, 2.0));
              },
            ),
            if (_isHovered)
              SizedBox(
                width: 150,
                child: Slider(
                  value: widget.currentZoom.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${(widget.currentZoom * 100).round()}%',
                  onChanged: (val) {
                    // Update slider visually using 10% steps
                    final newZoom = double.parse(val.toStringAsFixed(1));
                    widget.onZoomChanged(newZoom);
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('${(widget.currentZoom * 100).round()}%'),
              ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              onPressed: () {
                final newZoom = double.parse((widget.currentZoom + 0.1).toStringAsFixed(1));
                widget.onZoomChanged(newZoom.clamp(0.5, 2.0));
              },
            ),
          ],
        ),
      ),
    );
  }
}
