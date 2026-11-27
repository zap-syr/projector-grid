import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../custom_tooltip.dart';

/// The icons of the Free grid editor, in one place so the selection actions
/// that come later (Bezier, mirror, grid resize) reuse them.
class FreeGridIcons {
  const FreeGridIcons._();

  static const IconData undo = Icons.undo;
  static const IconData redo = Icons.redo;
  static const IconData bezier = Icons.gesture;
  static const IconData resetPositions = Icons.restart_alt;
  static const IconData mirrorHorizontally = Icons.flip;

  /// The same icon as [mirrorHorizontally], turned a quarter.
  static const IconData mirrorVertically = Icons.flip;
  static const IconData help = Icons.keyboard_outlined;
  static const IconData zoomOut = Icons.remove;
  static const IconData zoomIn = Icons.add;
  static const IconData fitPanel = Icons.fit_screen;
  static const IconData fitRange = Icons.zoom_out_map;
  static const IconData reload = Icons.refresh;
  static const IconData moreMemory = Icons.more_vert;
  static const IconData store = Icons.save_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline;
}

/// Control or Command: the key that zooms with the wheel and adds to a
/// selection. Macs take Command.
bool get freeGridIsMac => defaultTargetPlatform == TargetPlatform.macOS;

String get freeGridModifierName => freeGridIsMac ? 'Cmd' : 'Ctrl';

/// A round icon button of the editor's headers and zoom cluster: no ink on a
/// click, a soft fill under the pointer, the whole [size] square hit area.
class FreeGridIconButton extends StatelessWidget {
  const FreeGridIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 32,
    this.iconSize = 18,
    this.quarterTurns = 0,
    this.placement = TooltipPlacement.bottom,
    this.tooltipBody,
    this.tooltipMaxWidth = 260,
  });

  final IconData icon;
  final String tooltip;

  /// Lines under the tooltip's title (the keyboard help's table).
  final WidgetBuilder? tooltipBody;
  final double tooltipMaxWidth;

  /// Null disables the button; its tooltip still shows.
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// Turns the icon, for the vertical mirror.
  final int quarterTurns;
  final TooltipPlacement placement;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final enabled = onPressed != null;
    return CustomTooltip(
      message: tooltip,
      placement: placement,
      body: tooltipBody,
      maxWidth: tooltipMaxWidth,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: SizedBox.square(
          dimension: size,
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onPressed,
              containedInkWell: true,
              customBorder: const CircleBorder(),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: t.primary.withValues(alpha: 0.08),
              focusColor: t.primary.withValues(alpha: 0.08),
              child: Center(
                child: RotatedBox(
                  quarterTurns: quarterTurns,
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: enabled ? t.secondary : t.disabled,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The body below the mode tiles in the Free grid: the canvas card, a 16 px
/// gap and the controls card at a fixed 296 px. The canvas takes the rest of
/// the width, up to 560 px.
class FreeGridSplit extends StatelessWidget {
  const FreeGridSplit({super.key, required this.builder});

  /// Builds the two cards; `compact` when the canvas card is narrower than
  /// [compactBelow] (the count and help move, the legend is shorter).
  final (Widget canvas, Widget controls) Function(bool compact) builder;

  static const double gap = 16;
  static const double controlsWidth = 296;
  static const double maxCanvas = 560;
  static const double compactBelow = 480;

  static double canvasWidth(double width) =>
      math.min(maxCanvas, math.max(0, width - gap - controlsWidth));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = canvasWidth(constraints.maxWidth);
        final (c, r) = builder(canvas < compactBelow);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: canvas, child: c),
            const SizedBox(width: gap),
            SizedBox(width: controlsWidth, child: r),
          ],
        );
      },
    );
  }
}

/// A projector overlay colour: the grid overlay is drawn in it on the
/// projector's image, so these are data and not theme colours.
class FreeGridOverlayColor {
  const FreeGridOverlayColor(this.name, this.rgb);

  final String name;

  /// 0xRRGGBB.
  final int rgb;

  Color get color => Color(0xFF000000 | rgb);
}

const freeGridOverlayColors = [
  FreeGridOverlayColor('White', 0xFFFFFF),
  FreeGridOverlayColor('Red', 0xFF0000),
  FreeGridOverlayColor('Green', 0x00FF00),
  FreeGridOverlayColor('Blue', 0x0000FF),
  FreeGridOverlayColor('Yellow', 0xFFFF00),
  FreeGridOverlayColor('Cyan', 0x00FFFF),
  FreeGridOverlayColor('Magenta', 0xFF00FF),
];

/// The colour a session starts with: Green.
const int freeGridDefaultOverlayRgb = 0x00FF00;
