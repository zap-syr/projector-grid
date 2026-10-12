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

  void _select(BlendEdge edge, EdgePart part) =>
      setState(() => _selection = (side: _active, edge: edge, part: part));

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
                  Expanded(child: _buildUnreachable(side))
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
                          left: _buildBlendCanvas(side),
                          right: _dimmedWhenOff(_buildBlendPanel(side)),
                        ),
                        const SizedBox.shrink(),
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

  Widget _buildBlendCanvas(EdgeBlendSide side) {
    final selection = _selection;
    final interactive = side.blend.mode != EdgeBlendMode.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: CustomTooltip(
            message: 'Reset all edges',
            child: IconButton(
              icon: const Icon(Icons.restart_alt),
              iconSize: 20,
              onPressed: interactive
                  ? () => BlendEdge.values.forEach(side.resetEdge)
                  : null,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: EdgeBlendCanvas(
              state: side.blend,
              raster: side.raster,
              interactive: interactive,
              selection: selection != null && selection.side == _active
                  ? (edge: selection.edge, part: selection.part)
                  : null,
              onSelect: _select,
              onClearSelection: () => setState(() => _selection = null),
              onPreview: side.preview,
              onCommit: side.commit,
              onResetEdge: side.resetEdge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlendPanel(EdgeBlendSide side) {
    final selection = _selection;
    return EdgeBlendPanel(
      state: side.blend,
      raster: side.raster,
      selectedEdge: selection != null && selection.side == _active
          ? selection.edge
          : null,
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

  Widget _buildUnreachable(EdgeBlendSide side) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No reply from ${side.node.ipAddress}'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: side.load, child: const Text('Retry')),
        ],
      ),
    );
  }
}
