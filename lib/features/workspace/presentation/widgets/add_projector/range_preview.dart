import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/ip_input.dart';
import '../common/ip_chips.dart';
import '../projector_form/form_parts.dart';

/// Up to this many addresses each get a labelled cell; past it the strip
/// is dense and unlabelled, with an axis under it.
const _labelledCellLimit = 16;

/// The IP range tab's preview: how many addresses, which are new and which
/// are already in the project (and so skipped).
class RangePreview extends StatelessWidget {
  const RangePreview({
    super.key,
    required this.range,
    required this.existingIps,
  });

  final IpRangeValid range;
  final Set<String> existingIps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final addresses = range.addresses;
    final inProject = [
      for (final ip in addresses)
        if (existingIps.contains(ip)) ip,
    ];
    final taken = inProject.toSet();
    final newCount = addresses.length - inProject.length;
    final count = addresses.length;
    final labelled = count <= _labelledCellLimit;
    final muted = TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant);
    return FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(
                  count == 1 ? '1 address' : '$count addresses',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? '.${range.firstOctet}'
                        : '.${range.firstOctet} to .${range.lastOctet}',
                    style: AppTheme.mono(muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Legend(color: cs.primary, label: '$newCount new'),
                if (inProject.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  _Legend(
                    color: FormSurfaces.of(context).soft,
                    border: cs.outline.withValues(alpha: 0.5),
                    label: '${inProject.length} in project',
                  ),
                ],
              ],
            ),
          ),
          Semantics(
            label:
                '$count addresses, $newCount new, '
                '${inProject.length} already in project',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: labelled
                  ? _LabelledStrip(
                      octets: [
                        for (
                          var o = range.firstOctet;
                          o <= range.lastOctet;
                          o++
                        )
                          o,
                      ],
                      taken: {
                        for (final ip in taken) int.parse(ip.split('.').last),
                      },
                    )
                  : _DenseStrip(
                      inProject: [
                        for (final ip in addresses) taken.contains(ip),
                      ],
                    ),
            ),
          ),
          if (!labelled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _Axis(first: range.firstOctet, last: range.lastOctet),
            ),
          const SizedBox(height: 14),
          if (inProject.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 10),
                    child: Text('Skipped, already in project:', style: muted),
                  ),
                  Expanded(
                    child: IpChips(ips: inProject, short: true, maxChips: 8),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Stands in for the preview until From and To make a range, so the login
/// card below doesn't jump when it appears.
class RangePreviewPlaceholder extends StatelessWidget {
  const RangePreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FormCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Text(
        'Enter From and To to see which addresses are new',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, color: cs.onSurface)),
      ],
    );
  }
}

class _LabelledStrip extends StatelessWidget {
  const _LabelledStrip({required this.octets, required this.taken});

  final List<int> octets;
  final Set<int> taken;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final soft = FormSurfaces.of(context).soft;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final (i, o) in octets.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: taken.contains(o) ? soft : cs.primary,
                  borderRadius: BorderRadius.circular(6),
                  border: taken.contains(o)
                      ? Border.all(color: cs.outline.withValues(alpha: 0.5))
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '.$o',
                    style: AppTheme.mono(
                      taken.contains(o)
                          ? TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              decoration: TextDecoration.lineThrough,
                            )
                          : TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One thin cell per address, painted: up to 256 of them don't fit as
/// widgets with gaps.
class _DenseStrip extends StatelessWidget {
  const _DenseStrip({required this.inProject});

  final List<bool> inProject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: _DenseStripPainter(
          inProject: inProject,
          newColor: cs.primary,
          takenColor: FormSurfaces.of(context).soft,
          takenBorder: cs.outline.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DenseStripPainter extends CustomPainter {
  _DenseStripPainter({
    required this.inProject,
    required this.newColor,
    required this.takenColor,
    required this.takenBorder,
  });

  final List<bool> inProject;
  final Color newColor;
  final Color takenColor;
  final Color takenBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final n = inProject.length;
    final gap = n > 100 ? 1.0 : 2.0;
    final w = (size.width - gap * (n - 1)) / n;
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = takenBorder;
    for (var i = 0; i < n; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (w + gap), 0, w, size.height),
        Radius.circular(w < 6 ? 1 : 3),
      );
      fill.color = inProject[i] ? takenColor : newColor;
      canvas.drawRRect(rect, fill);
      if (inProject[i]) canvas.drawRRect(rect.deflate(0.5), stroke);
    }
  }

  @override
  bool shouldRepaint(_DenseStripPainter old) =>
      !_sameList(old.inProject, inProject) ||
      old.newColor != newColor ||
      old.takenColor != takenColor ||
      old.takenBorder != takenBorder;

  static bool _sameList(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Labels under the dense strip, each over the cell it names.
class _Axis extends StatelessWidget {
  const _Axis({required this.first, required this.last});

  final int first;
  final int last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = AppTheme.mono(
      TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
    );
    final span = last - first;
    return SizedBox(
      height: 16,
      child: Stack(
        children: [
          for (final t in rangeAxisTicks(first, last))
            Align(
              alignment: Alignment(-1 + 2 * (t - first) / span, 0),
              child: Text('.$t', style: style),
            ),
        ],
      ),
    );
  }
}
