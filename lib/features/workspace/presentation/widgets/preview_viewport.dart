import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/projector_web_status_service.dart';
import '../../../../core/services/remote_preview_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../../domain/preview_signal_tag.dart';
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

  /// A grid cell: smaller corners and tag insets, a compact "not available"
  /// notice, and the caption (group dot, model, IP) under the plane.
  final bool showCaption;

  /// Draw a `PRE-SHOW` tag over the frame — the dialog owns the actual state
  /// (read via NTCONTROL `QVX:PSMI1`).
  final bool preShowActive;

  // The projector's own web preview draws this exact green when the shutter is
  // open; red when closed. Public for the dialog's frame colour legend.
  static const frameOpen = Color(0xFF6CFF6C);
  static const frameClosed = Color(0xFFFF5F56);

  /// The frame when the projector isn't on.
  static Color frameNotOn(ColorScheme scheme) => scheme.outline;

  /// The gap above the caption plus the caption itself: the grid adds it to
  /// a tile's 16:9 plane.
  static const double captionHeight = 25;

  @override
  ConsumerState<PreviewViewport> createState() => _PreviewViewportState();
}

class _PreviewViewportState extends ConsumerState<PreviewViewport> {
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
    if (node.powerStatus != PowerStatus.on) {
      return PreviewViewport.frameNotOn(scheme);
    }
    return node.shutterStatus == ShutterStatus.open
        ? PreviewViewport.frameOpen
        : PreviewViewport.frameClosed;
  }

  bool get _inGrid => widget.showCaption;

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
      key: const ValueKey('preview-plane'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(_inGrid ? 8 : 10),
        border: Border.all(
          color: _frameColor(node, theme.colorScheme),
          width: 2,
        ),
      ),
      child: _content(state, node, webSignal),
    );

    // Grid cell: the cell's aspect ratio fixes the height, so the plane fills
    // what's left after the caption. Single: drive the 16:9 shape ourselves.
    if (_inGrid) {
      return Column(
        children: [
          Expanded(child: plane),
          _caption(node),
        ],
      );
    }
    return AspectRatio(aspectRatio: 16 / 9, child: plane);
  }

  Widget _content(
    RemotePreviewState state,
    ProjectorNode node,
    WebSignalStatus? webSignal,
  ) {
    final inset = _inGrid ? 6.0 : 8.0;
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
        final signal = previewSignalTag(node, webSignal);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(jpeg, gaplessPlayback: true, fit: BoxFit.contain),
            if (tag != null)
              Positioned(left: inset, top: inset, child: _PlaneTag(tag)),
            if (signal != null)
              Positioned(
                right: inset,
                bottom: inset,
                // A long tag on a small grid tile ends in an ellipsis
                // instead of running past the plane.
                left: inset,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: _PlaneTag(signal),
                ),
              ),
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
            if (showText)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    kind.label,
                    textAlign: TextAlign.center,
                    style: _planeText(context),
                  ),
                ),
              ),
            if (widget.preShowActive)
              Positioned(
                left: inset,
                top: inset,
                child: const _PlaneTag('PRE-SHOW'),
              ),
          ],
        );
      case RemotePreviewUnavailable():
        return _unavailable();
    }
  }

  /// Text on the black plane: light in both themes, the plane is black.
  TextStyle _planeText(BuildContext context) =>
      AppText.of(context).description.copyWith(color: Colors.white70);

  Widget _unavailable() {
    final t = AppText.of(context);
    final retry = OutlinedButton.icon(
      onPressed: _retry,
      // White on the black plane, where the theme's buttons don't read.
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Retry'),
    );
    // A grid tile has room for the title and Retry only.
    final children = _inGrid
        ? [Text('Preview not available', style: _planeText(context)), retry]
        : [
            const Icon(
              Icons.desktop_access_disabled_outlined,
              size: 30,
              color: Colors.white54,
            ),
            Text(
              'Preview not available',
              style: t.body.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              "The projector's web page did not answer.",
              textAlign: TextAlign.center,
              style: _planeText(context),
            ),
            retry,
          ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        // Scales down rather than overflowing on a very small plane.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _inGrid ? 8 : 10,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _caption(ProjectorNode node) {
    final t = AppText.of(context);
    final group = widget.group;
    // The model alone repeats across a rig, so the IP is always there; a
    // projector whose model isn't known yet shows the IP once.
    final model = node.name == node.ipAddress ? '' : node.name;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: SizedBox(
        height: PreviewViewport.captionHeight - 5,
        child: Row(
          children: [
            if (group != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(group.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.description.copyWith(
                  fontWeight: FontWeight.w600,
                  color: t.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(node.ipAddress, style: t.monoSmall),
          ],
        ),
      ),
    );
  }
}

/// A tag over the plane (`PRE-SHOW`, the signal): a dark translucent pill
/// with white text, readable over any frame.
class _PlaneTag extends StatelessWidget {
  const _PlaneTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: ShapeDecoration(
      color: Colors.black.withValues(alpha: 0.62),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.of(context).caption
          .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
    ),
  );
}
