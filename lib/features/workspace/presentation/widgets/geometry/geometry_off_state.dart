import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/geometry_modes.dart';
import '../../../domain/geometry_values.dart';
import '../common/dialog_parts.dart';

/// Off (§7.2): an empty state filling the body: what geometry correction
/// is, one small card per mode, and the Quad Pixel Drive note.
class GeometryOffState extends StatelessWidget {
  const GeometryOffState({
    super.key,
    required this.tier,
    required this.compact,
  });

  final QuadPixelTier tier;
  final bool compact;

  static const _modes = [
    (
      GeometryMode.keystone,
      'Fixes an image tilted up, down or to the side. Angles, balance and '
          'lens throw ratio.',
    ),
    (
      GeometryMode.curved,
      'For curved screens. Arc, keystone and balance, with the aspect ratio '
          'kept.',
    ),
    (
      GeometryMode.corner,
      'Moves each corner on its own. Linearity and pincushion for the edges.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final note = quadPixelDriveNote(tier);
    const padding = EdgeInsets.fromLTRB(24, 20, 24, 20);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DialogIconTile(Icons.aspect_ratio, size: 40),
        const SizedBox(height: 12),
        Text(
          'Geometry correction is off',
          textAlign: TextAlign.center,
          style: t.cardTitle,
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            compact
                ? 'Choose a mode above to fix a tilted, curved or uneven image.'
                : 'The image is shown as the panel draws it. Choose a mode '
                      'above to fix a tilted, curved or uneven image.',
            textAlign: TextAlign.center,
            style: t.description,
          ),
        ),
        SizedBox(height: compact ? 14 : 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: compact ? 8 : 10,
            children: [
              for (final (mode, line) in _modes)
                Expanded(
                  child: _ModeCard(mode: mode, line: line, compact: compact),
                ),
            ],
          ),
        ),
        if (note != null) ...[
          SizedBox(height: compact ? 12 : 16),
          _QuadPixelNote(text: note),
        ],
      ],
    );
    return DialogCard(
      key: const ValueKey('geometry-off-card'),
      child: LayoutBuilder(
        builder: (context, constraints) => DialogScrollBody(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - padding.vertical).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.line,
    required this.compact,
  });

  final GeometryMode mode;
  final String line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).editor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          SizedBox(
            width: compact ? 44 : 56,
            height: compact ? 28 : 36,
            child: CustomPaint(
              painter: _ModeSketchPainter(
                mode: mode,
                frame: cs.outline,
                image: cs.primary,
              ),
            ),
          ),
          Text(
            mode.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(line, style: t.description),
        ],
      ),
    );
  }
}

/// The small drawing of each mode: the panel and what the mode does to the
/// image, on a 56×36 grid scaled to the box.
class _ModeSketchPainter extends CustomPainter {
  _ModeSketchPainter({
    required this.mode,
    required this.frame,
    required this.image,
  });

  final GeometryMode mode;
  final Color frame;
  final Color image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 56, size.height / 36);
    canvas.drawRect(
      const Rect.fromLTRB(6, 4, 50, 32),
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final shape = switch (mode) {
      GeometryMode.curved =>
        Path()
          ..moveTo(6, 4)
          ..quadraticBezierTo(28, 13, 50, 4)
          ..lineTo(50, 32)
          ..quadraticBezierTo(28, 23, 6, 32)
          ..close(),
      GeometryMode.corner =>
        Path()..addPolygon(const [
          Offset(10, 6),
          Offset(50, 4),
          Offset(46, 30),
          Offset(8, 32),
        ], true),
      _ =>
        Path()..addPolygon(const [
          Offset(12, 4),
          Offset(44, 4),
          Offset(50, 32),
          Offset(6, 32),
        ], true),
    };
    canvas.drawPath(shape, Paint()..color = image.withValues(alpha: 0.14));
    canvas.drawPath(
      shape,
      Paint()
        ..color = image
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    if (mode == GeometryMode.corner) {
      for (final p in const [
        Offset(10, 6),
        Offset(50, 4),
        Offset(46, 30),
        Offset(8, 32),
      ]) {
        canvas.drawCircle(p, 2.4, Paint()..color = image);
      }
    }
  }

  @override
  bool shouldRepaint(_ModeSketchPainter old) =>
      old.mode != mode || old.frame != frame || old.image != image;
}

/// A neutral note (blue only means state): info icon, **Quad Pixel Drive**
/// and the tier's sentence.
class _QuadPixelNote extends StatelessWidget {
  const _QuadPixelNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      key: const ValueKey('quad-pixel-note'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: t.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Quad Pixel Drive ',
                    style: t.description.copyWith(
                      fontWeight: FontWeight.w600,
                      color: t.primary,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: t.description,
            ),
          ),
        ],
      ),
    );
  }
}
