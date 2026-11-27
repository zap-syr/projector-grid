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

  /// Not the glyph of the Corner Correction tile.
  static const IconData fitRange = Icons.open_in_full;
  static const IconData reload = Icons.refresh;
  static const IconData moreMemory = Icons.more_vert;
  static const IconData store = Icons.save_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline;
}

/// Tells a state whether the keyboard is what moves focus now: a focus ring
/// shows for keyboard focus only, and it has to appear when a key is pressed
/// while the widget already has focus from a click.
mixin FreeGridKeyboardHighlight<T extends StatefulWidget> on State<T> {
  bool get keyboardHighlight =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }
}

/// Control or Command: the key that zooms with the wheel and adds to a
/// selection. Macs take Command.
bool get freeGridIsMac => defaultTargetPlatform == TargetPlatform.macOS;

String get freeGridModifierName => freeGridIsMac ? 'Cmd' : 'Ctrl';

/// A round icon button of the editor's headers and zoom cluster: no ink on a
/// click, a soft fill under the pointer, the whole [size] square hit area.
class FreeGridIconButton extends StatefulWidget {
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
    this.showTooltip = true,
  });

  final IconData icon;
  final String tooltip;

  /// False hides the tooltip (a button whose menu is open).
  final bool showTooltip;

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
  State<FreeGridIconButton> createState() => _FreeGridIconButtonState();
}

class _FreeGridIconButtonState extends State<FreeGridIconButton>
    with FreeGridKeyboardHighlight {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final w = widget;
    final enabled = w.onPressed != null;
    // The ring shows for keyboard focus only: a click leaves none.
    final ring = _focused && keyboardHighlight;
    return CustomTooltip(
      message: w.tooltip,
      placement: w.placement,
      body: w.tooltipBody,
      maxWidth: w.tooltipMaxWidth,
      enabled: w.showTooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: w.tooltip,
        child: SizedBox.square(
          dimension: w.size,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ring ? t.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkResponse(
                onTap: w.onPressed,
                onFocusChange: (focused) => setState(() => _focused = focused),
                containedInkWell: true,
                customBorder: const CircleBorder(),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: t.primary.withValues(alpha: 0.08),
                focusColor: t.primary.withValues(alpha: 0.2),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: w.quarterTurns,
                    child: Icon(
                      w.icon,
                      size: w.iconSize,
                      color: enabled ? t.secondary : t.disabled,
                    ),
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

  /// Whether the canvas card is compact in a dialog [dialogWidth] wide: the
  /// body keeps 24 px at each side.
  static bool isCompact(double dialogWidth) =>
      canvasWidth(dialogWidth - 48) < compactBelow;

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
