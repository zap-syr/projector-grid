import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/skeleton.dart';
import 'geometry_parts.dart';

/// Where the drawing goes while a mode's values are read: a spinner and
/// what is happening, in place of the drawing (§7.6).
class GeometryLoadingView extends StatelessWidget {
  const GeometryLoadingView({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: t.description,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The controls card while a mode loads: per group a header line and
/// [groups] slider-sized rows of skeleton blocks.
class GeometryControlsSkeleton extends StatelessWidget {
  const GeometryControlsSkeleton({super.key, required this.groups});

  /// Rows per group.
  final List<int> groups;

  @override
  Widget build(BuildContext context) {
    return GeometryControlsCard(
      groups: [for (final rows in groups) _SkeletonGroup(rows: rows)],
    );
  }
}

class _SkeletonGroup extends StatelessWidget {
  const _SkeletonGroup({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          const SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 96, height: 12),
            ),
          ),
          for (var i = 0; i < rows; i++)
            const SizedBox(
              height: 40,
              child: Row(
                children: [
                  Skeleton(width: 56, height: 12),
                  SizedBox(width: 32),
                  Expanded(child: Skeleton(height: 4, radius: 2)),
                  SizedBox(width: 16),
                  Skeleton(width: 72, height: 32, radius: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
