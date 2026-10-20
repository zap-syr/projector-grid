import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/external_links.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/alignment.dart';
import '../../domain/card_layout.dart';
import '../../domain/projector_node.dart';
import '../../domain/projector_group.dart';
import '../../domain/test_patterns.dart';
import '../providers/alignment_provider.dart';
import '../providers/selection_provider.dart';
import 'alert_badge.dart';
import 'common/key_caps.dart';
import 'common/test_pattern_thumb.dart';
import 'projector_status_style.dart';

/// Height of the state-tinted header band at the top of a card.
const double kCardHeaderHeight = 26;

/// Height of the group band at the bottom of a grouped card.
const double kCardGroupBandHeight = 18;

const double _radius = 10;

/// Fill of the card body, top and bottom of its gradient. The group band
/// mixes into [bottom].
({Color top, Color bottom}) projectorCardFill(ColorScheme cs) =>
    cs.brightness == Brightness.dark
    ? (top: cs.surfaceContainerHigh, bottom: cs.surfaceContainer)
    : (top: cs.surfaceContainerLowest, bottom: cs.surfaceContainerLow);

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
  final VoidCallback onQuickStatus;
  final VoidCallback onDelete;
  final VoidCallback onColorCorrection;
  final VoidCallback onBrightnessControl;
  final VoidCallback onGeometryCorrection;
  final VoidCallback onEdgeBlending;
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
    required this.onQuickStatus,
    required this.onDelete,
    required this.onColorCorrection,
    required this.onBrightnessControl,
    required this.onGeometryCorrection,
    required this.onEdgeBlending,
    required this.onRemotePreview,
    required this.onSelectGroup,
    required this.buildGroupMenuItems,
  });

  @override
  ConsumerState<ProjectorCard> createState() => _ProjectorCardState();
}

class _ProjectorCardState extends ConsumerState<ProjectorCard> {
  // How far the focused card's Alignment ring reaches past the card edge
  // (its outer shadow's spreadRadius).
  static const double _ringWidth = 5;

  final _menuController = MenuController();
  bool _isHovered = false;
  double? _lastZoom;

  void _closeAndRun(VoidCallback action) {
    _menuController.close();
    action();
  }

  List<Widget> _menuChildren({
    required bool inPair,
    required bool alignmentActive,
  }) {
    final node = widget.node;
    return [
      _MenuHeader(model: node.name, ip: node.ipAddress),
      const _MenuDivider(),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onEdit),
        leadingIcon: const Icon(Icons.edit_outlined),
        child: const Text('Edit'),
      ),
      MenuItemButton(
        // The popover doesn't open in Alignment mode.
        onPressed: alignmentActive
            ? null
            : () => _closeAndRun(widget.onQuickStatus),
        leadingIcon: const Icon(Icons.info_outline),
        // Shown only: the key itself is bound in the canvas Shortcuts. Key
        // caps, as tooltips show shortcuts: `shortcut:` would draw it in the
        // item's own type, like a second label.
        trailingIcon: const KeyCaps(['Space'], small: true),
        child: const Text('Quick status'),
      ),
      const _MenuDivider(),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onBrightnessControl),
        leadingIcon: const Icon(Icons.brightness_6_outlined),
        child: const Text('Brightness Control'),
      ),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onColorCorrection),
        leadingIcon: const Icon(Icons.palette_outlined),
        child: const Text('Color Correction'),
      ),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onGeometryCorrection),
        leadingIcon: const Icon(Icons.crop_free),
        child: const Text('Geometry Correction'),
      ),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onEdgeBlending),
        leadingIcon: const Icon(Icons.gradient),
        child: Text(inPair ? 'Edge Blending (2 projectors)' : 'Edge Blending'),
      ),
      const _MenuDivider(),
      MenuItemButton(
        onPressed: () => _closeAndRun(widget.onRemotePreview),
        leadingIcon: const Icon(Icons.monitor_outlined),
        child: const Text('Remote Preview'),
      ),
      MenuItemButton(
        onPressed: () =>
            _closeAndRun(() => openInBrowser('http://${node.ipAddress}')),
        leadingIcon: const Icon(Icons.open_in_browser),
        child: const Text('Open in Browser'),
      ),
      const _MenuDivider(),
      SubmenuButton(
        alignmentOffset: AppTheme.submenuOffset,
        menuChildren: widget.buildGroupMenuItems(),
        leadingIcon: const Icon(Icons.workspaces_outlined),
        child: const Text('Assign to Group'),
      ),
      MenuItemButton(
        onPressed: widget.onSelectGroup != null
            ? () => _closeAndRun(widget.onSelectGroup!)
            : null,
        leadingIcon: const Icon(Icons.select_all),
        child: const Text('Select in Group'),
      ),
      const _MenuDivider(),
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
    ];
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
    // Edge Blending opens pair mode for exactly this selection.
    final inPair = ref.watch(
      selectionProvider.select(
        (ids) => ids.length == 2 && ids.contains(node.id),
      ),
    );
    final alignmentRole = ref.watch(
      alignmentProvider.select((s) => s.roles[node.id]),
    );
    final alignmentActive = ref.watch(
      alignmentProvider.select((s) => s.active),
    );
    // In Alignment mode the focused card is also the selection; its ring
    // replaces the selection ring instead of stacking on it.
    final showSelection = isSelected && alignmentRole == null;
    final alignmentAccent = AppTheme.alignmentAccent(theme.brightness);
    final alignmentNeighbour = AppTheme.alignmentNeighbour(theme.brightness);
    final offline = node.connectionStatus == ConnectionStatus.offline;
    final fill = projectorCardFill(colorScheme);
    final style = ProjectorStatusStyle.of(context);
    final dark = theme.brightness == Brightness.dark;

    // Offline is the only state that touches the outline, so a red outline
    // always means "doesn't answer" and standby never reads as a fault.
    // A selected card already has its ring; a hover outline inside it would
    // read as a second ring.
    final border = offline
        ? Border.all(color: colorScheme.error.withValues(alpha: 0.6))
        : Border.all(
            color: _isHovered && !showSelection
                ? colorScheme.primary.withValues(alpha: 0.7)
                : colorScheme.outlineVariant,
          );
    final bodyFill = offline
        ? [
            Color.alphaBlend(
              colorScheme.error.withValues(alpha: 0.07),
              fill.top,
            ),
            Color.alphaBlend(
              colorScheme.error.withValues(alpha: 0.05),
              fill.bottom,
            ),
          ]
        : [fill.top, fill.bottom];

    final card = SizedBox(
      width: kCardWidth,
      height: kCardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bodyFill,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.35 : 0.1),
                    blurRadius: dark ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardHeader(node: node, base: fill.top, style: style),
                  Expanded(
                    child: _CardBody(node: node, selected: showSelection),
                  ),
                  if (group != null)
                    Opacity(
                      opacity: offline ? 0.7 : 1,
                      child: _GroupBand(group: group, card: fill.bottom),
                    ),
                ],
              ),
            ),
          ),
          // Drawn over the content's edge rather than around it, so the
          // outline never shifts the content.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('card-border'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  border: border,
                ),
              ),
            ),
          ),
          // Cards whose shutter the mode keeps closed are dimmed like the
          // dark projectors on the wall, with an opaque scrim rather than
          // opacity so the canvas grid doesn't show through.
          if (alignmentRole == AlignmentRole.closed)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                ),
              ),
            ),
          if (showSelection)
            Positioned.fill(
              left: -5.5,
              top: -5.5,
              right: -5.5,
              bottom: -5.5,
              child: IgnorePointer(
                child: _SelectionRing(color: colorScheme.primary),
              ),
            ),
        ],
      ),
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
      //
      // No Material Tooltip anywhere inside: one nested in an overlay-based
      // widget like MenuAnchor corrupts the Windows accessibility tree
      // (AXTree) once enough of them rebuild at once, e.g. on every zoom step
      // (flutter/flutter#98099). The full group name is in the quick status
      // and the context menu instead.
      child: Transform.scale(
        scale: widget.zoom,
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: MenuAnchor(
            controller: _menuController,
            consumeOutsideTap: true,
            menuChildren: _menuChildren(
              inPair: inPair,
              alignmentActive: alignmentActive,
            ),
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
                // Alignment mode ring, drawn outside the card with a 2 px
                // canvas-coloured gap so it never merges with the card's
                // own border: focused = 3 px ring and a glow, open
                // neighbour = 2 px ring in a paler tone. Later shadows
                // paint over earlier ones, so the gap goes last.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    boxShadow: [
                      if (alignmentRole == AlignmentRole.focused) ...[
                        BoxShadow(
                          color: alignmentAccent.withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: _ringWidth,
                        ),
                        BoxShadow(
                          color: alignmentAccent,
                          spreadRadius: _ringWidth,
                        ),
                        BoxShadow(color: colorScheme.surface, spreadRadius: 2),
                      ] else if (alignmentRole == AlignmentRole.shown) ...[
                        BoxShadow(color: alignmentNeighbour, spreadRadius: 4),
                        BoxShadow(color: colorScheme.surface, spreadRadius: 2),
                      ],
                    ],
                  ),
                  child: card,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selection: a ring 3 px outside the card with a soft glow, painted
/// only outside so the glow never washes over the card.
class _SelectionRing extends StatelessWidget {
  const _SelectionRing({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('selection-ring'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius + 5.5),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 18,
            blurStyle: BlurStyle.outer,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 1,
            spreadRadius: 3,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
    );
  }
}

/// The header band, tinted by the power state so it reads from a distance:
/// power and shutter on the left, the open lock and the alert badge on the
/// right, so a new alert never moves the power icon.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.node,
    required this.base,
    required this.style,
  });

  final ProjectorNode node;
  final Color base;
  final ProjectorStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final tone = cardHeaderTone(node);
    final toneColor = style.toneColor(tone);
    final strong = tone == CardHeaderTone.offline;
    final t = AppText.of(context);

    final List<Widget> leading = switch (tone) {
      CardHeaderTone.offline => [
        _HeaderLabel(icon: Icons.power_off, label: 'Offline', color: toneColor),
      ],
      CardHeaderTone.loginFailed => [
        _HeaderLabel(
          icon: Icons.lock_outline,
          label: 'Login failed',
          color: toneColor,
        ),
      ],
      _ => [
        Icon(
          Icons.power_settings_new,
          key: const ValueKey('card-power'),
          size: 16,
          color: style.powerColor(node.powerStatus),
        ),
        const SizedBox(width: 6),
        Icon(
          ProjectorStatusStyle.shutterIcon(node.shutterStatus),
          key: const ValueKey('card-shutter'),
          size: 16,
          color: style.shutterColor(node),
        ),
        const Spacer(),
      ],
    };

    return Container(
      key: const ValueKey('card-header'),
      height: kCardHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          toneColor.withValues(alpha: strong ? 0.34 : 0.16),
          base,
        ),
        border: Border(
          bottom: BorderSide(
            color: Color.alphaBlend(
              toneColor.withValues(alpha: strong ? 0.5 : 0.28),
              base,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          ...leading,
          if (node.connectionStatus == ConnectionStatus.unprotected)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.lock_open,
                key: const ValueKey('card-unprotected'),
                size: 14,
                color: t.tertiary,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: AlertBadge(node: node),
          ),
        ],
      ),
    );
  }
}

/// *Offline* or *Login failed* in words, in place of the power and shutter
/// icons.
class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.of(context).caption
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The model (as read from the projector, so it often repeats) and the IP
/// that tells the cards apart, at the bottom of the body.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.node, required this.selected});

  final ProjectorNode node;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: const ValueKey('card-body'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
      decoration: selected
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary.withValues(alpha: 0.10),
                  primary.withValues(alpha: 0.16),
                ],
              ),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
          SizedBox(
            height: 16,
            child: Row(
              children: [
                // Scaled down rather than cut: the IP is what tells two
                // cards of the same model apart.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      node.ipAddress,
                      maxLines: 1,
                      style: t.monoSmall,
                    ),
                  ),
                ),
                // Shown whatever the shutter: the pattern is still set on the
                // projector and appears as soon as the shutter opens.
                if (isTestPatternActive(node.testPattern)) ...[
                  const SizedBox(width: 6),
                  TestPatternThumb(code: node.testPattern!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The group name on a band inside the bottom of the card, the group colour
/// muted into the card (variant C).
class _GroupBand extends StatelessWidget {
  const _GroupBand({required this.group, required this.card});

  final ProjectorGroup group;
  final Color card;

  @override
  Widget build(BuildContext context) {
    final band = groupBandColor(card, Color(group.color));
    final text = groupBandTextColor(band);
    final lightText = text.computeLuminance() > 0.5;
    return Container(
      key: const ValueKey('card-group-band'),
      height: kCardGroupBandHeight,
      color: band,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.of(context).caption.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
          height: 1,
          shadows: lightText
              ? const [
                  Shadow(
                    color: Color(0x59000000),
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// The context menu's first line: model and IP, which the menu acts on.
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.model, required this.ip});

  final String model;
  final String ip;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Padding(
      key: const ValueKey('card-menu-header'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(model, style: t.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(ip, style: t.monoSmall),
        ],
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 9,
      thickness: 1,
      indent: 6,
      endIndent: 6,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.6),
    );
  }
}
