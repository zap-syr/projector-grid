import 'package:flutter/material.dart';

enum TooltipPlacement { top, bottom }

/// A tooltip that is transparent to the mouse pointer via [IgnorePointer].
///
/// Uses [CustomSingleChildLayout] so the delegate receives the tooltip's actual
/// rendered size — enabling correct horizontal centering and edge-clamping
/// without needing to know the width upfront.
///
/// [placement] controls whether the tooltip appears above or below the child.
/// [width] pins the tooltip to an exact width; omit to let it size intrinsically.
class CustomTooltip extends StatefulWidget {
  final String message;
  final Widget child;
  final TooltipPlacement placement;
  final double? width;

  const CustomTooltip({
    super.key,
    required this.message,
    required this.child,
    this.placement = TooltipPlacement.top,
    this.width,
  });

  @override
  State<CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<CustomTooltip> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null || !mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(overlayContext).colorScheme;
        final lines = widget.message.split('\n');

        return CustomSingleChildLayout(
          delegate: _TooltipLayoutDelegate(
            buttonPosition: position,
            buttonSize: size,
            placement: widget.placement,
          ),
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: widget.width,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (int i = 0; i < lines.length; i++)
                      Text(
                        lines[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontSize: 12,
                          fontStyle: i > 0 ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}

// ── Layout delegate ───────────────────────────────────────────────────────────

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset buttonPosition;
  final Size buttonSize;
  final TooltipPlacement placement;

  static const double _margin = 8.0;
  static const double _gap = 6.0;

  const _TooltipLayoutDelegate({
    required this.buttonPosition,
    required this.buttonSize,
    required this.placement,
  });

  /// Prevent the tooltip from ever being wider than the screen minus margins.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth - _margin * 2);

  /// Called after the child is laid out — [childSize] is the actual rendered
  /// size of the tooltip, so centering and clamping are always exact.
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final idealLeft =
        buttonPosition.dx + buttonSize.width / 2 - childSize.width / 2;
    final left =
        idealLeft.clamp(_margin, size.width - childSize.width - _margin);

    final double top = placement == TooltipPlacement.top
        ? buttonPosition.dy - childSize.height - _gap
        : buttonPosition.dy + buttonSize.height + _gap;

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate old) =>
      old.buttonPosition != buttonPosition ||
      old.buttonSize != buttonSize ||
      old.placement != placement;
}
