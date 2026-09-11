import 'package:flutter/material.dart';

/// The title bar every dialog in the app uses (except Preferences, which
/// keeps its own chrome): a title and a close (✕) button, nothing else — the
/// one dismiss affordance across the app, replacing the mix of a bottom
/// "Close" text button some dialogs used and a corner ✕ others did.
///
/// Deliberately carries no other controls: an "Add"/action button here would
/// sit right next to ✕, inviting mis-clicks between "do something" and
/// "close everything". Dialogs that need one put it near what it acts on
/// instead (e.g. a footer button under a list).
///
/// Includes the divider beneath it; callers just drop this in as the first
/// child of their dialog's content column.
class DialogTitleBar extends StatelessWidget {
  const DialogTitleBar({super.key, required this.title, this.onClose});

  final String title;

  /// Defaults to popping the current route. Override when closing needs a
  /// side effect first (e.g. a warning that a setting stays active).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                tooltip: 'Close',
                onPressed: onClose ?? () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
