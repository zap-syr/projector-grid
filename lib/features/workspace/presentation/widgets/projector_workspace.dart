import 'dart:io' show Platform;
import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workspace_provider.dart';
import '../providers/selection_provider.dart';
import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import 'projector_card.dart';
import 'edit_projector_dialog.dart';
import 'color_correction_dialog.dart';
import 'brightness_control_dialog.dart';
import 'geometry_correction_dialog.dart';
import 'manage_groups_dialog.dart';

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

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class FocusOnNodesIntent extends Intent {
  final bool allProjectors;
  const FocusOnNodesIntent({required this.allProjectors});
}

class ProjectorWorkspace extends ConsumerStatefulWidget {
  const ProjectorWorkspace({super.key});

  @override
  ConsumerState<ProjectorWorkspace> createState() => _ProjectorWorkspaceState();
}

class _ProjectorWorkspaceState extends ConsumerState<ProjectorWorkspace>
    with WidgetsBindingObserver {
  // Marquee (rubber-band) selection. The anchor is a plain field and the live
  // rectangle is a ValueNotifier painted by _MarqueePainter, so dragging the
  // marquee never calls setState — the ~100 ProjectorCard widgets built in
  // build() are not recreated on every pointer move. Stored in screen (zoomed)
  // coordinates; divided by _currentZoom only when hit-testing nodes.
  Offset? _selectionAnchor;
  final ValueNotifier<Rect?> _marqueeRect = ValueNotifier<Rect?>(null);

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  Offset _panTotalDelta = Offset.zero;
  Map<String, Offset>? _panStartPositions;

  final double _gridStep = 20.0;
  final double _workspaceWidth = 3000.0;
  final double _workspaceHeight = 3000.0;
  double _currentZoom = 1.0;
  bool _isMultiSelect = false;
  bool _isPanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _isMultiSelect = _checkIsMultiSelect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _verticalController.dispose();
    _horizontalController.dispose();
    _marqueeRect.dispose();
    super.dispose();
  }

  // On Windows/macOS, holding Ctrl/Cmd then switching away from the window
  // can cause the key-up event to be dropped, leaving _isMultiSelect stuck as
  // true and permanently applying NeverScrollableScrollPhysics. Resetting on
  // resume clears any stale modifier-key state as soon as the window refocuses.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isMultiSelect) {
      setState(() => _isMultiSelect = false);
    }
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

  // Card size mirrors the fixed dimensions in projector_card.dart — the
  // bounding box needs the cards' visual extent, not just their x/y anchors.
  static const double _cardWidth = 120.0;
  static const double _cardHeight = 100.0;
  static const double _focusPadding = 60.0;

  /// Zooms/scrolls so [targets] are centered and fit in the viewport.
  ///
  /// Unlike [_setZoom] (which keeps a point fixed at its current on-screen
  /// position — right for zoom-under-cursor/zoom-buttons), this jumps the
  /// viewport to a brand-new center, so it computes the target scroll
  /// offset directly rather than an anchor-preserving delta.
  void _focusOnNodes(List<ProjectorNode> targets) {
    if (targets.isEmpty) return;
    if (!_horizontalController.hasClients || !_verticalController.hasClients) {
      return;
    }

    final minX = targets.map((n) => n.x).reduce(min);
    final maxX = targets.map((n) => n.x + _cardWidth).reduce(max);
    final minY = targets.map((n) => n.y).reduce(min);
    final maxY = targets.map((n) => n.y + _cardHeight).reduce(max);

    final boxWidth = (maxX - minX) + _focusPadding * 2;
    final boxHeight = (maxY - minY) + _focusPadding * 2;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final viewportWidth = _horizontalController.position.viewportDimension;
    final viewportHeight = _verticalController.position.viewportDimension;

    final fitZoom = min(viewportWidth / boxWidth, viewportHeight / boxHeight);
    final newZoom = fitZoom.clamp(0.5, 2.0).toDouble();

    final newScrollX = (centerX * newZoom) - (viewportWidth / 2);
    final newScrollY = (centerY * newZoom) - (viewportHeight / 2);

    if (newZoom == _currentZoom) {
      // Zoom isn't changing, so canvasWidth/canvasHeight (derived from
      // _currentZoom) won't change either, which means nothing forces a
      // relayout to pick up a correctPixels()-style silent adjustment —
      // correctPixels only takes visible effect piggybacking on a relayout
      // that was going to happen anyway (see _setZoom's early-return for
      // the same reason). A plain jumpTo() goes through the normal,
      // notifying scroll pipeline instead, so it repaints on its own.
      _horizontalController.jumpTo(
        newScrollX.clamp(0.0, _horizontalController.position.maxScrollExtent),
      );
      _verticalController.jumpTo(
        newScrollY.clamp(0.0, _verticalController.position.maxScrollExtent),
      );
      return;
    }

    // Same "correct pixels before setState" trick as _setZoom, so the
    // scroll view doesn't visibly jump/animate across two frames.
    _horizontalController.position.correctPixels(
      newScrollX.clamp(0.0, double.infinity),
    );
    _verticalController.position.correctPixels(
      newScrollY.clamp(0.0, double.infinity),
    );

    setState(() {
      _currentZoom = newZoom;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(
          newScrollX.clamp(0.0, _horizontalController.position.maxScrollExtent),
        );
      }
      if (_verticalController.hasClients) {
        _verticalController.jumpTo(
          newScrollY.clamp(0.0, _verticalController.position.maxScrollExtent),
        );
      }
    });
  }

  List<Widget> _buildGroupMenuItems(
    ProjectorNode node,
    WorkspaceNotifier notifier,
    List<ProjectorGroup> groups,
  ) {
    // Collect affected node IDs: if the node is selected, apply to all selected.
    final selected = ref.read(selectionProvider);
    final targetIds = selected.contains(node.id)
        ? selected.toList()
        : [node.id];

    return [
      ...groups.map(
        (g) => MenuItemButton(
          onPressed: () => notifier.assignNodesToGroup(targetIds, g.id),
          leadingIcon: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(g.color),
              shape: BoxShape.circle,
            ),
          ),
          trailingIcon: node.groupId == g.id
              ? Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          child: Text(g.name),
        ),
      ),
      if (groups.isNotEmpty) const Divider(height: 1),
      MenuItemButton(
        onPressed: () async {
          final newGroup = await showGroupEditorDialog(context, ref);
          if (newGroup != null) {
            notifier.assignNodesToGroup(targetIds, newGroup.id);
          }
        },
        child: const Text('New Group...'),
      ),
      if (node.groupId != null)
        MenuItemButton(
          onPressed: () => notifier.assignNodesToGroup(targetIds, null),
          child: const Text('Remove from Group'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);
    final groups = notifier.groups;
    final groupMap = {for (var g in groups) g.id: g};

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = (_workspaceWidth * _currentZoom).clamp(
          constraints.maxWidth,
          double.infinity,
        );
        final canvasHeight = (_workspaceHeight * _currentZoom).clamp(
          constraints.maxHeight,
          double.infinity,
        );

        return MouseRegion(
          cursor: _isPanning
              ? (Platform.isMacOS
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.move)
              : MouseCursor.defer,
          child: Stack(
            children: [
              // The Scrollable Workspace
              Shortcuts(
                shortcuts: {
                  LogicalKeySet(
                    LogicalKeyboardKey.control,
                    LogicalKeyboardKey.keyA,
                  ): const SelectAllIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.meta,
                    LogicalKeyboardKey.keyA,
                  ): const SelectAllIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.control,
                    LogicalKeyboardKey.keyD,
                  ): const DeselectAllIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.meta,
                    LogicalKeyboardKey.keyD,
                  ): const DeselectAllIntent(),
                  LogicalKeySet(LogicalKeyboardKey.delete):
                      const DeleteIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.control,
                    LogicalKeyboardKey.keyZ,
                  ): const UndoIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.meta,
                    LogicalKeyboardKey.keyZ,
                  ): const UndoIntent(),
                  // Redo is Ctrl+Y here (Windows/Linux convention). macOS
                  // uses Cmd+Shift+Z instead, matching platform convention —
                  // bound via the native Edit menu in mac_menu_bar.dart, not
                  // here, so there's exactly one macOS Redo binding rather
                  // than this plus a non-standard Cmd+Y.
                  LogicalKeySet(
                    LogicalKeyboardKey.control,
                    LogicalKeyboardKey.keyY,
                  ): const RedoIntent(),

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
                  const SingleActivator(
                    LogicalKeyboardKey.arrowUp,
                    shift: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI3=+00200',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowDown,
                    shift: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI3=+00201',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowLeft,
                    shift: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00201',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowRight,
                    shift: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00200',
                  ),

                  // ── Lens Shift — slow speed (Ctrl + arrow; also Cmd + arrow
                  // on macOS, matching how every other Ctrl-bound shortcut in
                  // this map registers a meta variant too, and how the
                  // Keyboard Shortcuts dialog already labels this row ⌘ on
                  // macOS) ───────────────────
                  const SingleActivator(
                    LogicalKeyboardKey.arrowUp,
                    control: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI3=+00000',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowDown,
                    control: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI3=+00001',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowLeft,
                    control: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00001',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowRight,
                    control: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00000',
                  ),
                  const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
                      const SendCommandIntent('VXX:LNSI3=+00000'),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowDown,
                    meta: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI3=+00001',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowLeft,
                    meta: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00001',
                  ),
                  const SingleActivator(
                    LogicalKeyboardKey.arrowRight,
                    meta: true,
                  ): const SendCommandIntent(
                    'VXX:LNSI2=+00000',
                  ),

                  // ── Shutter ───────────────────────────────────────────────────
                  const SingleActivator(LogicalKeyboardKey.keyI):
                      const SendCommandIntent('OSH:1'),
                  const SingleActivator(LogicalKeyboardKey.keyO):
                      const SendCommandIntent('OSH:0'),

                  // ── Focus (F = selected, falls back to all; Shift+F = all) ───
                  const SingleActivator(LogicalKeyboardKey.keyF):
                      const FocusOnNodesIntent(allProjectors: false),
                  const SingleActivator(LogicalKeyboardKey.keyF, shift: true):
                      const FocusOnNodesIntent(allProjectors: true),
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
                    UndoIntent: CallbackAction<UndoIntent>(
                      onInvoke: (intent) => notifier.undo(),
                    ),
                    RedoIntent: CallbackAction<RedoIntent>(
                      onInvoke: (intent) => notifier.redo(),
                    ),
                    FocusOnNodesIntent: CallbackAction<FocusOnNodesIntent>(
                      onInvoke: (intent) {
                        final selectedIds = ref.read(selectionProvider);
                        final targets =
                            (intent.allProjectors || selectedIds.isEmpty)
                            ? nodes
                            : nodes
                                  .where((n) => selectedIds.contains(n.id))
                                  .toList();
                        _focusOnNodes(targets);
                        return null;
                      },
                    ),
                    DeleteIntent: CallbackAction<DeleteIntent>(
                      onInvoke: (intent) async {
                        final selectedCount = ref
                            .read(selectionProvider)
                            .length;
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
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
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
                      onPointerDown: (event) {
                        if (event.buttons == kMiddleMouseButton) {
                          setState(() => _isPanning = true);
                        }
                      },
                      onPointerUp: (event) {
                        if (_isPanning) setState(() => _isPanning = false);
                      },
                      onPointerMove: (event) {
                        final panning = event.buttons == kMiddleMouseButton;
                        if (panning != _isPanning)
                          setState(() => _isPanning = panning);
                        if (panning) {
                          if (_horizontalController.hasClients) {
                            _horizontalController.jumpTo(
                              (_horizontalController.offset - event.delta.dx)
                                  .clamp(
                                    0.0,
                                    _horizontalController
                                        .position
                                        .maxScrollExtent,
                                  ),
                            );
                          }
                          if (_verticalController.hasClients) {
                            _verticalController.jumpTo(
                              (_verticalController.offset - event.delta.dy)
                                  .clamp(
                                    0.0,
                                    _verticalController
                                        .position
                                        .maxScrollExtent,
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
                                          (_currentZoom - 0.1).toStringAsFixed(
                                            1,
                                          ),
                                        );
                                        _setZoom(
                                          newZoom.clamp(0.5, 2.0),
                                          contentOffset:
                                              pointerSignal.localPosition,
                                        );
                                      } else if (scrollDelta < 0) {
                                        final newZoom = double.parse(
                                          (_currentZoom + 0.1).toStringAsFixed(
                                            1,
                                          ),
                                        );
                                        _setZoom(
                                          newZoom.clamp(0.5, 2.0),
                                          contentOffset:
                                              pointerSignal.localPosition,
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
                                    if (_isPanning) return;
                                    _selectionAnchor = details.localPosition;
                                    _marqueeRect.value =
                                        details.localPosition & Size.zero;
                                    notifier.startMarqueeSelection(
                                      append: _isMultiSelect,
                                    );
                                  },
                                  onPanUpdate: (details) {
                                    if (_isPanning) return;
                                    final anchor = _selectionAnchor;
                                    if (anchor == null) return;
                                    _marqueeRect.value = Rect.fromPoints(
                                      anchor,
                                      details.localPosition,
                                    );
                                    notifier.selectNodesInRect(
                                      Rect.fromPoints(
                                        anchor / _currentZoom,
                                        details.localPosition / _currentZoom,
                                      ),
                                      append: _isMultiSelect,
                                    );
                                  },
                                  onPanEnd: (details) {
                                    if (_isPanning) return;
                                    _selectionAnchor = null;
                                    _marqueeRect.value = null;
                                    notifier.endMarqueeSelection();
                                  },
                                  child: Container(
                                    width: canvasWidth,
                                    height: canvasHeight,
                                    color:
                                        Colors.transparent, // Capture gestures
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Background grid isolated in its own
                                        // layer (RepaintBoundary) so it
                                        // rasterizes once and stays cached while
                                        // cards are dragged on top of it,
                                        // instead of the whole 3000x3000 grid
                                        // repainting on every pointer move.
                                        Positioned.fill(
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: GridPainter(
                                                Theme.of(context).dividerColor
                                                    .withValues(alpha: 0.1),
                                                _gridStep * _currentZoom,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Render projector nodes
                                        ...nodes.map(
                                          (node) => ProjectorCard(
                                            key: ValueKey(node.id),
                                            node: node,
                                            group: node.groupId != null
                                                ? groupMap[node.groupId]
                                                : null,
                                            isDragging:
                                                _panStartPositions?.containsKey(
                                                  node.id,
                                                ) ??
                                                false,
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
                                              if (_panStartPositions == null) {
                                                notifier.saveBeforeMove();
                                                final selectedIds = ref.read(
                                                  selectionProvider,
                                                );
                                                final affected =
                                                    selectedIds.contains(
                                                      node.id,
                                                    )
                                                    ? nodes.where(
                                                        (n) => selectedIds
                                                            .contains(n.id),
                                                      )
                                                    : [node];
                                                _panStartPositions = {
                                                  for (final n in affected)
                                                    n.id: Offset(n.x, n.y),
                                                };
                                                _panTotalDelta = Offset.zero;
                                              }
                                              _panTotalDelta += details.delta;
                                              notifier.setNodePositionsFromDrag(
                                                node.id,
                                                _panTotalDelta,
                                                _panStartPositions!,
                                              );
                                            },
                                            onPanEnd: (details) {
                                              // Clear drag tracking before the
                                              // snap so the resulting rebuild
                                              // sees isDragging=false and
                                              // animates the snap correction
                                              // instead of jumping instantly.
                                              _panStartPositions = null;
                                              _panTotalDelta = Offset.zero;
                                              notifier.snapNodeToGrid(node.id);
                                              notifier.endMove();
                                            },
                                            onEdit: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    EditProjectorDialog(
                                                      node: node,
                                                      existingIps: nodes
                                                          .map(
                                                            (n) => n.ipAddress,
                                                          )
                                                          .where(
                                                            (ip) =>
                                                                ip !=
                                                                node.ipAddress,
                                                          )
                                                          .toSet(),
                                                      onSave:
                                                          (
                                                            ip,
                                                            login,
                                                            password,
                                                          ) {
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
                                              final selectedIds = ref.read(
                                                selectionProvider,
                                              );
                                              final selectedCount =
                                                  selectedIds.length;
                                              final isMultiDelete =
                                                  selectedIds.contains(
                                                    node.id,
                                                  ) &&
                                                  selectedCount > 1;
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Delete Projector',
                                                  ),
                                                  content: Text(
                                                    isMultiDelete
                                                        ? 'Are you sure you want to delete $selectedCount selected projectors?'
                                                        : 'Are you sure you want to delete ${node.name}?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: const Text(
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                if (isMultiDelete) {
                                                  notifier.deleteSelected();
                                                } else {
                                                  notifier.deleteNode(node.id);
                                                }
                                              }
                                            },
                                            onColorCorrection: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) =>
                                                    ColorCorrectionDialog(
                                                      node: node,
                                                    ),
                                              );
                                            },
                                            onBrightnessControl: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) =>
                                                    BrightnessControlDialog(
                                                      node: node,
                                                    ),
                                              );
                                            },
                                            onGeometryCorrection: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) =>
                                                    GeometryCorrectionDialog(
                                                      node: node,
                                                    ),
                                              );
                                            },
                                            onSelectGroup: node.groupId != null
                                                ? () => notifier
                                                      .selectNodesInGroup(
                                                        node.groupId!,
                                                      )
                                                : null,
                                            buildGroupMenuItems: () =>
                                                _buildGroupMenuItems(
                                                  node,
                                                  notifier,
                                                  groups,
                                                ),
                                          ),
                                        ),

                                        // Selection marquee — painted from a
                                        // ValueNotifier so the drag repaints
                                        // only this overlay, not the card tree.
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: CustomPaint(
                                              painter: _MarqueePainter(
                                                rect: _marqueeRect,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
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
          ),
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

/// Paints the rubber-band selection rectangle. Driven directly by a
/// [ValueNotifier] via `super.repaint`, so the marquee drag repaints this
/// overlay alone — the parent [ProjectorWorkspace] never rebuilds.
class _MarqueePainter extends CustomPainter {
  _MarqueePainter({required ValueNotifier<Rect?> rect, required this.color})
    : _rect = rect,
      super(repaint: rect);

  final ValueNotifier<Rect?> _rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _rect.value;
    if (rect == null || rect.isEmpty) return;
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate._rect != _rect;
}

class _ZoomControl extends StatefulWidget {
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;

  const _ZoomControl({required this.currentZoom, required this.onZoomChanged});

  @override
  State<_ZoomControl> createState() => _ZoomControlState();
}

class _ZoomControlState extends State<_ZoomControl> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
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
