import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dialog_title_bar.dart';

class AppAboutDialog extends StatefulWidget {
  const AppAboutDialog({super.key});

  @override
  State<AppAboutDialog> createState() => _AppAboutDialogState();
}

class _AppAboutDialogState extends State<AppAboutDialog> {
  static const _author = 'Aleksei Vlasov';
  static const _description =
      'Desktop application for controlling and monitoring projectors.';

  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

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
            const DialogTitleBar(title: 'About'),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + version
                  Text(
                    'Projector Grid',
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
                        '© 2025-2026',
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
                            applicationName: 'Projector Grid',
                            applicationVersion: _version.isEmpty
                                ? ''
                                : _version,
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
