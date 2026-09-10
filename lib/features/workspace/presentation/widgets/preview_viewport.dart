import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/remote_preview_service.dart';
import '../../domain/projector_group.dart';
import '../../domain/projector_node.dart';
import '../providers/remote_preview_provider.dart';

/// One 16:9 preview surface: black plane, a 2 px frame coloured by the
/// projector's shutter, and the live JPEG or a status line. Used on its own in
/// the single dialog and as a grid cell (with [showCaption]) in the multiview.
class PreviewViewport extends ConsumerStatefulWidget {
  const PreviewViewport({
    super.key,
    required this.node,
    this.group,
    this.showCaption = false,
  });

  final ProjectorNode node;
  final ProjectorGroup? group;
  final bool showCaption;

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

  bool get _knownOffline =>
      widget.node.connectionStatus == ConnectionStatus.offline && !_forced;

  Color _frameColor(ColorScheme scheme) {
    if (widget.node.powerStatus != PowerStatus.on) return scheme.outline;
    return widget.node.shutterStatus == ShutterStatus.open
        ? _frameOpen
        : _frameClosed;
  }

  void _retry() {
    if (_knownOffline) {
      setState(() => _forced = true);
      return;
    }
    ref.read(remotePreviewProvider(widget.node.ipAddress).notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _knownOffline
        ? const RemotePreviewUnavailable()
        : ref.watch(remotePreviewProvider(widget.node.ipAddress));

    final plane = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: _frameColor(theme.colorScheme), width: 2),
      ),
      child: _content(state, theme),
    );

    // Grid cell: the cell's aspect ratio fixes the height, so the plane fills
    // what's left after the caption. Single: drive the 16:9 shape ourselves.
    if (widget.showCaption) {
      return Column(
        children: [
          Expanded(child: plane),
          _caption(theme),
        ],
      );
    }
    return AspectRatio(aspectRatio: 16 / 9, child: plane);
  }

  Widget _content(RemotePreviewState state, ThemeData theme) {
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
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(jpeg, gaplessPlayback: true, fit: BoxFit.contain),
            if (overlay != null)
              Positioned(
                left: 6,
                top: 6,
                child: _tag(overlay.label.toUpperCase()),
              ),
          ],
        );
      case RemotePreviewNotice(:final kind):
        if (kind == RemotePreviewNoticeKind.blank) {
          return const SizedBox.shrink();
        }
        return _planeText(kind.label, theme);
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

  Widget _caption(ThemeData theme) {
    final node = widget.node;
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
