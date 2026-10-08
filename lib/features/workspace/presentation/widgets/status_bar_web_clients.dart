import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/web_auth.dart';
import '../providers/web_clients_provider.dart';
import '../providers/web_server_provider.dart';
import 'preferences_dialog.dart';

/// The status bar's Web Access item, shown while the server runs: how many
/// browsers have the page open and how many of them are operators. Only
/// open pages count; a session whose page is closed is in Preferences.
/// Clicking opens Preferences on Web Access.
class StatusBarWebClients extends ConsumerWidget {
  const StatusBarWebClients({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(webServerProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final online = [
      for (final c in ref.watch(webClientsProvider))
        if (c.online) c,
    ];
    final operators = online.where((c) => c.role == WebRole.operator).length;
    final label = online.isEmpty
        ? 'Web: no clients'
        : operators == 0
        ? 'Web: ${online.length}'
        : 'Web: ${online.length} ($operators '
              '${operators == 1 ? 'operator' : 'operators'})';
    final muted = theme.colorScheme.onSurfaceVariant;

    final item = Tooltip(
      message: online.isEmpty
          ? 'Web access on, no page open'
          : [
              for (final c in online)
                '${c.ip}  ${c.role == WebRole.operator ? 'Operator' : 'Viewer'}',
            ].join('\n'),
      // Its own Material, as for the Alerts button: the status bar's
      // coloured container would otherwise hide the hover.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const PreferencesDialog(openWebAccess: true),
          ),
          borderRadius: BorderRadius.circular(6),
          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(
                  Icons.language,
                  size: 14,
                  color: online.isEmpty ? muted : Colors.green,
                ),
                Text(
                  label,
                  style: online.isEmpty ? style?.copyWith(color: muted) : style,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The gap to Last refresh lives here so it goes when the item does.
    return Padding(padding: const EdgeInsets.only(right: 12), child: item);
  }
}
