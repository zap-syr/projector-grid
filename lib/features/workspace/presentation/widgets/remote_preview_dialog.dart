import 'dart:async';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/remote_preview_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ip_ranges.dart';
import '../../domain/pre_show.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../providers/pre_show_provider.dart';
import '../providers/remote_preview_provider.dart';
import '../providers/workspace_provider.dart';
import 'common/dialog_parts.dart';
import 'common/status_pill.dart';
import 'dialog_title_bar.dart';
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

class RemotePreviewDialog extends ConsumerStatefulWidget {
  const RemotePreviewDialog({
    super.key,
    required this.nodes,
    this.groups = const {},
  });

  final List<ProjectorNode> nodes;
  final Map<String, ProjectorGroup> groups;

  @override
  ConsumerState<RemotePreviewDialog> createState() =>
      _RemotePreviewDialogState();
}

class _RemotePreviewDialogState extends ConsumerState<RemotePreviewDialog> {
  bool get _isMulti => widget.nodes.length > 1;

  // The grid's own Scrollbar needs an explicit controller shared with its
  // GridView — without one it falls back to PrimaryScrollController, which
  // has no ScrollPosition here and throws on every scroll.
  final _gridScrollController = ScrollController();

  // Grid tiles: the widest a tile gets, and the gap between tiles.
  static const double _maxCell = 300;
  static const double _spacing = 8;

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  ProjectorGroup? _groupOf(ProjectorNode n) =>
      n.groupId != null ? widget.groups[n.groupId] : null;

  // ── Pre-show (§4.3) ──────────────────────────────────────────────────────

  // Shared with a web page previewing the same projector (preShowProvider).
  PreShowState _preShow(ProjectorNode n) => ref.watch(preShowProvider(n.id));

  bool _wsConnected(ProjectorNode n) {
    final s = ref.watch(remotePreviewProvider(n.ipAddress));
    return s is RemotePreviewFrame || s is RemotePreviewNotice;
  }

  /// Standby + live feed — the only projectors pre-show can act on.
  List<ProjectorNode> _eligible(List<ProjectorNode> nodes) => [
    for (final n in nodes)
      if (n.powerStatus == PowerStatus.standby && _wsConnected(n)) n,
  ];

  void _setPreShow(List<ProjectorNode> targets, bool on) {
    for (final n in targets) {
      unawaited(ref.read(preShowProvider(n.id).notifier).set(on));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Live nodes so power/shutter/pre-show eligibility track polling.
    final live = ref.watch(workspaceProvider);
    final nodes = [
      for (final n in widget.nodes)
        live.firstWhere((x) => x.id == n.id, orElse: () => n),
    ];

    return Dialog(
      clipBehavior: Clip.antiAlias,
      // Maximum size, not a fixed one: the viewport(s) scale to the room the
      // app window leaves (down to 800×600), and only to that, so the dialog
      // keeps its size whatever the feed shows.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _isMulti ? 980 : 720,
          maxHeight: _isMulti ? 630 : 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _isMulti
                ? DialogTitleBar(
                    icon: Icons.monitor_outlined,
                    title: 'Remote Preview',
                    subtitle: _multiSubtitle(nodes),
                    badges: [_OnlineBadge(nodes: nodes)],
                    onClose: _close,
                  )
                : DialogTitleBar(
                    icon: Icons.monitor_outlined,
                    title: 'Remote Preview',
                    projectorId: nodes.first.id,
                    onClose: _close,
                  ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: LayoutBuilder(
                        // heightFactor 1: the plane's own height, not all
                        // the room it was offered, so the Pre-show card sits
                        // right under it.
                        builder: (context, box) => Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 1,
                          child: _isMulti
                              ? _grid(nodes, box.maxWidth, box.maxHeight)
                              : _single(nodes, box.maxWidth, box.maxHeight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _preShowCard(nodes),
                  ],
                ),
              ),
            ),
            const DialogFooter(message: _LiveNote(), actions: [_FrameLegend()]),
          ],
        ),
      ),
    );
  }

  void _close() {
    // Pre-show is sticky projector-side — leaving the dialog doesn't clear it.
    if (widget.nodes.any((n) => ref.read(preShowProvider(n.id)).on == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-show stays active on the projector')),
      );
    }
    Navigator.of(context).pop();
  }

  /// `8 projectors (192.168.0.41 to .48)`.
  String _multiSubtitle(List<ProjectorNode> nodes) {
    final runs = collapseIpRanges(nodes.map((n) => n.ipAddress));
    return '${nodes.length} projectors (${runs.map((r) => r.label()).join(', ')})';
  }

  // Width bounded by [maxWidth] and by [maxHeight] via the 16:9 ratio, so the
  // viewport never asks for more room than the dialog actually has (the
  // window can be resized smaller than the dialog's maximum).
  Widget _single(List<ProjectorNode> nodes, double maxWidth, double maxHeight) {
    final width = max(0.0, min(maxWidth, maxHeight * 16 / 9));
    return SizedBox(
      width: width,
      child: PreviewViewport(
        node: nodes.first,
        group: _groupOf(nodes.first),
        preShowActive: _preShow(nodes.first).on ?? false,
      ),
    );
  }

  Widget _grid(List<ProjectorNode> nodes, double maxWidth, double maxHeight) {
    // 2 up to four projectors, 3 beyond; more than two visible rows scrolls.
    final cols = nodes.length <= 4 ? 2 : 3;
    // A Scrollbar paints its thumb at the edge of its OWN render box, not
    // relative to whatever sits outside it — narrowing the Scrollbar/GridView
    // and leaving empty space beside them (padding or a sibling SizedBox,
    // both tried) does nothing, the thumb still draws flush against the last
    // tile because that's the edge of its box. The fix has to live on the
    // *inside*: keep the Scrollbar/GridView at the full width and give the
    // GridView itself right padding, so its own content (the tiles) stops
    // short of the edge the thumb draws at.
    const scrollbarGutter = 16.0;
    final visRows = (nodes.length / cols).ceil().clamp(1, 2);
    const caption = PreviewViewport.captionHeight;

    // Solve the per-tile width from both budgets (16:9 plane + the caption
    // strip per tile).
    final byWidth = (maxWidth - scrollbarGutter - (cols - 1) * _spacing) / cols;
    final byHeight =
        ((maxHeight - (visRows - 1) * _spacing) / visRows - caption) * 16 / 9;
    final cell = max(1.0, [byWidth, byHeight, _maxCell].reduce(min));
    final cellHeight = cell * 9 / 16 + caption;
    // Full width the Scrollbar/GridView occupy — tiles' share plus the
    // gutter, which the GridView's own padding carves out of this same box.
    final gridWidth = cols * cell + (cols - 1) * _spacing + scrollbarGutter;
    final gridHeight = visRows * cellHeight + (visRows - 1) * _spacing;

    return SizedBox(
      width: gridWidth,
      height: gridHeight,
      // One deliberate scrollbar, inside the grid's own gutter, not the
      // ambient desktop one (which drew over the rightmost tiles). Always on
      // (not just while scrolling): with more projectors than fit, a thumb
      // that only appears mid-scroll gives no advance warning there's more
      // below; harmless when nothing overflows (no thumb to show).
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _gridScrollController,
          thumbVisibility: true,
          thickness: 8,
          child: GridView.builder(
            controller: _gridScrollController,
            // The actual gutter: inset the grid's own content from the right
            // edge of this (full-width) box, where the Scrollbar draws.
            padding: const EdgeInsets.only(right: scrollbarGutter),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: _spacing,
              mainAxisSpacing: _spacing,
              childAspectRatio: cell / cellHeight,
            ),
            itemCount: nodes.length,
            itemBuilder: (_, i) => PreviewViewport(
              node: nodes[i],
              group: _groupOf(nodes[i]),
              showCaption: true,
              preShowActive: _preShow(nodes[i]).on ?? false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _preShowCard(List<ProjectorNode> nodes) {
    final bool value;
    final bool enabled;
    final bool applying;
    final String subtitle;
    final void Function(bool) onChanged;

    if (_isMulti) {
      // Watched for every projector, not just the eligible ones, so each
      // one in Standby reads its pre-show as soon as the dialog opens.
      final states = {for (final n in nodes) n.id: _preShow(n)};
      final eligible = _eligible(nodes);
      final onCount = eligible.where((n) => states[n.id]!.on == true).length;
      enabled = eligible.isNotEmpty;
      applying = eligible.any((n) => states[n.id]!.applying);
      value = eligible.isNotEmpty && onCount == eligible.length;
      final onPart = onCount == 0
          ? ''
          : onCount == eligible.length
          ? ', on'
          : ', $onCount on';
      subtitle =
          'In Standby with a live feed: ${eligible.length} of '
          '${nodes.length} projectors$onPart. Applies to every projector '
          'that can take it.';
      onChanged = (on) => _setPreShow(eligible, on);
    } else {
      final n = nodes.first;
      // Same requirement as multi's _eligible: without a connected preview
      // socket, setPreshow() sends over a WebSocket that isn't open — a
      // silent no-op the projector never confirms, leaving the switch stuck
      // showing ON with nothing actually applied.
      final live = n.powerStatus == PowerStatus.standby && _wsConnected(n);
      final state = _preShow(n);
      enabled = live;
      applying = state.applying;
      value = state.on ?? false;
      subtitle = n.powerStatus == PowerStatus.on
          ? 'Only in Standby: this projector is on'
          : live
          ? 'Keeps the input alive for preview, the projector stays off. '
                'Stays on after you close this window.'
          : 'Needs the live feed and Standby';
      onChanged = (on) => _setPreShow([n], on);
    }

    return _PreShowCard(
      value: value,
      subtitle: subtitle,
      applying: applying,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Pre-show as a card under the preview: the switch shows the state, the
/// subtitle says why it can or can't be used.
class _PreShowCard extends StatelessWidget {
  const _PreShowCard({
    required this.value,
    required this.subtitle,
    required this.applying,
    required this.onChanged,
  });

  final bool value;
  final String subtitle;
  final bool applying;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return DialogCard(
      key: const ValueKey('pre-show-card'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 14,
        children: [
          const DialogIconTile(Icons.visibility_outlined),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pre-show mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle,
                ),
                // Two lines held for every subtitle, so the card keeps its
                // height as the state changes.
                Stack(
                  children: [
                    Text('\n', maxLines: 2, style: t.description),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.description,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              // The slot is held while idle, so the switch doesn't move when
              // a change starts or is confirmed. An empty box, not a hidden
              // spinner: that one would keep animating.
              SizedBox(
                width: 16,
                height: 16,
                child: applying
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : null,
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// `6 of 8 online` in the title bar of the grid.
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.nodes});

  final List<ProjectorNode> nodes;

  @override
  Widget build(BuildContext context) {
    // Reachable counts as online; Wrong login is a status of its own.
    final online = nodes
        .where(
          (n) =>
              n.connectionStatus == ConnectionStatus.connected ||
              n.connectionStatus == ConnectionStatus.unprotected,
        )
        .length;
    final sc = AppStatusColors.of(context);
    final color = online == nodes.length
        ? sc.success
        : online == 0
        ? Theme.of(context).colorScheme.error
        : sc.warning;
    return StatusPill(
      label: '$online of ${nodes.length} online',
      color: color,
      dot: true,
    );
  }
}

class _LiveNote extends StatelessWidget {
  const _LiveNote();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.info_outline, size: 16, color: AppText.of(context).secondary),
      const SizedBox(width: 8),
      const Flexible(
        child: Text(
          'Live from the projector, about 1 frame a second',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// What the plane's frame colour means.
class _FrameLegend extends StatelessWidget {
  const _FrameLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppText.of(context).caption;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 14,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 2),
          ),
        ),
        Text(label, style: style),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        item(PreviewViewport.frameOpen, 'Shutter open'),
        item(PreviewViewport.frameClosed, 'Shutter closed'),
        item(PreviewViewport.frameNotOn(scheme), 'Not on'),
      ],
    );
  }
}
