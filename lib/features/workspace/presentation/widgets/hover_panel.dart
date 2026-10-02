import 'dart:async';

import 'package:flutter/material.dart';

import 'anchored_panel_layout.dart';

/// A trigger that opens a floating panel on hover: 250 ms on the trigger
/// opens it, it stays while the pointer is on the trigger or the panel (250
/// ms to cross the gap), and a click elsewhere closes it. A click on the
/// trigger itself does nothing extra, so it can sit inside something
/// clickable (a projector card).
///
/// Built on `OverlayPortal`, not a Tooltip: a Tooltip inside a card's
/// MenuAnchor corrupts the Windows accessibility tree, and these panels hold
/// more than a line of text.
class HoverPanel extends StatefulWidget {
  const HoverPanel({
    super.key,
    required this.builder,
    required this.panel,
    required this.width,
  });

  /// The trigger; `active` while hovered or while the panel is open.
  final Widget Function(BuildContext context, bool active) builder;
  final WidgetBuilder panel;
  final double width;

  @override
  State<HoverPanel> createState() => _HoverPanelState();
}

class _HoverPanelState extends State<HoverPanel> {
  static const _delay = Duration(milliseconds: 250);

  final _portal = OverlayPortalController();
  final _tapGroup = Object();
  Timer? _openTimer;
  Timer? _closeTimer;
  var _hovered = false;

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  void _show() {
    _closeTimer?.cancel();
    if (!_portal.isShowing) setState(_portal.show);
  }

  void _hide() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    if (_portal.isShowing) setState(_portal.hide);
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(_delay, _hide);
  }

  @override
  Widget build(BuildContext context) {
    // The layout-builder variant hands over the trigger's place in the
    // overlay during layout, so the panel follows it through zoom and pan.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => CustomSingleChildLayout(
        delegate: AnchoredPanelLayout(
          anchor: MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
          width: widget.width,
        ),
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _hide(),
          child: MouseRegion(
            onEnter: (_) => _closeTimer?.cancel(),
            onExit: (_) => _scheduleClose(),
            child: widget.panel(context),
          ),
        ),
      ),
      child: TapRegion(
        groupId: _tapGroup,
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _hovered = true);
            _closeTimer?.cancel();
            if (_portal.isShowing) return;
            _openTimer?.cancel();
            _openTimer = Timer(_delay, _show);
          },
          onExit: (_) {
            setState(() => _hovered = false);
            _openTimer?.cancel();
            _scheduleClose();
          },
          child: widget.builder(context, _hovered || _portal.isShowing),
        ),
      ),
    );
  }
}
