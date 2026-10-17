import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/geometry_preview.dart';
import '../custom_tooltip.dart';
import '../geometry_preview_painter.dart';
import 'geometry_canvas_card.dart';

const approximateNote =
    'The drawing is approximate, check the result on the screen.';

/// The Keystone / Curved preview card (§7.3, GEOMETRY_PREVIEW_PLAN §2.2):
/// header *Preview* and **Reset**, the drawing, the *Panel* / *Image*
/// legend and the approximate note (which is why there's no *Schematic*
/// pill).
class GeometryPreviewCard extends StatelessWidget {
  const GeometryPreviewCard({
    super.key,
    required this.preview,
    required this.compact,
    required this.onReset,
    this.loading,
  });

  /// Null while [loading] is shown in its place.
  final GeometryPreview? preview;

  /// A small window: the note goes into an `Approximate` tooltip so the
  /// legend and note take one line.
  final bool compact;
  final VoidCallback? onReset;
  final Widget? loading;

  static const _legend = [
    (LegendMark.panel, 'Panel'),
    (LegendMark.image, 'Image'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final shown = preview;
    return GeometryCanvasCard(
      title: 'Preview',
      resetLabel: 'Reset',
      onReset: onReset,
      body:
          loading ??
          Padding(
            padding: const EdgeInsets.all(16),
            child: shown == null
                ? const SizedBox.shrink()
                : GeometryPreviewCanvas(preview: shown),
          ),
      legend: GeometryLegend(
        items: _legend,
        trailing: compact
            ? CustomTooltip(
                message: 'Approximate',
                detail: approximateNote,
                child: Text('Approximate', style: t.caption),
              )
            : null,
      ),
      note: compact ? null : const GeometryNote(child: Text(approximateNote)),
    );
  }
}
