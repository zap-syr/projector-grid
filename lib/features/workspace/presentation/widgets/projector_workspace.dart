import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import 'projector_card.dart';
import 'edit_projector_dialog.dart';

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

class DeselectAllIntent extends Intent {
  const DeselectAllIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class SendCommandIntent extends Intent {
  final String command;
  const SendCommandIntent(this.command);
}

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
  bool _isMultiSelect = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _isMultiSelect = _checkIsMultiSelect();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  bool _checkIsMultiSelect() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isMulti = _checkIsMultiSelect();
    if (_isMultiSelect != isMulti) {
      setState(() {
        _isMultiSelect = isMulti;
      });
    }
    return false;
  }

  void _setZoom(double zoom, {Offset? contentOffset}) {
    final newZoom = zoom.clamp(0.5, 2.0);
    if (newZoom == _currentZoom) return;

    if (_horizontalController.hasClients && _verticalController.hasClients) {
      final oldZoom = _currentZoom;
      final scaleRatio = newZoom / oldZoom;

      double absoluteX;
      double absoluteY;

      if (contentOffset != null) {
        // Provided by mouse pointer signal (relative to the content itself)
        absoluteX = contentOffset.dx;
        absoluteY = contentOffset.dy;
      } else {
        // Fallback for UI buttons/slider: zoom relative to the center of the visible viewport
        absoluteX =
            _horizontalController.offset +
            (_horizontalController.position.viewportDimension / 2);
        absoluteY =
            _verticalController.offset +
            (_verticalController.position.viewportDimension / 2);
      }

      final viewportX = absoluteX - _horizontalController.offset;
      final viewportY = absoluteY - _verticalController.offset;

      final newAbsoluteX = absoluteX * scaleRatio;
      final newAbsoluteY = absoluteY * scaleRatio;

      final newScrollX = newAbsoluteX - viewportX;
      final newScrollY = newAbsoluteY - viewportY;

      // Adjust pixel offset synchronously to avoid 1-frame jitter during layout rebuild
      _horizontalController.position.correctPixels(newScrollX);
      _verticalController.position.correctPixels(newScrollY);

      setState(() {
        _currentZoom = newZoom;
      });

      // Post-frame jump ensures the scrollbars natively refresh their thumbs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_horizontalController.hasClients) {
          _horizontalController.jumpTo(_horizontalController.offset);
        }
        if (_verticalController.hasClients) {
          _verticalController.jumpTo(_verticalController.offset);
        }
      });
    } else {
      setState(() {
        _currentZoom = newZoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = (_workspaceWidth * _currentZoom)
            .clamp(constraints.maxWidth, double.infinity);
        final canvasHeight = (_workspaceHeight * _currentZoom)
            .clamp(constraints.maxHeight, double.infinity);

    return Stack(
      children: [
        // The Scrollable Workspace
        Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
                const SelectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA):
                const SelectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
                const DeselectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD):
                const DeselectAllIntent(),
            LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),

            // ── Lens Shift — normal speed (arrow only) ───────────────────
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const SendCommandIntent('VXX:LNSI3=+00100'),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const SendCommandIntent('VXX:LNSI3=+00101'),
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                const SendCommandIntent('VXX:LNSI2=+00101'),
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                const SendCommandIntent('VXX:LNSI2=+00100'),

            // ── Lens Shift — fast speed (Shift + arrow) ──────────────────
            const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
                const SendCommandIntent('VXX:LNSI3=+00200'),
            const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
                const SendCommandIntent('VXX:LNSI3=+00201'),
            const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
                const SendCommandIntent('VXX:LNSI2=+00201'),
            const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
                const SendCommandIntent('VXX:LNSI2=+00200'),

            // ── Lens Shift — slow speed (Ctrl + arrow) ───────────────────
            const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
                const SendCommandIntent('VXX:LNSI3=+00000'),
            const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
                const SendCommandIntent('VXX:LNSI3=+00001'),
            const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
                const SendCommandIntent('VXX:LNSI2=+00001'),
            const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
                const SendCommandIntent('VXX:LNSI2=+00000'),

            // ── Shutter ───────────────────────────────────────────────────
            const SingleActivator(LogicalKeyboardKey.keyI):
                const SendCommandIntent('OSH:1'),
            const SingleActivator(LogicalKeyboardKey.keyO):
                const SendCommandIntent('OSH:0'),
          },
          child: Actions(
            actions: {
              SelectAllIntent: CallbackAction<SelectAllIntent>(
                onInvoke: (intent) => notifier.selectAll(),
              ),
              DeselectAllIntent: CallbackAction<DeselectAllIntent>(
                onInvoke: (intent) => notifier.deselectAll(),
              ),
              SendCommandIntent: CallbackAction<SendCommandIntent>(
                onInvoke: (intent) =>
                    notifier.sendCommandToSelected(intent.command),
              ),
              DeleteIntent: CallbackAction<DeleteIntent>(
                onInvoke: (intent) async {
                  final selectedCount = nodes.where((n) => n.isSelected).length;
                  if (selectedCount == 0) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Projectors'),
                      content: Text(
                        'Are you sure you want to delete $selectedCount selected projector(s)?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    notifier.deleteSelected();
                  }
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              canRequestFocus: true,
              // Outer listener: Captures middle-mouse panning independently of scroll contents
              child: Listener(
                onPointerMove: (event) {
                  if (event.buttons == kMiddleMouseButton) {
                    if (_horizontalController.hasClients) {
                      _horizontalController.jumpTo(
                        (_horizontalController.offset - event.delta.dx).clamp(
                          0.0,
                          _horizontalController.position.maxScrollExtent,
                        ),
                      );
                    }
                    if (_verticalController.hasClients) {
                      _verticalController.jumpTo(
                        (_verticalController.offset - event.delta.dy).clamp(
                          0.0,
                          _verticalController.position.maxScrollExtent,
                        ),
                      );
                    }
                  }
                },
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
                      physics: _isMultiSelect
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        physics: _isMultiSelect
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        // Inner listener: Captures scroll wheel zoom and intercepts it before SingleChildScrollView acts
                        child: Listener(
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent) {
                              if (_isMultiSelect) {
                                final double scrollDelta =
                                    pointerSignal.scrollDelta.dy;
                                if (scrollDelta > 0) {
                                  final newZoom = double.parse(
                                    (_currentZoom - 0.1).toStringAsFixed(1),
                                  );
                                  _setZoom(
                                    newZoom.clamp(0.5, 2.0),
                                    contentOffset: pointerSignal.localPosition,
                                  );
                                } else if (scrollDelta < 0) {
                                  final newZoom = double.parse(
                                    (_currentZoom + 0.1).toStringAsFixed(1),
                                  );
                                  _setZoom(
                                    newZoom.clamp(0.5, 2.0),
                                    contentOffset: pointerSignal.localPosition,
                                  );
                                }
                              }
                            }
                          },
                          child: GestureDetector(
                            onTap: () {
                              notifier.deselectAll();
                            },
                            onPanStart: (details) {
                              setState(() {
                                _selectionStart =
                                    details.localPosition / _currentZoom;
                                _selectionCurrent =
                                    details.localPosition / _currentZoom;
                              });
                              notifier.startMarqueeSelection(
                                append: _isMultiSelect,
                              );
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _selectionCurrent =
                                    details.localPosition / _currentZoom;
                              });
                              if (_selectionStart != null &&
                                  _selectionCurrent != null) {
                                final rect = Rect.fromPoints(
                                  _selectionStart!,
                                  _selectionCurrent!,
                                );
                                notifier.selectNodesInRect(
                                  rect,
                                  append: _isMultiSelect,
                                );
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
                              width: canvasWidth,
                              height: canvasHeight,
                              color: Colors.transparent, // Capture gestures
                              child: CustomPaint(
                                painter: GridPainter(
                                  Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.1),
                                  _gridStep * _currentZoom,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Render projector nodes
                                    ...nodes.map(
                                      (node) => ProjectorCard(
                                        key: ValueKey(node.id),
                                        node: node,
                                        zoom: _currentZoom,
                                        onTap: () {
                                          notifier.selectNodeOnTap(
                                            node.id,
                                            multiSelect: _isMultiSelect,
                                          );
                                        },
                                        onPanDown: (details) {
                                          notifier.selectNodeOnDown(
                                            node.id,
                                            multiSelect: _isMultiSelect,
                                          );
                                        },
                                        onPanUpdate: (details) {
                                          notifier.updateNodePosition(
                                            node.id,
                                            details.delta.dx,
                                            details.delta.dy,
                                          );
                                        },
                                        onPanEnd: (details) {
                                          notifier.snapNodeToGrid(node.id);
                                        },
                                        onEdit: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                EditProjectorDialog(
                                                  node: node,
                                                  onSave:
                                                      (ip, login, password) {
                                                        notifier.updateNode(
                                                          node.id,
                                                          ip,
                                                          login,
                                                          password,
                                                        );
                                                      },
                                                ),
                                          );
                                        },
                                        onDelete: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Delete Projector',
                                              ),
                                              content: Text(
                                                'Are you sure you want to delete ${node.name}?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            notifier.deleteNode(node.id);
                                          }
                                        },
                                        onColorCorrection: () {
                                          // Empty for now
                                        },
                                      ),
                                    ),

                                    // Render selection marquee
                                    if (_selectionStart != null &&
                                        _selectionCurrent != null)
                                      Positioned.fromRect(
                                        rect: Rect.fromPoints(
                                          _selectionStart! * _currentZoom,
                                          _selectionCurrent! * _currentZoom,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.2),
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
          ),
        ),

        // Zoom Controls overlay at bottom left
        Positioned(
          bottom: 16,
          left: 16,
          child: _ZoomControl(
            currentZoom: _currentZoom,
            onZoomChanged: (zoom) => _setZoom(zoom),
          ),
        ),
      ],
    );
      },
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

  const _ZoomControl({required this.currentZoom, required this.onZoomChanged});

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
                final newZoom = double.parse(
                  (widget.currentZoom - 0.1).toStringAsFixed(1),
                );
                widget.onZoomChanged(newZoom.clamp(0.5, 2.0));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('${(widget.currentZoom * 100).round()}%'),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              onPressed: () {
                final newZoom = double.parse(
                  (widget.currentZoom + 0.1).toStringAsFixed(1),
                );
                widget.onZoomChanged(newZoom.clamp(0.5, 2.0));
              },
            ),
          ],
        ),
      ),
    );
  }
}
