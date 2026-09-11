import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/projector_web_status_service.dart';
import '../../../../core/services/remote_preview_service.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../providers/preview_signal_status_provider.dart';
import '../providers/remote_preview_provider.dart';
import '../providers/workspace_provider.dart';

/// One 16:9 preview surface: black plane, a 2 px frame coloured by the
/// projector's shutter, and the live JPEG or a status line. Used on its own in
/// the single dialog and as a grid cell (with [showCaption]) in the multiview.
class PreviewViewport extends ConsumerStatefulWidget {
  const PreviewViewport({
    super.key,
    required this.node,
    this.group,
    this.showCaption = false,
    this.preShowActive = false,
  });

  final ProjectorNode node;
  final ProjectorGroup? group;
  final bool showCaption;

  /// Draw a `PRE-SHOW` tag over the frame — the dialog owns the actual state
  /// (read via NTCONTROL `QVX:PSMI1`).
  final bool preShowActive;

  @override
  ConsumerState<PreviewViewport> createState() => _PreviewViewportState();
}

class _PreviewViewportState extends ConsumerState<PreviewViewport> {
  // The projector's own web preview draws this exact green when the shutter is
  // open; red when closed.
  static const _frameOpen = Color(0xFF6CFF6C);
  static const _frameClosed = Color(0xFFFF5F56);

  // A known-offline projector: skip opening a socket that would just time out
  // (matters when a multiview holds several). Retry forces an attempt anyway.
  bool _forced = false;

  // The live node from workspaceProvider (power/shutter/connection change as
  // polling runs); falls back to the passed-in snapshot if it's gone.
  ProjectorNode get _node => ref
      .read(workspaceProvider)
      .firstWhere((n) => n.id == widget.node.id, orElse: () => widget.node);

  bool _isOffline(ProjectorNode node) =>
      node.connectionStatus == ConnectionStatus.offline && !_forced;

  Color _frameColor(ProjectorNode node, ColorScheme scheme) {
    if (node.powerStatus != PowerStatus.on) return scheme.outline;
    return node.shutterStatus == ShutterStatus.open ? _frameOpen : _frameClosed;
  }

  void _retry() {
    if (_isOffline(_node)) {
      setState(() => _forced = true);
      return;
    }
    ref.read(remotePreviewProvider(_node.ipAddress).notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Track the live node so the shutter-coloured frame updates when a poll
    // reports the shutter opened/closed while the dialog is open.
    final node = ref
        .watch(workspaceProvider)
        .firstWhere((n) => n.id == widget.node.id, orElse: () => widget.node);
    final RemotePreviewState state;
    WebSignalStatus? webSignal;
    if (_isOffline(node)) {
      state = const RemotePreviewUnavailable();
    } else {
      state = ref.watch(remotePreviewProvider(node.ipAddress));
      // The projector's own web UI, not NTCONTROL, for the signal tag: QIN /
      // QVX:NSGS1 return ER401 whenever the projector isn't fully on, so a
      // poll-driven tag goes stale exactly when it matters (Standby +
      // pre-show, or mid power-on). This provider is event-driven off the
      // preview socket's own SIGNAL message — see its doc comment.
      webSignal = ref.watch(
        previewSignalStatusProvider(node.ipAddress, node.login, node.password),
      );
      // The first frame after a gap proves the input is live — pull fresh
      // telemetry for this node now instead of waiting for the next poll, so
      // the rest of the app (Monitoring table, shutter colour) is current too.
      ref.listen(remotePreviewProvider(node.ipAddress), (prev, next) {
        if (next is RemotePreviewFrame && prev is! RemotePreviewFrame) {
          ref.read(workspaceProvider.notifier).refreshNode(widget.node.id);
        }
      });
    }

    final plane = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: _frameColor(node, theme.colorScheme),
          width: 2,
        ),
      ),
      child: _content(state, node, webSignal, theme),
    );

    // Grid cell: the cell's aspect ratio fixes the height, so the plane fills
    // what's left after the caption. Single: drive the 16:9 shape ourselves.
    if (widget.showCaption) {
      return Column(
        children: [
          Expanded(child: plane),
          _caption(node, theme),
        ],
      );
    }
    return AspectRatio(aspectRatio: 16 / 9, child: plane);
  }

  Widget _content(
    RemotePreviewState state,
    ProjectorNode node,
    WebSignalStatus? webSignal,
    ThemeData theme,
  ) {
    switch (state) {
      case RemotePreviewConnecting():
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case RemotePreviewFrame(:final jpeg, :final overlay):
        // Pre-show wins the tag slot — it's the more actionable state.
        final tag = widget.preShowActive
            ? 'PRE-SHOW'
            : overlay?.label.toUpperCase();
        final signal = _signalTag(node, webSignal);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(jpeg, gaplessPlayback: true, fit: BoxFit.contain),
            if (tag != null) Positioned(left: 6, top: 6, child: _tag(tag)),
            if (signal != null)
              Positioned(right: 6, bottom: 6, child: _tag(signal)),
          ],
        );
      case RemotePreviewNotice(:final kind):
        // Pre-show is a projector-level mode, not a property of any one
        // signal reading — show it no matter what the current status is
        // (including NOSIGNAL), not just while a frame happens to be on
        // screen.
        final showText = kind != RemotePreviewNoticeKind.blank;
        if (!showText && !widget.preShowActive) {
          return const SizedBox.shrink();
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showText) _planeText(kind.label, theme),
            if (widget.preShowActive)
              Positioned(left: 6, top: 6, child: _tag('PRE-SHOW')),
          ],
        );
      case RemotePreviewUnavailable():
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _planeLabel('Preview not available', theme),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    }
  }

  Widget _planeText(String text, ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: _planeLabel(text, theme, center: true),
    ),
  );

  Widget _planeLabel(String text, ThemeData theme, {bool center = false}) =>
      Text(
        text,
        textAlign: center ? TextAlign.center : null,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
      );

  static bool _isRealSignal(String s) =>
      s.isNotEmpty &&
      s != '-' &&
      s != 'Timeout' &&
      s != 'ER401' &&
      s.toUpperCase() != 'NO SIGNAL';

  // Bottom-right tag for the live frame. Primary source is [webSignal] — the
  // projector's own web UI, event-driven off the preview socket's SIGNAL
  // message (see previewSignalStatusProvider); it works in every power state,
  // unlike NTCONTROL. Falls back to the polled node fields only until that
  // first fetch lands (or if it ever fails), so the tag isn't blank meanwhile.
  //  - web says a real signal  -> "HDMI1 · 3840x2160/60p (134.99kHz/59.99Hz)"
  //  - web says no signal      -> "No signal" (authoritative — built-in test
  //    pattern / no external input, in any power state)
  //  - web fetch pending/failed, polled value real -> that, same format
  //  - polled value also unusable  -> "No signal" if that's what NTCONTROL
  //    said, else no tag (nothing known yet)
  String? _signalTag(ProjectorNode node, WebSignalStatus? webSignal) {
    if (webSignal != null) {
      if (webSignal.signalName.isEmpty) return 'No signal';
      final input = webSignal.input.isNotEmpty ? webSignal.input : node.input;
      final freq = webSignal.signalFrequency;
      final detail = freq.isNotEmpty
          ? '${webSignal.signalName} ($freq)'
          : webSignal.signalName;
      return _isRealSignal(input) ? '$input · $detail' : detail;
    }
    final hasInput = _isRealSignal(node.input);
    if (_isRealSignal(node.signal)) {
      return hasInput ? '${node.input} · ${node.signal}' : node.signal;
    }
    if (node.signal.toUpperCase() == 'NO SIGNAL') return 'No signal';
    return null;
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _caption(ProjectorNode node, ThemeData theme) {
    final group = widget.group;
    final left = group != null ? '${node.name} · ${group.name}' : node.name;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            node.ipAddress,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
