import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/keyboard/primary_shortcut.dart';
import '../../providers/monitoring_filter_provider.dart';
import '../../providers/monitoring_panel_provider.dart';

/// The Monitoring view's keys: Ctrl+F (Cmd+F) to the search field, Esc
/// closes the projector panel. It wraps the view's focus scope from
/// outside, so the keys work also while the scope itself holds the focus
/// (right after switching to Monitoring), not only a widget inside it.
class MonitoringShortcuts extends ConsumerWidget {
  const MonitoringShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void focusSearch() =>
        ref.read(monitoringSearchFocusProvider.notifier).request();
    return CallbackShortcuts(
      bindings: {
        primaryShortcut(LogicalKeyboardKey.keyF): focusSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(monitoringPanelProvider.notifier).close(),
      },
      child: child,
    );
  }
}
