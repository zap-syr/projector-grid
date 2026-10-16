import 'package:flutter/material.dart';

import '../../domain/geometry_preview.dart';
import 'common/dialog_parts.dart';

/// The Keystone / Curved preview drawing: the panel, the corrected image on
/// it and the image's centre cross, scaled to the space it gets. The shape
/// comes from `domain/geometry_preview.dart`; this only draws it.
class GeometryPreviewCanvas extends StatelessWidget {
  const GeometryPreviewCanvas({super.key, required this.preview});

  final GeometryPreview preview;

  /// The panel's proportions (16:10, every model with geometry modes).
  static const double panelAspect = 1920 / 1200;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: AspectRatio(
        aspectRatio: panelAspect,
        child: CustomPaint(
          painter: _GeometryPreviewPainter(
            preview: preview,
            panelFill: DialogSurfaces.of(context).soft,
            panelEdge: cs.outline,
            image: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _GeometryPreviewPainter extends CustomPainter {
  _GeometryPreviewPainter({
    required this.preview,
    required this.panelFill,
    required this.panelEdge,
    required this.image,
  });

  final GeometryPreview preview;
  final Color panelFill;
  final Color panelEdge;
  final Color image;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the image stroke so an edge on the panel border isn't cut.
    const inset = 1.0;
    final panel = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    Offset toCanvas(Offset p) => Offset(
      panel.left + p.dx * panel.width,
      panel.top + p.dy * panel.height,
    );
    Path polyline(List<Offset> points, {bool close = false}) =>
        Path()..addPolygon(points.map(toCanvas).toList(), close);

    canvas.drawRect(panel, Paint()..color = panelFill);
    canvas.drawRect(
      panel,
      Paint()
        ..color = panelEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final outline = polyline(preview.outline, close: true);
    canvas.drawPath(outline, Paint()..color = image.withValues(alpha: 0.14));

    final cross = Paint()
      ..color = image.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(polyline(preview.centerRow), cross);
    canvas.drawPath(polyline(preview.centerColumn), cross);

    canvas.drawPath(
      outline,
      Paint()
        ..color = image
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GeometryPreviewPainter old) =>
      old.preview != preview ||
      old.panelFill != panelFill ||
      old.panelEdge != panelEdge ||
      old.image != image;
}
