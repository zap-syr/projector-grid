import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/panasonic_protocol_service.dart';
import '../../../../core/services/remote_preview_service.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../providers/remote_preview_provider.dart';
import '../providers/workspace_provider.dart';
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
  final _service = PanasonicProtocolService();

  bool get _isMulti => widget.nodes.length > 1;

  // Pre-show state per projector IP, from NTCONTROL QVX:PSMI1. Absent = unknown.
  final Map<String, bool> _preShow = {};
  // IPs whose pre-show change we've sent but the projector hasn't confirmed yet
  // (entering pre-show takes ~12 s to report back).
  final Set<String> _applying = {};
  // Bumped on every toggle so a superseded confirmation loop bails out.
  int _psGen = 0;

  // The grid's own Scrollbar needs an explicit controller shared with its
  // GridView — without one it falls back to PrimaryScrollController, which
  // has no ScrollPosition here and throws on every scroll.
  final _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPreShow(widget.nodes);
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  ProjectorGroup? _groupOf(ProjectorNode n) =>
      n.groupId != null ? widget.groups[n.groupId] : null;

  // ── Pre-show (§4.3) ──────────────────────────────────────────────────────

  static bool? _parsePsmi(String? response) {
    if (response == null) return null;
    final i = response.indexOf('PSMI1=');
    if (i < 0) return null;
    final v = response.substring(i + 6).trim();
    if (v.startsWith('+00001')) return true;
    if (v.startsWith('+00000')) return false;
    return null;
  }

  Future<void> _loadPreShow(Iterable<ProjectorNode> nodes) async {
    for (final n in nodes) {
      if (n.powerStatus != PowerStatus.standby) continue;
      final resp = await _service.sendRawCommand(
        n.ipAddress,
        n.port,
        n.login,
        n.password,
        'QVX:PSMI1',
      );
      final on = _parsePsmi(resp);
      if (!mounted) return;
      if (on != null) setState(() => _preShow[n.ipAddress] = on);
    }
  }

  bool _wsConnected(ProjectorNode n) {
    final s = ref.watch(remotePreviewProvider(n.ipAddress));
    return s is RemotePreviewFrame || s is RemotePreviewNotice;
  }

  /// Standby + live feed — the only projectors pre-show can act on.
  List<ProjectorNode> _eligible(List<ProjectorNode> nodes) => [
    for (final n in nodes)
      if (n.powerStatus == PowerStatus.standby && _wsConnected(n)) n,
  ];

  Future<void> _setPreShow(List<ProjectorNode> targets, bool on) async {
    if (targets.isEmpty) return;
    final gen = ++_psGen;
    for (final n in targets) {
      ref.read(remotePreviewProvider(n.ipAddress).notifier).setPreshow(on);
    }
    // Reflect the intent immediately — the WebSocket command has no reply, and
    // the projector takes seconds (≈12 s to enter pre-show) to report the new
    // state over NTCONTROL.
    setState(() {
      for (final n in targets) {
        _preShow[n.ipAddress] = on;
        _applying.add(n.ipAddress);
      }
    });

    // Confirm in the background: poll QVX:PSMI1 until it reports the value we
    // asked for (ignoring transient ER401 during the transition), or give up
    // after a generous window and keep the optimistic value.
    final pending = {for (final n in targets) n.ipAddress: n};
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (mounted &&
        _psGen == gen &&
        pending.isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _psGen != gen) return;
      for (final entry in pending.entries.toList()) {
        final n = entry.value;
        final back = _parsePsmi(
          await _service.sendRawCommand(
            n.ipAddress,
            n.port,
            n.login,
            n.password,
            'QVX:PSMI1',
          ),
        );
        if (!mounted || _psGen != gen) return;
        if (back == on) {
          pending.remove(entry.key);
          setState(() => _applying.remove(entry.key));
        }
      }
    }
    if (mounted && _psGen == gen) {
      setState(() => _applying.removeAll(pending.keys));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Live nodes so power/shutter/pre-show eligibility track polling.
    final live = ref.watch(workspaceProvider);
    final nodes = [
      for (final n in widget.nodes)
        live.firstWhere((x) => x.id == n.id, orElse: () => n),
    ];

    // The app window (desktop, so MediaQuery is the window's own client area)
    // can be resized smaller than this dialog's natural size — size the
    // viewport(s) to what's actually available instead of a fixed pixel
    // budget. Chrome estimate: AlertDialog's default insetPadding (40
    // horizontal / 24 vertical each side) + title bar + divider + content
    // padding + the gap + the pre-show row + the actions row. A
    // SingleChildScrollView below is the safety net for any shortfall in
    // that estimate rather than a hard overflow.
    final viewport = MediaQuery.sizeOf(context);
    final maxContentWidth = (viewport.width - 80 - 32).clamp(160.0, 900.0);
    final maxContentHeight = (viewport.height - 48 - 210).clamp(120.0, 900.0);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(16),
      title: DialogTitleBar(title: _title(nodes), onClose: _close),
      content: ScrollConfiguration(
        // One deliberate Scrollbar, inside _grid's own gutter — not the
        // ambient auto-scrollbar this and the nested GridView would each
        // otherwise get, which is what was drawing over the rightmost tiles.
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Align, not a bare child: under crossAxisAlignment.stretch a
              // Column forces every direct child to its own (wider)
              // cross-axis size, silently overriding the width _grid/_single
              // computed. Align gives its child loose constraints so it keeps
              // exactly the size it asked for.
              Align(
                child: _isMulti
                    ? _grid(nodes, maxContentWidth, maxContentHeight)
                    : _single(nodes, maxContentWidth, maxContentHeight),
              ),
              if (_isMulti) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
              const SizedBox(height: 12),
              _preShowStrip(nodes, theme),
            ],
          ),
        ),
      ),
    );
  }

  void _close() {
    // Pre-show is sticky projector-side — leaving the dialog doesn't clear it.
    if (_preShow.containsValue(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-show stays active on the projector')),
      );
    }
    Navigator.of(context).pop();
  }

  String _title(List<ProjectorNode> nodes) {
    if (_isMulti) return 'Remote Preview - ${nodes.length} projectors';
    final n = nodes.first;
    final group = _groupOf(n);
    final tail = group != null ? ' · ${group.name}' : '';
    return 'Remote Preview - ${n.name} ${n.ipAddress}$tail';
  }

  // Width bounded by [maxWidth] and by [maxHeight] via the 16:9 ratio, so the
  // viewport never asks for more room than the dialog actually has (the
  // window can be resized smaller than any fixed pixel budget).
  Widget _single(List<ProjectorNode> nodes, double maxWidth, double maxHeight) {
    final width = [640.0, maxWidth, maxHeight * 16 / 9].reduce(min);
    return SizedBox(
      width: width,
      child: PreviewViewport(
        node: nodes.first,
        group: _groupOf(nodes.first),
        preShowActive: _preShow[nodes.first.ipAddress] ?? false,
      ),
    );
  }

  Widget _grid(List<ProjectorNode> nodes, double maxWidth, double maxHeight) {
    // 2 up to four projectors, 3 beyond; more than two visible rows scrolls.
    final cols = nodes.length <= 4 ? 2 : 3;
    const spacing = 8.0;
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

    // Solve the per-tile width from both budgets (16:9 plane + ~28px caption
    // strip per tile), then clamp to a sane usable range.
    final byWidth = (maxWidth - scrollbarGutter - (cols - 1) * spacing) / cols;
    final byHeight =
        ((maxHeight - (visRows - 1) * spacing) / visRows - 28) * 16 / 9;
    final cell = [byWidth, byHeight, 300.0].reduce(min).clamp(120.0, 340.0);
    final cellHeight = cell * 9 / 16 + 28;
    // Full width the Scrollbar/GridView occupy — tiles' share plus the
    // gutter, which the GridView's own padding carves out of this same box.
    final gridWidth = cols * cell + (cols - 1) * spacing + scrollbarGutter;
    final gridHeight = visRows * cellHeight + (visRows - 1) * spacing;

    return SizedBox(
      width: gridWidth,
      height: gridHeight,
      // The dialog's ScrollConfiguration turns off the ambient
      // auto-scrollbar (see build()); this is the one deliberate scrollbar.
      // Always on (not just while scrolling) — with more projectors than
      // fit, a thumb that only appears mid-scroll gives no advance warning
      // there's more below; harmless when nothing overflows (no thumb to
      // show).
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
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cell / cellHeight,
          ),
          itemCount: nodes.length,
          itemBuilder: (_, i) => PreviewViewport(
            node: nodes[i],
            group: _groupOf(nodes[i]),
            showCaption: true,
            preShowActive: _preShow[nodes[i].ipAddress] ?? false,
          ),
        ),
      ),
    );
  }

  Widget _preShowStrip(List<ProjectorNode> nodes, ThemeData theme) {
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    final bool value;
    final bool enabled;
    final bool applying;
    final String subtitle;
    final void Function(bool) onChanged;

    if (_isMulti) {
      final eligible = _eligible(nodes);
      final onCount = eligible
          .where((n) => _preShow[n.ipAddress] == true)
          .length;
      enabled = eligible.isNotEmpty;
      applying = eligible.any((n) => _applying.contains(n.ipAddress));
      value = eligible.isNotEmpty && onCount == eligible.length;
      subtitle =
          'Standby + live feed: ${eligible.length} of ${nodes.length}'
          '${onCount > 0 ? ' · $onCount on' : ''}';
      onChanged = (on) => _setPreShow(eligible, on);
    } else {
      final n = nodes.first;
      final standby = n.powerStatus == PowerStatus.standby;
      enabled = standby;
      applying = _applying.contains(n.ipAddress);
      value = _preShow[n.ipAddress] ?? false;
      subtitle = standby
          ? 'Keeps the input alive for preview; projector stays off'
          : 'Enabled only in Standby — this projector is on';
      onChanged = (on) => _setPreShow([n], on);
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pre-show mode', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(applying ? '$subtitle · applying…' : subtitle, style: hint),
            ],
          ),
        ),
        if (applying)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ],
    );
  }
}
