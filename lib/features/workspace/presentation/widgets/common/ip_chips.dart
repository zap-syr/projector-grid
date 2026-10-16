import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/ip_ranges.dart';
import '../custom_tooltip.dart';

/// Addresses as chips, consecutive ones collapsed (`192.168.0.10 to .49`).
/// Past [maxChips] the rest go into a `+N more` chip with the full list in
/// its tooltip.
class IpChips extends StatelessWidget {
  const IpChips({
    super.key,
    required this.ips,
    this.maxChips,
    this.short = false,
  });

  final Iterable<String> ips;
  final int? maxChips;

  /// Drop the first three octets (`.31 to .33`) where the prefix is shown
  /// elsewhere.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final runs = collapseIpRanges(ips);
    final limit = maxChips;
    final shown = limit == null || runs.length <= limit
        ? runs
        : runs.take(limit).toList();
    final hidden = runs.skip(shown.length).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in shown) _Chip(r.label(short: short)),
        if (hidden.isNotEmpty)
          CustomTooltip(
            message: '${hidden.fold(0, (n, r) => n + r.length)} more',
            detail: hidden.map((r) => r.label(short: short)).join(', '),
            child: _Chip('+${hidden.length} more', mono: false),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.mono = true});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        text,
        style: (mono ? t.monoSmall : t.caption).copyWith(
          color: t.primary,
          height: 1.2,
        ),
      ),
    );
  }
}
