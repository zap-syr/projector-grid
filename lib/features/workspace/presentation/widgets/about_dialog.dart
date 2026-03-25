import 'package:flutter/material.dart';

class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key});

  static const _version = '1.0.0';
  static const _author = 'Aleksei Vlasov';
  static const _description =
      'Desktop application for controlling and monitoring\nprojectors over NTCONTROL/TCP.';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              color: colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  Text('About', style: textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + version
                  Text(
                    'Projectors Manager',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $_version',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    _description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Author
                  Row(
                    children: [
                      Text(
                        'Author  ',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      Text(
                        _author,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Copyright
                      Text(
                        '© 2025–2026',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      // Licenses button
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showLicensePage(
                            context: context,
                            applicationName: 'Projectors Manager',
                            applicationVersion: _version,
                          );
                        },
                        child: const Text('View Licenses'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
