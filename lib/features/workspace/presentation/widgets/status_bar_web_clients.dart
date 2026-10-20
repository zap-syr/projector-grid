import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/web_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/web_clients_provider.dart';
import '../providers/web_server_provider.dart';
import 'custom_tooltip.dart';
import 'preferences_dialog.dart';
import 'status_bar_item.dart';

/// The status bar's Web Access item (plan §7l.4), shown while the server
/// runs: a green globe and how many browsers have the page open, with the
/// operators among them; *Web 0* with a grey globe when none is. Only open
/// pages count; a session whose page is closed is in Preferences. Clicking
/// opens Preferences on Web Access.
class StatusBarWebClients extends ConsumerWidget {
  const StatusBarWebClients({super.key, this.narrow = false});

  /// The globe and the count only.
  final bool narrow;

  static String _role(WebRole role) =>
      role == WebRole.operator ? 'Operator' : 'Viewer';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(webServerProvider)) return const SizedBox.shrink();
    final t = AppText.of(context);
    final online = [
      for (final c in ref.watch(webClientsProvider))
        if (c.online) c,
    ];
    final operators = online.where((c) => c.role == WebRole.operator).length;
    final pages = online.length;
    return StatusBarItem(
      key: const ValueKey('status-web'),
      narrow: narrow,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) =>
            const PreferencesDialog(section: PreferencesSection.web),
      ),
      tooltip: switch (pages) {
        0 => 'Web access, no page open',
        1 => 'Web access, 1 page open',
        _ => 'Web access, $pages pages open',
      },
      tooltipBody: pages == 0
          ? null
          : (_) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in online)
                  TooltipRow(mono: c.ip, text: _role(c.role)),
              ],
            ),
      semanticLabel: 'Web $pages',
      children: [
        Icon(
          Icons.language,
          size: 14,
          color: pages == 0 ? t.tertiary : AppStatusColors.of(context).success,
        ),
        if (!narrow) const Text('Web'),
        StatusBarCount(pages),
        if (!narrow && operators > 0)
          Text(
            '($operators ${operators == 1 ? 'operator' : 'operators'})',
            style: TextStyle(color: t.tertiary),
          ),
      ],
    );
  }
}
