import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/blend_edge.dart';
import '../../../domain/projector_node.dart';
import '../../providers/protocol_service_provider.dart';
import '../command_failure_notice.dart';
import '../common/dialog_split_layout.dart';
import '../common/projector_settings_client.dart';
import '../custom_tooltip.dart';
import '../dialog_title_bar.dart';
import 'black_level_panel.dart';
import 'edge_blend_canvas.dart';
import 'edge_blend_panel.dart';
import 'edge_blend_side.dart';
import 'edge_blend_state.dart';

/// The edge picked on the canvas or in the panel: arrows act on its [part],
/// Esc clears it.
typedef EdgeSelection = ({int side, BlendEdge edge, EdgePart part});

/// Edge Blending and Black Level for one projector. Takes a list so pair
/// mode (two projectors, plan §9) can be added without reshaping it.
class EdgeBlendingDialog extends ConsumerStatefulWidget {
  const EdgeBlendingDialog({super.key, required this.nodes})
    : assert(nodes.length == 1, 'pair mode (plan §9) is not built yet');

  final List<ProjectorNode> nodes;

  @override
  ConsumerState<EdgeBlendingDialog> createState() => _EdgeBlendingDialogState();
}

class _EdgeBlendingDialogState extends ConsumerState<EdgeBlendingDialog> {
  late final List<EdgeBlendSide> _sides = [
    for (final node in widget.nodes)
      EdgeBlendSide(
        node: node,
        client: ProjectorSettingsClient(
          service: ref.read(protocolServiceProvider),
          node: node,
          onFailure: (cmd) {
            if (mounted) notifyCommandFailure(context, cmd);
          },
        ),
      ),
  ];

  final int _active = 0;
  EdgeSelection? _selection;

  EdgeBlendSide get _side => _sides[_active];

  @override
  void initState() {
    super.initState();
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

  void _onSideChanged() => setState(() {});

  /// The selection keeps the last blend part (Start / Width) even when the
  /// Black Level tab picks the edge: arrows there move the border anyway,
  /// and back on the blend tab they act on what was grabbed last.
  void _select(BlendEdge edge, EdgePart part) {
    final keep = _selection?.edge == edge ? _selection!.part : EdgePart.start;
    setState(
      () => _selection = (
        side: _active,
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
    final side = _side;

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
                DialogTitleBar(title: 'Edge Blending - ${side.node.ipAddress}'),
                if (side.loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (side.unreachable)
                  Expanded(child: _buildNoReply(side, side.load))
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: SegmentedButton<EdgeBlendMode>(
                      segments: [
                        for (final m in EdgeBlendMode.values)
                          ButtonSegment(value: m, label: Text(m.label)),
                      ],
                      selected: {side.blend.mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => side.setMode(s.first),
                    ),
                  ),
                  const Divider(height: 1),
                  TabBar(
                    // Black Level loads on its first open: its ~17 queries
                    // are wasted if the user never goes there.
                    onTap: (i) {
                      if (i == 1 && side.black == null) side.loadBlack();
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
                      children: [
                        DialogSplitLayout(
                          left: _buildCanvas(side, blackTab: false),
                          right: _dimmedWhenOff(_buildBlendPanel(side)),
                        ),
                        _buildBlackTab(side),
                      ],
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

  /// The same canvas on both tabs; on Black Level its handles move the
  /// border widths, so the selection is shown as [EdgePart.border] there.
  Widget _buildCanvas(EdgeBlendSide side, {required bool blackTab}) {
    final edge = _selectedEdge;
    final interactive = side.blend.mode != EdgeBlendMode.off;
    final reset = blackTab ? side.resetBorder : side.resetEdge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: CustomTooltip(
            message: blackTab ? 'Reset all border widths' : 'Reset all edges',
            child: IconButton(
              icon: const Icon(Icons.restart_alt),
              iconSize: 20,
              onPressed: interactive
                  ? () => BlendEdge.values.forEach(reset)
                  : null,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: EdgeBlendCanvas(
              state: side.blend,
              black: blackTab ? side.black : null,
              raster: side.raster,
              interactive: interactive,
              selection: edge == null
                  ? null
                  : (
                      edge: edge,
                      part: blackTab ? EdgePart.border : _selection!.part,
                    ),
              onSelect: _select,
              onClearSelection: () => setState(() => _selection = null),
              onPreview: side.preview,
              onCommit: side.commit,
              onResetEdge: reset,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlackTab(EdgeBlendSide side) {
    final black = side.black;
    if (side.blackUnreachable) return _buildNoReply(side, side.loadBlack);
    if (black == null) return const Center(child: CircularProgressIndicator());
    return DialogSplitLayout(
      left: _buildCanvas(side, blackTab: true),
      right: _dimmedWhenOff(
        BlackLevelPanel(
          black: black,
          blend: side.blend,
          raster: side.raster,
          selectedEdge: _selectedEdge,
          onModeChanged: side.setBlackMode,
          onLevelChanged: (slot, channel, v) {
            final edge = slot.edge;
            if (edge != null && _selectedEdge != edge) {
              _select(edge, EdgePart.border);
            }
            side.previewLevel(slot, channel, v);
          },
          onLevelCommitted: side.commitLevel,
          onInterlockedChanged: side.setInterlocked,
          onBorderWidthChanged: (edge, v) {
            if (_selectedEdge != edge) _select(edge, EdgePart.border);
            side.preview(edge, EdgePart.border, v);
          },
          onBorderWidthCommitted: (edge) => side.commit(edge, EdgePart.border),
        ),
      ),
    );
  }

  Widget _buildBlendPanel(EdgeBlendSide side) {
    return EdgeBlendPanel(
      state: side.blend,
      raster: side.raster,
      selectedEdge: _selectedEdge,
      onMarkersChanged: side.setMarkers,
      onAutoPatternChanged: side.setAutoPattern,
      onEnabledChanged: side.setEnabled,
      onValueChanged: (edge, part, v) {
        if (_selection?.edge != edge || _selection?.part != part) {
          _select(edge, part);
        }
        side.preview(edge, part, v);
      },
      onValueCommitted: side.commit,
    );
  }

  Widget _buildNoReply(EdgeBlendSide side, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No reply from ${side.node.ipAddress}'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
