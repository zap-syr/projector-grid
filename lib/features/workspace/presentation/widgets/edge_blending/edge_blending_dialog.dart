import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_pair.dart';
import '../../../domain/projector_node.dart';
import '../../providers/protocol_service_provider.dart';
import '../command_failure_notice.dart';
import '../common/dialog_split_layout.dart';
import '../common/projector_settings_client.dart';
import '../custom_tooltip.dart';
import '../dialog_title_bar.dart';
import 'black_level_panel.dart';
import 'edge_blend_canvas.dart';
import 'edge_blend_link.dart';
import 'edge_blend_panel.dart';
import 'edge_blend_side.dart';
import 'edge_blend_state.dart';

/// Edge Blending and Black Level for one projector, or for two in pair mode
/// (plan §9): both rasters on one canvas, the panel shows the active one,
/// and mode, Markers and Auto test pattern are written to both.
class EdgeBlendingDialog extends ConsumerStatefulWidget {
  const EdgeBlendingDialog({super.key, required this.nodes})
    : assert(nodes.length == 1 || nodes.length == 2);

  final List<ProjectorNode> nodes;

  @override
  ConsumerState<EdgeBlendingDialog> createState() => _EdgeBlendingDialogState();
}

class _EdgeBlendingDialogState extends ConsumerState<EdgeBlendingDialog> {
  /// In pair mode A (left / upper) first.
  late List<EdgeBlendSide> _sides;
  PairArrangement _arrangement = PairArrangement.sideBySide;

  int _active = 0;
  int _tab = 0;
  EdgeSelection? _selection;

  /// Pair mode's Link toggle, on by default (plan §9).
  bool _linkOn = true;

  /// The side whose overlapped level Link copies once both projectors'
  /// Black Level values have loaded (Link turned on before that).
  int? _levelCopyFrom;

  EdgeBlendSide get _side => _sides[_active];

  /// Every edit goes through here, so a linked facing edge mirrors.
  EdgeBlendLink get _link =>
      EdgeBlendLink(sides: _sides, arrangement: _arrangement, on: _linkOn);

  bool get _pair => _sides.length == 2;

  /// Shared writes skip a projector that never answered: it shows its own
  /// "No reply" and gets the values on Retry from the projector itself.
  Iterable<EdgeBlendSide> get _reachable =>
      _sides.where((s) => !s.loading && !s.unreachable);

  @override
  void initState() {
    super.initState();
    final service = ref.read(protocolServiceProvider);
    var nodes = widget.nodes;
    if (nodes.length == 2) {
      final guess = guessPairArrangement(
        (x: nodes[0].x, y: nodes[0].y),
        (x: nodes[1].x, y: nodes[1].y),
      );
      _arrangement = guess.arrangement;
      if (guess.swapped) nodes = nodes.reversed.toList();
    }
    _sides = [
      for (final node in nodes)
        EdgeBlendSide(
          node: node,
          client: ProjectorSettingsClient(
            service: service,
            node: node,
            onFailure: (cmd) {
              if (mounted) notifyCommandFailure(context, cmd);
            },
          ),
        ),
    ];
    // Each side's queryAll batches on its own projector, so the two loads
    // run in parallel without contending.
    for (final side in _sides) {
      side.addListener(_onSideChanged);
      side.load();
    }
  }

  @override
  void dispose() {
    for (final side in _sides) {
      side
        ..removeListener(_onSideChanged)
        ..dispose();
    }
    super.dispose();
  }

  /// A projector that finishes loading while it's active on Black Level
  /// starts that tab's load right away; a level copy waiting for it runs.
  void _onSideChanged() {
    setState(() {});
    _loadBlackIfShown();
    final from = _levelCopyFrom;
    // Cleared first: the copy's own writes notify straight back here.
    if (from != null && _sides.every((s) => s.black != null)) {
      _levelCopyFrom = null;
      _link.copyLevelFrom(from);
    }
  }

  void _setActive(int index) {
    if (index == _active) return;
    setState(() => _active = index);
    _loadBlackIfShown();
  }

  /// Black Level loads per projector, the first time it's shown on that
  /// tab: its ~17 queries are wasted if the user never goes there. While
  /// linked the other projector loads too, so the overlapped level can
  /// mirror into it. After a failed load only Retry tries again.
  void _loadBlackIfShown() {
    if (_tab != 1) return;
    final link = _link;
    for (final side in _sides) {
      if (side != _side && !link.linked) continue;
      if (!side.loading &&
          !side.unreachable &&
          side.black == null &&
          !side.blackLoading &&
          !side.blackUnreachable) {
        side.loadBlack();
      }
    }
  }

  /// Turning Link on with different values copies the active projector's
  /// facing edge to the other one. Its overlapped level waits for both
  /// Black Level loads when they haven't happened yet.
  void _setLink(bool on) {
    setState(() => _linkOn = on);
    _levelCopyFrom = null;
    if (on) {
      final link = _link..copyFrom(_active);
      if (!link.copyLevelFrom(_active)) _levelCopyFrom = _active;
    }
    _loadBlackIfShown();
  }

  /// The facing edge's Link toggle for the active projector's panel; null
  /// in single mode.
  EdgeLinkControl? _linkControl() {
    if (!_pair) return null;
    final link = _link;
    final other = 1 - _active;
    final otherName = _sides[other].node.name;
    final otherEdge = _arrangement.facingOf(other).label;
    return (
      edge: _arrangement.facingOf(_active),
      on: link.linked,
      tooltip: link.mixedRasters
          ? "Different rasters: widths are in each projector's own units"
          : !link.available
          ? 'Link needs both projectors'
          : link.linked
          ? 'Linked with $otherName $otherEdge'
          : 'Link with $otherName $otherEdge',
      onChanged: link.available ? _setLink : null,
    );
  }

  /// The selection follows its projector, so A and B swap places in the
  /// list but each keeps what was picked on it.
  void _swap() {
    setState(() {
      _sides = _sides.reversed.toList();
      _active = 1 - _active;
      final from = _levelCopyFrom;
      if (from != null) _levelCopyFrom = 1 - from;
      final s = _selection;
      if (s != null) {
        _selection = (side: 1 - s.side, edge: s.edge, part: s.part);
      }
    });
  }

  /// One value across the reachable projectors, or null when they differ
  /// (nothing shown as selected; picking a value writes it to both).
  T? _shared<T>(T Function(EdgeBlendSide s) get) {
    final values = _reachable.map(get).toSet();
    return values.length == 1 ? values.first : null;
  }

  /// The selection keeps the last blend part (Start / Width) even when the
  /// Black Level tab picks the edge: arrows there move the border anyway,
  /// and back on the blend tab they act on what was grabbed last. Picking
  /// the other projector's edge on the canvas makes it the active one.
  void _select(int side, BlendEdge edge, EdgePart part) {
    final s = _selection;
    final keep = s != null && s.side == side && s.edge == edge
        ? s.part
        : EdgePart.start;
    _setActive(side);
    setState(
      () => _selection = (
        side: side,
        edge: edge,
        part: part == EdgePart.border ? keep : part,
      ),
    );
  }

  BlendEdge? get _selectedEdge {
    final selection = _selection;
    return selection != null && selection.side == _active
        ? selection.edge
        : null;
  }

  /// Esc clears the selection first; only an Esc with nothing selected
  /// bubbles on and closes the dialog.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _selection != null) {
      setState(() => _selection = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final title = _pair
        ? _sides.map((s) => s.node.name).join(', ')
        : _side.node.ipAddress;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 560,
            maxWidth: 960,
            maxHeight: screenHeight * 0.9,
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DialogTitleBar(title: 'Edge Blending - $title'),
                if (_reachable.isEmpty)
                  Expanded(
                    child: _sides.any((s) => s.loading)
                        ? const Center(child: CircularProgressIndicator())
                        : _buildNoReply(_sides, () {
                            for (final s in _sides) {
                              s.load();
                            }
                          }),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: SegmentedButton<EdgeBlendMode>(
                      segments: [
                        for (final m in EdgeBlendMode.values)
                          ButtonSegment(value: m, label: Text(m.label)),
                      ],
                      selected: {?_shared((s) => s.blend.mode)},
                      // Mixed modes in a pair: no segment is selected.
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        for (final side in _reachable) {
                          side.setMode(s.first);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  TabBar(
                    onTap: (i) {
                      _tab = i;
                      _loadBlackIfShown();
                    },
                    tabs: const [
                      Tab(text: 'Edge Blending'),
                      Tab(text: 'Black Level'),
                    ],
                    labelStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      // Horizontal handle drags on the canvas must never
                      // turn into a tab swipe.
                      physics: const NeverScrollableScrollPhysics(),
                      children: [_buildBlendTab(), _buildBlackTab()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Off greys out the controls but keeps them in place (and their State),
  /// so the zones stay readable; the projector itself accepts writes while
  /// Off, this is only a cue that they have no effect.
  Widget _dimmedWhenOff(Widget child) {
    final off = _side.blend.mode == EdgeBlendMode.off;
    return IgnorePointer(
      ignoring: off,
      child: AnimatedOpacity(
        opacity: off ? 0.38 : 1,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
    );
  }

  /// The active projector's own load state on the Edge Blending tab, or
  /// null once it's ready. In a pair the other projector stays usable.
  Widget? _blendStatus(EdgeBlendSide side) {
    if (side.loading) return const Center(child: CircularProgressIndicator());
    if (side.unreachable) return _buildNoReply([side], side.load);
    return null;
  }

  Widget? _blackStatus(EdgeBlendSide side) {
    final status = _blendStatus(side);
    if (status != null) return status;
    if (side.blackUnreachable) return _buildNoReply([side], side.loadBlack);
    if (side.black == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }

  Widget _buildBlendTab() {
    final side = _side;
    final status = _blendStatus(side);
    return DialogSplitLayout(
      left: _buildLeft(blackTab: false, ready: status == null),
      right: _buildRight(
        status ?? _buildBlendPanel(side),
        ready: status == null,
      ),
    );
  }

  /// The canvas as seen by [EdgeBlendCanvas]: a projector that hasn't
  /// loaded is a labelled placeholder, so the pills stay there to switch
  /// to the other one.
  BlendCanvasSide _canvasSide(EdgeBlendSide s) {
    final ready = !s.loading && !s.unreachable;
    return BlendCanvasSide(
      node: s.node,
      raster: s.raster,
      state: ready ? s.blend : null,
      black: ready ? s.black : null,
      status: s.loading ? 'Loading' : 'No reply',
    );
  }

  /// The pair controls and Reset all over the canvas, which is the same on
  /// both tabs; on Black Level its handles move the border widths, so the
  /// selection is shown as [EdgePart.border] there. [ready]: the active
  /// projector has its values for this tab.
  Widget _buildLeft({required bool blackTab, required bool ready}) {
    final side = _side;
    final sel = _selection;
    final interactive = ready && side.blend.mode != EdgeBlendMode.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_pair) ...[
              const SizedBox(width: 12),
              SegmentedButton<PairArrangement>(
                segments: [
                  for (final a in PairArrangement.values)
                    ButtonSegment(value: a, label: Text(a.label)),
                ],
                selected: {_arrangement},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (s) =>
                    setState(() => _arrangement = s.first),
              ),
              CustomTooltip(
                message: 'Swap projectors',
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  iconSize: 20,
                  onPressed: _swap,
                ),
              ),
            ],
            const Spacer(),
            CustomTooltip(
              message: blackTab ? 'Reset all border widths' : 'Reset all edges',
              child: IconButton(
                icon: const Icon(Icons.restart_alt),
                iconSize: 20,
                onPressed: interactive
                    ? () {
                        for (final edge in BlendEdge.values) {
                          _reset(_active, edge, blackTab: blackTab);
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: EdgeBlendCanvas(
              sides: [for (final s in _sides) _canvasSide(s)],
              active: _active,
              arrangement: _arrangement,
              blackTab: blackTab,
              selection: sel == null
                  ? null
                  : (
                      side: sel.side,
                      edge: sel.edge,
                      part: blackTab ? EdgePart.border : sel.part,
                    ),
              maxFor: _link.maxFor,
              onActivate: _setActive,
              onSelect: _select,
              onClearSelection: () => setState(() => _selection = null),
              onPreview: _link.preview,
              onCommit: _link.commit,
              onResetEdge: (i, edge) => _reset(i, edge, blackTab: blackTab),
            ),
          ),
        ),
      ],
    );
  }

  void _reset(int side, BlendEdge edge, {required bool blackTab}) {
    blackTab ? _sides[side].resetBorder(edge) : _link.resetEdge(side, edge);
  }

  /// The panel, under the active projector's header in a pair. The header
  /// isn't dimmed by Off: it names whose values these are. Until [ready],
  /// [panel] is the active projector's load state.
  Widget _buildRight(Widget panel, {required bool ready}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pair) _buildPanelHeader(),
        if (ready)
          _dimmedWhenOff(panel)
        else
          Padding(padding: const EdgeInsets.only(top: 48), child: panel),
      ],
    );
  }

  Widget _buildPanelHeader() {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final node = _side.node;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  node.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(node.ipAddress, style: muted),
              const Spacer(),
              Text('Switch on the canvas', style: muted),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildBlackTab() {
    final side = _side;
    final status = _blackStatus(side);
    final link = _link;
    final linkedEdge = _arrangement.facingOf(_active);
    final other = 1 - _active;
    return DialogSplitLayout(
      left: _buildLeft(blackTab: true, ready: status == null),
      right: _buildRight(
        ready: status == null,
        status ??
            BlackLevelPanel(
              black: side.black!,
              blend: side.blend,
              raster: side.raster,
              selectedEdge: _selectedEdge,
              linked: link.linked
                  ? (
                      edge: linkedEdge,
                      tooltip:
                          'Linked with ${_sides[other].node.name} '
                          '${_arrangement.facingOf(other).label}',
                    )
                  : null,
              onModeChanged: side.setBlackMode,
              onLevelChanged: (slot, channel, v) {
                final edge = slot.edge;
                if (edge != null && _selectedEdge != edge) {
                  _select(_active, edge, EdgePart.border);
                }
                link.previewLevel(_active, slot, channel, v);
              },
              onLevelCommitted: (slot) => link.commitLevel(_active, slot),
              onInterlockedChanged: (slot, on) =>
                  link.setInterlocked(_active, slot, on),
              onBorderWidthChanged: (edge, v) {
                if (_selectedEdge != edge) {
                  _select(_active, edge, EdgePart.border);
                }
                side.preview(edge, EdgePart.border, v);
              },
              onBorderWidthCommitted: (edge) =>
                  side.commit(edge, EdgePart.border),
            ),
      ),
    );
  }

  /// Markers and Auto test pattern are shared: they show on only when on
  /// for both, and a toggle writes both.
  Widget _buildBlendPanel(EdgeBlendSide side) {
    final link = _link;
    return EdgeBlendPanel(
      state: side.blend.copyWith(
        markers: _shared((s) => s.blend.markers) ?? false,
        autoPattern: _shared((s) => s.blend.autoPattern) ?? false,
      ),
      raster: side.raster,
      selectedEdge: _selectedEdge,
      maxFor: (edge, part) => link.maxFor(_active, edge, part),
      link: _linkControl(),
      onMarkersChanged: (on) {
        for (final s in _reachable) {
          s.setMarkers(on);
        }
      },
      onAutoPatternChanged: (on) {
        for (final s in _reachable) {
          s.setAutoPattern(on);
        }
      },
      autoPatternRefused: _reachable.any((s) => s.autoPatternRefused),
      onEnabledChanged: (edge, on) => link.setEnabled(_active, edge, on),
      onValueChanged: (edge, part, v) {
        if (_selectedEdge != edge || _selection?.part != part) {
          _select(_active, edge, part);
        }
        link.preview(_active, edge, part, v);
      },
      onValueCommitted: (edge, part) => link.commit(_active, edge, part),
    );
  }

  Widget _buildNoReply(List<EdgeBlendSide> sides, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No reply from ${sides.map((s) => s.node.ipAddress).join(', ')}',
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
