import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/blend_edge.dart';
import '../../../domain/edge_blend_labels.dart';
import '../../../domain/edge_blend_pair.dart';
import '../../../domain/projector_node.dart';
import '../../providers/protocol_service_provider.dart';
import '../command_failure_notice.dart';
import '../common/controls_card.dart';
import '../common/dialog_parts.dart';
import '../common/mode_tile.dart';
import '../common/projector_settings_client.dart';
import '../common/segmented_tabs.dart';
import '../common/status_pill.dart';
import '../custom_tooltip.dart';
import '../dialog_title_bar.dart';
import '../geometry/geometry_split.dart';
import 'black_level_panel.dart';
import 'edge_blend_canvas.dart';
import 'edge_blend_canvas_card.dart';
import 'edge_blend_link.dart';
import 'edge_blend_panel.dart';
import 'edge_blend_parts.dart';
import 'edge_blend_side.dart';
import 'edge_blend_state.dart';

/// Edge Blending and Black Level for one projector, or for two in pair mode
/// (DIALOG_REDESIGN_PLAN §7a, EDGE_BLENDING_PLAN §9): mode tiles, the two
/// tabs, the canvas card beside the controls card, and an info footer.
/// Both rasters share one canvas in a pair, the controls show the active
/// one, and mode, Markers and Auto test pattern are written to both.
class EdgeBlendingDialog extends ConsumerStatefulWidget {
  const EdgeBlendingDialog({super.key, required this.nodes})
    : assert(nodes.length == 1 || nodes.length == 2);

  final List<ProjectorNode> nodes;

  /// The size cap; the dialog takes all of it (or all a smaller window
  /// leaves), so it never changes size between tabs, modes or states.
  static const double maxWidth = 960;
  static const double maxHeight = 800;

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

  bool get _blackTab => _tab == 1;

  static bool _ready(EdgeBlendSide s) => !s.loading && !s.unreachable;

  /// Shared writes skip a projector that never answered: it shows its own
  /// "No reply" and gets the values on Retry from the projector itself.
  Iterable<EdgeBlendSide> get _reachable => _sides.where(_ready);

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

  void _setTab(int tab) {
    setState(() => _tab = tab);
    _loadBlackIfShown();
  }

  /// Black Level loads per projector, the first time it's shown on that
  /// tab: its ~17 queries are wasted if the user never goes there. While
  /// linked the other projector loads too, so the overlapped level can
  /// mirror into it. After a failed load only Retry tries again.
  void _loadBlackIfShown() {
    if (!_blackTab) return;
    final link = _link;
    for (final side in _sides) {
      if (side != _side && !link.linked) continue;
      if (_ready(side) &&
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

  /// `B Left`: the other projector's facing edge, as the Link labels name
  /// it.
  String get _partnerName {
    final other = 1 - _active;
    return '${sideLetter(other)} ${_arrangement.facingOf(other).label}';
  }

  /// The facing edge's Link chip on the active projector's card; null in
  /// single mode.
  EdgeLinkControl? _linkControl() {
    if (!_pair) return null;
    final link = _link;
    final partner = _partnerName;
    final edge = _arrangement.facingOf(_active);
    if (link.mixedRasters) {
      return (
        edge: edge,
        on: false,
        label: 'Link unavailable',
        tooltip: "Different rasters: widths are in each projector's own units",
        onChanged: null,
      );
    }
    if (!link.available) {
      return (
        edge: edge,
        on: false,
        label: 'Link needs ${sideLetter(1 - _active)}',
        tooltip: 'Link needs both projectors',
        onChanged: null,
      );
    }
    return (
      edge: edge,
      on: link.linked,
      label: link.linked ? 'Linked with $partner' : 'Link with $partner',
      tooltip: link.linked
          ? 'On, Width and the overlapped black level also go to $partner. '
                'Click to unlink.'
          : 'Click to send on, Width and the overlapped black level to '
                '$partner as well.',
      onChanged: _setLink,
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

  void _reset(int side, BlendEdge edge) {
    _blackTab ? _sides[side].resetBorder(edge) : _link.resetEdge(side, edge);
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loading =
        _sides.any((s) => s.loading) || (_blackTab && _side.blackLoading);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        // A cap the dialog fills: one size on both tabs, in every mode and
        // state; the smallest window (800×600) leaves about 720×550.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: EdgeBlendingDialog.maxWidth,
            maxHeight: EdgeBlendingDialog.maxHeight,
          ),
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _modeTiles(),
                        const SizedBox(height: 16),
                        _tabs(),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GeometrySplit(
                            builder: (compact) =>
                                (_canvasCard(compact), _controlsCard()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DialogFooter(message: SentRightAwayNote(loading: loading)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBar() {
    if (!_pair) {
      return DialogTitleBar(
        icon: Icons.gradient,
        title: 'Edge Blending',
        projectorId: _side.node.id,
      );
    }
    final reply = pairReplyOf(
      (loading: _sides[0].loading, unreachable: _sides[0].unreachable),
      (loading: _sides[1].loading, unreachable: _sides[1].unreachable),
    );
    final t = AppText.of(context);
    final status = AppStatusColors.of(context);
    return DialogTitleBar(
      icon: Icons.gradient,
      title: 'Edge Blending',
      pairIds: (_sides[0].node.id, _sides[1].node.id),
      badges: [
        StatusPill(
          key: const ValueKey('edge-blend-pair-status'),
          label: pairReplyLabel(reply),
          dot: true,
          color: switch (reply) {
            PairReply.reading => t.tertiary,
            PairReply.online => status.success,
            PairReply.aSilent || PairReply.bSilent => status.warning,
            PairReply.bothSilent => Theme.of(context).colorScheme.error,
          },
        ),
      ],
    );
  }

  static IconData _modeIcon(EdgeBlendMode m) => switch (m) {
    EdgeBlendMode.off => Icons.block,
    EdgeBlendMode.on => Icons.auto_awesome_motion,
    EdgeBlendMode.user => Icons.show_chart,
  };

  /// Mixed modes in a pair select none; until a projector answers they're
  /// disabled.
  Widget _modeTiles() {
    final ready = _reachable.isNotEmpty;
    return ModeTileRow<EdgeBlendMode>(
      key: edgeBlendModeTilesKey,
      height: 54,
      iconAbove: false,
      selected: ready ? _shared((s) => s.blend.mode) : null,
      onSelected: ready
          ? (m) {
              for (final side in _reachable) {
                side.setMode(m);
              }
            }
          : null,
      tiles: [
        for (final m in EdgeBlendMode.values)
          ModeTileData(
            value: m,
            icon: _modeIcon(m),
            label: m.label,
            detail: m.detail,
          ),
      ],
    );
  }

  Widget _tabs() {
    final side = _side;
    final ready = _ready(side);
    return SegmentedTabs<int>(
      key: edgeBlendTabsKey,
      selected: _tab,
      onChanged: _setTab,
      tabs: [
        SegmentedTab(
          value: 0,
          label: 'Edge Blending',
          icon: Icons.auto_awesome_motion,
          pill: ready
              ? blendTabPill(
                  loaded: true,
                  off: side.blend.mode == EdgeBlendMode.off,
                  linked: _link.linked,
                  enabledEdges: BlendEdge.values
                      .where((e) => side.blend[e].enabled)
                      .length,
                )
              : null,
        ),
        SegmentedTab(
          value: 1,
          label: 'Black Level',
          icon: Icons.contrast,
          pill: side.black?.mode.pill,
        ),
      ],
    );
  }

  /// The canvas as seen by [EdgeBlendCanvas]: a projector that hasn't
  /// loaded is a placeholder in its place, so the pills stay there to
  /// switch to the other one.
  BlendCanvasSide _canvasSide(EdgeBlendSide s) {
    final ready = _ready(s);
    return BlendCanvasSide(
      node: s.node,
      raster: s.raster,
      state: ready ? s.blend : null,
      black: ready ? s.black : null,
      status: s.loading ? 'Reading from the projector' : '',
      unreachable: s.unreachable,
      onRetry: s.load,
    );
  }

  /// The silent one of a pair, while the other replies.
  int? get _silentSide {
    if (!_pair) return null;
    final silent = [
      for (var i = 0; i < 2; i++)
        if (_sides[i].unreachable) i,
    ];
    return silent.length == 1 ? silent.single : null;
  }

  Widget _canvasCard(bool compact) {
    final side = _side;
    final ready = _ready(side);
    final off = ready && side.blend.mode == EdgeBlendMode.off;
    final interactive = ready && !off && (!_blackTab || side.black != null);
    final sel = _selection;
    final silent = _silentSide;
    final reachable = _reachable.isNotEmpty;
    final onBoth = _pair && silent == null;
    String scope(String name) => silent != null
        ? '$name, sent to ${sideLetter(1 - silent)} only until '
              '${sideLetter(silent)} replies'
        : onBoth
        ? '$name on both projectors'
        : name;
    final togglesEnabled = reachable && !off;
    final ofA = _pair ? ' of ${sideLetter(_active)}' : '';
    final actions = [
      EdgeBlendToggle(
        key: const ValueKey('edge-blend-markers'),
        icon: Icons.width_normal,
        tooltip: scope('Markers'),
        detail: 'Start and zone end lines on the image',
        selected: reachable && (_shared((s) => s.blend.markers) ?? false),
        onChanged: togglesEnabled
            ? (on) {
                for (final s in _reachable) {
                  s.setMarkers(on);
                }
              }
            : null,
      ),
      const SizedBox(width: 6),
      EdgeBlendToggle(
        key: const ValueKey('edge-blend-auto-pattern'),
        icon: Icons.grid_on,
        tooltip: scope('Auto test pattern'),
        warning: _reachable.any((s) => s.autoPatternRefused)
            ? 'Not available while a test pattern is on'
            : null,
        selected: reachable && (_shared((s) => s.blend.autoPattern) ?? false),
        onChanged: togglesEnabled
            ? (on) {
                for (final s in _reachable) {
                  s.setAutoPattern(on);
                }
              }
            : null,
      ),
      const SizedBox(width: 2),
      CustomTooltip(
        message: _blackTab
            ? 'Reset all border widths$ofA'
            : 'Reset all edges$ofA',
        child: IconButton(
          key: const ValueKey('edge-blend-reset'),
          icon: const Icon(Icons.restart_alt, size: 18),
          onPressed: interactive
              ? () {
                  for (final edge in BlendEdge.values) {
                    _reset(_active, edge);
                  }
                }
              : null,
        ),
      ),
    ];
    return EdgeBlendCanvasCard(
      compact: compact,
      off: off,
      hint: _blackTab
          ? EdgeBlendHint.black
          : _pair
          ? EdgeBlendHint.pair
          : EdgeBlendHint.single,
      notice: silent == null
          ? null
          : '${sideLetter(silent)} is not replying: Markers and Auto test '
                'pattern go to ${sideLetter(1 - silent)} only until it does.',
      leading: _pair ? _arrangementControls(compact) : null,
      actions: actions,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: EdgeBlendCanvas(
          sides: [for (final s in _sides) _canvasSide(s)],
          active: _active,
          arrangement: _arrangement,
          blackTab: _blackTab,
          linked: _pair && _link.linked,
          compact: compact,
          selection: sel == null
              ? null
              : (
                  side: sel.side,
                  edge: sel.edge,
                  part: _blackTab ? EdgePart.border : sel.part,
                ),
          maxFor: _link.maxFor,
          onActivate: _setActive,
          onSelect: _select,
          onClearSelection: () => setState(() => _selection = null),
          onPreview: _link.preview,
          onCommit: _link.commit,
          onResetEdge: _reset,
        ),
      ),
    );
  }

  /// The width the arrangement tabs need with their names: each name in the
  /// selected tab's weight, the tab padding (12 a side) and the track's 3.
  double _arrangementWidth() {
    final style = AppText.of(context).body
        .copyWith(fontWeight: FontWeight.w600);
    var width = 6.0 + 2;
    for (final a in PairArrangement.values) {
      final painter = TextPainter(
        text: TextSpan(text: a.label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width += painter.width + 24 + 2;
      painter.dispose();
    }
    return width;
  }

  /// Side by side / Stacked and the swap button; icons only where the names
  /// don't fit (a narrow card), the names then in the tooltip.
  Widget _arrangementControls(bool narrowCard) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) => _arrangementTabs(
              narrowCard || constraints.maxWidth < _arrangementWidth(),
            ),
          ),
        ),
        const SizedBox(width: 2),
        CustomTooltip(
          message: 'Swap projectors',
          child: IconButton(
            icon: const Icon(Icons.swap_horiz, size: 18),
            onPressed: _swap,
          ),
        ),
      ],
    );
  }

  Widget _arrangementTabs(bool compact) {
    // Too narrow for the two named tabs: one button that shows the current
    // arrangement and switches to the other one.
    if (compact) {
      final next = PairArrangement.values.firstWhere((a) => a != _arrangement);
      return CustomTooltip(
        message: _arrangement.label,
        detail: 'Click for ${next.label.toLowerCase()}',
        child: IconButton(
          key: const ValueKey('edge-blend-arrangement'),
          icon: Icon(switch (_arrangement) {
            PairArrangement.sideBySide => Icons.view_column,
            PairArrangement.stacked => Icons.view_agenda,
          }, size: 18),
          onPressed: () => setState(() => _arrangement = next),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: CustomTooltip(
            message: 'Arrangement',
            detail: 'Side by side or stacked',
            child: SegmentedTabs<PairArrangement>(
              key: const ValueKey('edge-blend-arrangement'),
              expand: false,
              selected: _arrangement,
              onChanged: (a) => setState(() => _arrangement = a),
              tabs: [
                for (final a in PairArrangement.values)
                  SegmentedTab(value: a, label: a.label),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The A / B switch at the top of a pair's controls card, on both tabs.
  Widget? _projectorSwitch() {
    if (!_pair) return null;
    final t = AppText.of(context);
    final status = AppStatusColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    return ProjectorSwitch(
      key: const ValueKey('edge-blend-projector-switch'),
      selected: _active,
      onChanged: _setActive,
      items: [
        for (final (i, s) in _sides.indexed)
          (
            letter: sideLetter(i),
            ip: s.node.ipAddress,
            dot: s.unreachable
                ? error
                : s.loading
                ? t.tertiary
                : status.success,
          ),
      ],
    );
  }

  String get _edgesTitle => _pair ? 'Edges of ${sideLetter(_active)}' : 'Edges';

  Widget _controlsCard() {
    final side = _side;
    final top = _projectorSwitch();
    if (!_ready(side)) {
      return EdgeBlendControlsSkeleton(
        groups: _blackTab ? const [1, 4, 3, 3] : const [4],
        pulse: side.loading,
        top: top,
      );
    }
    if (!_blackTab) return _blendControls(side, top);
    final black = side.black;
    if (side.blackUnreachable) {
      return ControlsCard(
        key: edgeBlendControlsCardKey,
        groups: [
          ?top,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: NoReplyView(
              title: 'No reply',
              detail: 'The Black Level values could not be read',
              onRetry: side.loadBlack,
            ),
          ),
        ],
      );
    }
    if (black == null) {
      return EdgeBlendControlsSkeleton(
        groups: const [1, 4, 3, 3],
        pulse: true,
        top: top,
      );
    }
    final link = _link;
    return BlackLevelControls(
      black: black,
      blend: side.blend,
      raster: side.raster,
      selectedEdge: _selectedEdge,
      title: _edgesTitle,
      top: top,
      linked: link.linked
          ? (
              edge: _arrangement.facingOf(_active),
              tooltip: 'Linked with $_partnerName',
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
        if (_selectedEdge != edge) _select(_active, edge, EdgePart.border);
        side.preview(edge, EdgePart.border, v);
      },
      onBorderWidthCommitted: (edge) => side.commit(edge, EdgePart.border),
    );
  }

  Widget _blendControls(EdgeBlendSide side, Widget? top) {
    final link = _link;
    final other = sideLetter(1 - _active);
    return EdgeBlendControls(
      state: side.blend,
      raster: side.raster,
      selectedEdge: _selectedEdge,
      title: _edgesTitle,
      top: top,
      note: _pair
          ? 'Linked: on, Width and the overlapped black level go to $other '
                'as well. Start stays per projector.'
          : 'The tick on a track is the limit: the border lines of opposite '
                "edges never cross, so each edge's Start, Width and border "
                'limit the other.',
      maxFor: (edge, part) => link.maxFor(_active, edge, part),
      link: _linkControl(),
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
}
