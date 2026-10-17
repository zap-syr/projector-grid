import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/geometry_corners.dart';
import '../common/canvas_card.dart';
import '../common/controls_card.dart';
import '../common/key_caps.dart';
import '../custom_tooltip.dart';
import 'corner_canvas.dart';
import 'geometry_legend.dart';
import 'geometry_parts.dart';
import 'geometry_settings.dart';

/// The Corner Correction card (§7.5): header *Corners* with the selection
/// pill and **Reset all**, the canvas, the legend and the mouse and
/// keyboard hint (a keyboard icon with a tooltip in a small window).
class CornerCanvasCard extends StatelessWidget {
  const CornerCanvasCard({
    super.key,
    required this.model,
    required this.focusNode,
    required this.compact,
    required this.onCommit,
    required this.onResetAll,
    this.loading,
  });

  final CornerModel model;
  final FocusNode focusNode;
  final bool compact;
  final Future<void> Function(List<(String, int)>) onCommit;
  final VoidCallback? onResetAll;

  /// Shown in place of the canvas while the corner values are read.
  final Widget? loading;

  static String get _multiKey => Platform.isMacOS ? 'Cmd' : 'Ctrl';

  static String get hintText =>
      'Drag a corner, or move it 1 step with the arrow keys. $_multiKey '
      'click selects more corners, double click resets one.';

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return CanvasCard(
      key: geometryCanvasCardKey,
      title: 'Corners',
      pill: loading == null
          ? ListenableBuilder(
              listenable: model,
              builder: (context, _) {
                final label = cornerSelectionLabel(model.selected);
                return label == null
                    ? const SizedBox.shrink()
                    : CardPill(label, selected: true);
              },
            )
          : null,
      help: compact
          ? CustomTooltip(
              message: 'Mouse and keyboard',
              detail: hintText,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.keyboard_outlined,
                  size: 18,
                  color: t.secondary,
                ),
              ),
            )
          : null,
      resetLabel: 'Reset all',
      onReset: onResetAll,
      body:
          loading ??
          // Translucent: a click on empty space around the canvas clears the
          // selection too; the handles still win their own taps.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: model.clearSelection,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CornerCanvas(
                model: model,
                focusNode: focusNode,
                onCommit: onCommit,
              ),
            ),
          ),
      legend: GeometryLegend(
        items: [
          (LegendMark.outerLimit, 'Outer limit'),
          (LegendMark.defaultFrame, 'Default frame'),
          (
            LegendMark.range,
            compact ? 'Corner range' : 'Range of the selected corner',
          ),
        ],
      ),
      note: compact ? null : const CanvasNote(child: _KeyHint()),
    );
  }
}

/// "Drag a corner, or move it 1 step with ← ↑ → ↓. Ctrl click selects more
/// corners, double click resets one." with the keys as caps.
class _KeyHint extends StatelessWidget {
  const _KeyHint();

  @override
  Widget build(BuildContext context) {
    InlineSpan cap(String key) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: KeyCap(key, small: true),
      ),
    );
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Drag a corner, or move it 1 step with '),
          cap('←'),
          const TextSpan(text: ' '),
          cap('↑'),
          const TextSpan(text: ' '),
          cap('→'),
          const TextSpan(text: ' '),
          cap('↓'),
          const TextSpan(text: '. '),
          cap(CornerCanvasCard._multiKey),
          const TextSpan(
            text: ' click selects more corners, double click resets one.',
          ),
        ],
      ),
    );
  }
}
