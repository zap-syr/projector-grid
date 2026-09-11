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

  // Once the preview socket has actually produced a frame/notice, a later
  // connectionStatus flip to offline is treated as telemetry noise, not proof
  // the socket should close — NTCONTROL polling is known to misclassify a
  // busy projector as offline under load (see workspace_provider.dart), and
  // that channel is independent of this one. Without this, _isOffline below
  // would stop watching remotePreviewProvider on a false blip, and losing its
  // last watcher (the provider isn't keepAlive) tears down a working stream.
  bool _everConnected = false;

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
    if (_isOffline(node) && !_everConnected) {
      state = const RemotePreviewUnavailable();
    } else {
      state = ref.watch(remotePreviewProvider(node.ipAddress));
      if (state is RemotePreviewFrame || state is RemotePreviewNotice) {
        _everConnected = true;
      }
      // The projector's own web UI, not NTCONTROL, for the signal tag: QIN /
      // QVX:NSGS1 return ER401 whenever the projector isn't fully on, so a
      // poll-driven tag goes stale exactly when it matters (Standby +
      // pre-show, or mid power-on). This provider is event-driven off the
      // preview socket's own SIGNAL message — see its doc comment.
      webSignal = ref.watch(
        previewSignalStatusProvider(node.ipAddress, node.login, node.password),
      );
      // Mirror the preview's signal tag into the rest of the app (Monitoring
      // table) while powered on, so closing the dialog leaves current data
      // behind instead of whatever the last regular poll saw.
      // previewSignalStatusProvider already re-fetches on open, on every
      // SIGNAL event and on the first frame, so listening to it (rather than
      // to frame transitions alone) also catches a signal change mid-stream
      // that never leaves RemotePreviewFrame. Applied via applyWebSignal, not
      // refreshNode alone: NTCONTROL's own QVX:NSGS1 was found to lag the web
      // status by a noticeable margin even while fully on, so a poll right
      // after a SIGNAL event could still read the old value — applyWebSignal
      // writes the already-trusted value with no round trip. refreshNode
      // still runs too (cooldown-gated) for the rest of the telemetry
      // (shutter colour etc.); passing it the same value keeps it from ever
      // regressing what applyWebSignal just wrote. Skipped in Standby:
      // NTCONTROL can't report anything there anyway (see
      // previewSignalStatusProvider's doc comment) — the web-status tag alone
      // is authoritative in that case.
      ref.listen(
        previewSignalStatusProvider(node.ipAddress, node.login, node.password),
        (_, next) {
          if (next == null) return;
          final live = ref
              .read(workspaceProvider)
              .firstWhere(
                (n) => n.id == widget.node.id,
                orElse: () => widget.node,
              );
          if (live.powerStatus != PowerStatus.on) return;
          final notifier = ref.read(workspaceProvider.notifier);
          notifier.applyWebSignal(widget.node.id, next);
          notifier.refreshNode(widget.node.id, webSignal: next);
        },
      );
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
  // unlike NTCONTROL. previewSignalStatusProvider keeps its last known-good
  // value across a transient fetch failure, so the polled node fields below
  // are only a fallback until the very first fetch lands, not on every
  // failure — that would mean displaying NTCONTROL's own stale/ER401 reading
  // with no time bound, the exact staleness this tag exists to avoid.
  //  - web says a real signal  -> "HDMI1 · 3840x2160/60p (134.99kHz/59.99Hz)"
  //  - web says no signal      -> "No signal" (authoritative — built-in test
  //    pattern / no external input, in any power state)
  //  - no fetch has ever landed, polled value real -> that, same format
  //  - polled value also unusable  -> "No signal" if that's what NTCONTROL
  //    said, else no tag (nothing known yet)
  String? _signalTag(ProjectorNode node, WebSignalStatus? webSignal) {
    if (webSignal != null) {
      if (!webSignal.hasSignal) return 'No signal';
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
