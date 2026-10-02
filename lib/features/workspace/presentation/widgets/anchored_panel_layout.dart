import 'package:flutter/widgets.dart';

/// Places a floating panel under its [anchor], 8px clear of the overlay's
/// edges. For `OverlayPortal.overlayChildLayoutBuilder`, which supplies the
/// anchor's rect.
class AnchoredPanelLayout extends SingleChildLayoutDelegate {
  AnchoredPanelLayout({
    required this.anchor,
    required this.width,
    this.flip = true,
  });

  /// The anchor (badge, button), in the overlay's coordinates.
  final Rect anchor;
  final double width;

  /// Opens above the anchor when there's no room below (a card's badge
  /// anywhere on the canvas). Without it the panel stays under the anchor
  /// and gets shorter instead (the status bar, always at the top), so it
  /// doesn't wander when the window is resized.
  final bool flip;

  /// Below this the panel stops shrinking and runs off the window instead.
  static const double _minHeight = 120;

  double get _top => anchor.bottom + 4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = flip
        ? constraints.maxHeight - 16
        : constraints.maxHeight - _top - 8;
    return BoxConstraints(
      maxWidth: width,
      maxHeight: room < _minHeight ? _minHeight : room,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (anchor.left - 12).clamp(8.0, size.width - childSize.width - 8);
    var y = _top;
    if (flip && y + childSize.height > size.height - 8) {
      final above = anchor.top - childSize.height - 4;
      y = above >= 8 ? above : size.height - childSize.height - 8;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(AnchoredPanelLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      flip != oldDelegate.flip;
}
