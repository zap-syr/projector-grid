import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import '../providers/selection_provider.dart';

/// How strongly a grouped card's background is tinted with its group's
/// color. Applied via [Color.alphaBlend] over the card's normal surface
/// color, so 0 is indistinguishable from an ungrouped card and 1 would
/// replace the surface entirely with the flat group color. Kept as a single
/// named constant, rather than inlined, so it's a one-line change to tune.
const double kProjectorCardGroupTintOpacity = 0.15;

class ProjectorCard extends ConsumerStatefulWidget {
  final ProjectorNode node;
  final ProjectorGroup? group;
  // Keyed by node id, in workspace (unzoomed) coordinates. An entry means
  // this card is being actively dragged and should render at that position
  // instead of node.x/node.y — see ProjectorWorkspace's onPanUpdate/onPanEnd.
  final ValueListenable<Map<String, Offset>> dragOverrides;
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
  final VoidCallback onRemotePreview;
  final VoidCallback? onSelectGroup;
  final List<Widget> Function() buildGroupMenuItems;

  const ProjectorCard({
    super.key,
    required this.node,
    this.group,
    required this.dragOverrides,
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
    required this.onRemotePreview,
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
    final powerColor = switch (node.powerStatus) {
      PowerStatus.on => Colors.green,
      PowerStatus.standby => Colors.red,
      PowerStatus.turningOn || PowerStatus.cooling => Colors.amber,
    };
    final shutterColor = node.shutterStatus == ShutterStatus.open
        ? Colors.green
        : Colors.red;
    final connectionColor = switch (node.connectionStatus) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.unprotected => Colors.green,
      ConnectionStatus.unauthorized => Colors.amber,
      ConnectionStatus.offline => Colors.red,
    };

    // The status bar + name/IP column, shared by grouped and ungrouped
    // cards alike — a grouped card tints its own background instead of
    // changing anything inside this column (see build below).
    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.power_settings_new, size: 14, color: powerColor),
              const SizedBox(width: 4),
              Icon(Icons.visibility, size: 14, color: shutterColor),
              const SizedBox(width: 4),
              if (node.errors != 'NO ERRORS' && node.errors != '-')
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.orange,
                ),
              const Spacer(),
              if (node.connectionStatus == ConnectionStatus.unauthorized)
                const Icon(Icons.lock_outline, size: 12, color: Colors.amber),
              if (node.connectionStatus == ConnectionStatus.unprotected)
                const Icon(Icons.lock_open, size: 12, color: Colors.blue),
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
    );

    // Zoom changes rescale left/top just like a real position change would,
    // but should snap instantly rather than ease like an actual drag-snap
    // correction — otherwise every card visibly "jumps" on every zoom step.
    final zoomChanged = widget.zoom != _lastZoom;
    _lastZoom = widget.zoom;

    return ValueListenableBuilder<Map<String, Offset>>(
      valueListenable: widget.dragOverrides,
      builder: (context, dragOverrides, child) {
        // A live entry means this card is being actively dragged right now;
        // it overrides node.x/node.y until workspaceProvider is committed on
        // onPanEnd. Only this small closure rebuilds per pointer move — the
        // heavy subtree below is passed through unchanged as `child`.
        final liveOffset = dragOverrides[node.id];
        final isDragging = liveOffset != null;
        return AnimatedPositioned(
          duration: (isDragging || zoomChanged)
              ? Duration.zero
              : const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          left: (liveOffset?.dx ?? node.x) * widget.zoom,
          top: (liveOffset?.dy ?? node.y) * widget.zoom,
          child: child!,
        );
      },
      // Each card gets its own compositing layer so dragging one card only
      // re-composites that layer — the grid and every other card stay cached
      // instead of repainting on every pointer move. The boundary sits below
      // AnimatedPositioned (which must stay a direct child of the Stack).
      //
      // Transform.scale wraps the RepaintBoundary (not the other way round) so
      // hit-testing stays correct at zoom > 1. Transform.scale only changes
      // paint, never layout, so the card's RenderBox keeps its unscaled
      // 120x100 size. RepaintBoundary (a RenderProxyBox) bounds-checks pointer
      // events against its own size before forwarding them, so if it sat above
      // the Transform every pointer past x=120 / y=100 — i.e. the right/bottom
      // of a zoomed-in card, since scaling grows from topLeft — would be
      // rejected and hover/cursor/drag would never fire there. RenderTransform
      // deliberately skips that self bounds-check and maps the pointer through
      // its inverse matrix, so keeping it outermost makes the whole visible
      // (scaled) card area hittable.
      child: Transform.scale(
        scale: widget.zoom,
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          // The group chip is a sibling of MenuAnchor, not a descendant of
          // it — a Tooltip (which the chip may show) nested inside another
          // overlay-based widget like MenuAnchor corrupts the Windows
          // accessibility tree (AXTree) once enough of them rebuild at once,
          // e.g. on every zoom step. See flutter/flutter#98099 and the
          // Otzaria fix for the same "tooltip inside overlay anchor" crash.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MenuAnchor(
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
                    onPressed: () => _closeAndRun(widget.onRemotePreview),
                    leadingIcon: const Icon(Icons.cast),
                    child: const Text('Remote Preview'),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 120,
                      height: 100,
                      padding: EdgeInsets.all(isSelected ? 0 : 1),
                      decoration: BoxDecoration(
                        // A grouped card's background is the normal surface
                        // color tinted with the group's color rather than a
                        // separate bar or border, so the whole card reads as
                        // "belongs to this group" at a glance without adding
                        // any new shape to the card.
                        color: group == null
                            ? colorScheme.surface
                            : Color.alphaBlend(
                                Color(
                                  group.color,
                                ).withValues(alpha: kProjectorCardGroupTintOpacity),
                                colorScheme.surface,
                              ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : (_isHovered
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.85,
                                      )
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
                      // Explicit ClipRRect rather than the container's own
                      // clipBehavior: with a border drawn on the *outer*
                      // 8px-radius edge and this content inset by the
                      // border's own width, the content has to be clipped to
                      // the smaller *inner* radius (8 - border width) to line
                      // up flush with that border — the same correction the
                      // status bar below already relies on for its top
                      // corners. See: https://github.com/flutter/flutter/issues/149631
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: cardBody,
                      ),
                    ),
                  ),
                ),
              ),
              // Group chip — a sibling of MenuAnchor rather than nested
              // inside it (see the comment on the outer Column above).
              if (group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _GroupChip(group: group),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colored pill under a grouped card: the group name, painted in
/// whichever of black/white actually reads on top of the group's color —
/// unlike plain text set in the raw group color, this stays legible no
/// matter how light or dark that color is. Constrained to the card's own
/// 120px width so a long group name ellipsizes instead of overlapping its
/// neighbors; the full name only shows as a hover tooltip when it's actually
/// been cut off.
class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group});

  final ProjectorGroup group;

  static const _maxWidth = 120.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 3);

  @override
  Widget build(BuildContext context) {
    final color = Color(group.color);
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? const Color(0xFF15171B)
        : Colors.white;
    final textStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: textColor,
      height: 1,
    );

    final painter = TextPainter(
      text: TextSpan(text: group.name, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final isTruncated = painter.width > (_maxWidth - _padding.horizontal);

    final chip = Container(
      // No `alignment` and no fixed `height` here, on purpose. `alignment`
      // (or wrapping the child in Align/Center) makes a render object fill
      // the full *available* extent whenever that extent is bounded but not
      // exact — which a `maxWidth`-only cap always is — so either one
      // re-introduces the "chip stretches to the card's width" bug this
      // already went through once. A forced exact `height` has the same
      // problem from the other side: it creates a taller box than the text
      // needs, and with no alignment to center *within* it, the text just
      // sits at the box's top edge. Sizing purely from padding avoids the
      // mismatch instead of trying to correct for it — the box always hugs
      // the text exactly, in both axes, so there's nothing left to center.
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      padding: _padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );

    return isTruncated ? Tooltip(message: group.name, child: chip) : chip;
  }
}
