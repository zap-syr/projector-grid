import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/canvas_card.dart';
import '../common/dashed_border.dart';
import '../common/dialog_parts.dart';
import '../common/key_caps.dart';
import '../custom_tooltip.dart';
import 'edge_blend_parts.dart';

/// What the canvas card's footer explains.
enum EdgeBlendHint {
  /// One projector, Edge Blending tab: mouse and keys.
  single,

  /// A pair, Edge Blending tab: switching projectors, mouse and keys.
  pair,

  /// Black Level tab.
  black,
}

/// The canvas card of Edge Blending (§7a.1): the header with [leading]
/// (a pair's arrangement and swap) and [actions] (Markers, Auto test
/// pattern, Reset all) in the same place in every state, the canvas, the
/// legend and one note. Off dims the canvas and footer and lays an opaque
/// note over them (§7a.5).
class EdgeBlendCanvasCard extends StatelessWidget {
  const EdgeBlendCanvasCard({
    super.key,
    required this.body,
    required this.actions,
    required this.hint,
    required this.compact,
    required this.off,
    this.leading,
    this.notice,
  });

  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final EdgeBlendHint hint;

  /// A narrow card: the mouse and keyboard hint moves into a keyboard
  /// icon's tooltip in the header.
  final bool compact;
  final bool off;

  /// Replaces the hint (a pair's projector that doesn't reply).
  final String? notice;

  static String get _hintPlain =>
      'Drag a handle, or move it 1 step with the arrow keys, 10 with Shift. '
      'Double click resets an edge, Esc clears the selection.';

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final keyHint = hint != EdgeBlendHint.black && notice == null;
    final Widget? note = notice != null
        ? Text(notice!)
        : switch (hint) {
            EdgeBlendHint.black => const Text(
              'Each area shows its own level. Drag the border line to set '
              'its width.',
            ),
            _ when compact => null,
            EdgeBlendHint.single => const _KeyHint(),
            EdgeBlendHint.pair => const _KeyHint(pair: true),
          };
    return CanvasCard(
      key: edgeBlendCanvasCardKey,
      leading: leading,
      help: compact && keyHint
          ? CustomTooltip(
              message: 'Mouse and keyboard',
              detail: hint == EdgeBlendHint.pair
                  ? 'Click a raster or its pill to edit that projector. '
                        '$_hintPlain'
                  : _hintPlain,
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
      actions: actions,
      body: Stack(
        children: [
          Positioned.fill(
            child: OffDim(off: off, child: body),
          ),
          if (off) const Center(child: _OffNote()),
        ],
      ),
      legend: Opacity(
        opacity: off ? 0.38 : 1,
        child: _Legend(hint: hint),
      ),
      note: note == null
          ? null
          : Opacity(
              opacity: off ? 0.38 : 1,
              child: CanvasNote(child: note),
            ),
    );
  }
}

/// Over the dimmed canvas while the mode is Off: opaque, so the drawing
/// under it doesn't read as live.
class _OffNote extends StatelessWidget {
  const _OffNote();

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DialogCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            key: const ValueKey('edge-blend-off-note'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edge blending is off',
                textAlign: TextAlign.center,
                style: t.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'The values stay on the projector and apply again when you '
                'choose On or User.',
                textAlign: TextAlign.center,
                style: t.description,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Swatch { start, width, zone, other, nonOverlapped, overlapped, border }

class _Legend extends StatelessWidget {
  const _Legend({required this.hint});

  final EdgeBlendHint hint;

  @override
  Widget build(BuildContext context) {
    final items = switch (hint) {
      EdgeBlendHint.single => [
        (_Swatch.start, 'Start'),
        (_Swatch.width, 'Width, zone end'),
        (_Swatch.zone, 'Blend zone'),
      ],
      EdgeBlendHint.pair => [
        (_Swatch.start, 'Start'),
        (_Swatch.width, 'Width, zone end'),
        (_Swatch.other, 'Other projector'),
      ],
      EdgeBlendHint.black => [
        (_Swatch.nonOverlapped, 'Non-overlapped'),
        (_Swatch.overlapped, 'Overlapped'),
        (_Swatch.border, 'Overlapped + border'),
      ],
    };
    return CanvasLegend(
      items: [for (final (s, label) in items) (_swatch(context, s), label)],
    );
  }

  Widget _swatch(BuildContext context, _Swatch s) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(2);
    // A handle, ringed in its part's colour.
    Widget handle(Color color) => Center(
      child: Container(
        width: 8,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
    return switch (s) {
      _Swatch.start => handle(AppStatusColors.of(context).warning),
      _Swatch.width => handle(cs.primary),
      _Swatch.zone => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.5),
              cs.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
      ),
      _Swatch.other => DashedBorder(
        color: cs.outline,
        radius: 2,
        dash: 3,
        gap: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: radius,
          ),
        ),
      ),
      _Swatch.nonOverlapped => DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.all(color: cs.outlineVariant),
        ),
      ),
      _Swatch.overlapped => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            cs.onSurface.withValues(alpha: 0.18),
            cs.surfaceContainerHighest,
          ),
          borderRadius: radius,
        ),
      ),
      _Swatch.border => ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: _HatchPainter(
            fill: Color.alphaBlend(
              cs.onSurface.withValues(alpha: 0.26),
              cs.surfaceContainerHighest,
            ),
            line: cs.outline,
          ),
        ),
      ),
    };
  }
}

/// The hatched swatch of *Overlapped + border*, as the canvas hatches it.
class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.fill, required this.line});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 4) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.fill != fill || old.line != line;
}

/// "Drag a handle, or move it 1 step with ← → ↑ ↓, 10 with Shift. Double
/// click resets an edge, Esc clears the selection." with the keys as caps;
/// a pair starts with how to switch projectors.
class _KeyHint extends StatelessWidget {
  const _KeyHint({this.pair = false});

  final bool pair;

  @override
  Widget build(BuildContext context) {
    InlineSpan cap(String key) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: KeyCap(key, small: true),
      ),
    );
    const space = TextSpan(text: ' ');
    return Text.rich(
      TextSpan(
        children: [
          if (pair)
            const TextSpan(
              text: 'Click a raster or its pill to edit that projector. ',
            ),
          const TextSpan(text: 'Drag a handle, or move it 1 step with '),
          cap('←'),
          space,
          cap('→'),
          space,
          cap('↑'),
          space,
          cap('↓'),
          const TextSpan(text: ', 10 with '),
          cap('Shift'),
          if (pair)
            const TextSpan(text: '.')
          else ...[
            const TextSpan(text: '. Double click resets an edge, '),
            cap('Esc'),
            const TextSpan(text: ' clears the selection.'),
          ],
        ],
      ),
    );
  }
}
