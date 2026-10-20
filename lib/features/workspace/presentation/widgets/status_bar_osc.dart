import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/osc_status.dart';
import '../providers/app_settings_provider.dart';
import '../providers/osc_provider.dart';
import 'preferences_dialog.dart';
import 'status_bar_item.dart';

/// The status bar's OSC item (plan §7l.4): a green dot and the port while
/// listening; a red dot and *port busy* when the last start couldn't bind
/// its port, kept for the session although that failure turned the setting
/// off. Hidden while OSC is off, and while it is starting: only an explicit
/// bind failure is shown as one. Clicking opens Preferences on OSC.
class StatusBarOsc extends ConsumerWidget {
  const StatusBarOsc({super.key, this.narrow = false});

  /// The dot and the port only.
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(oscProvider);
    final (port, failed) = switch (status) {
      OscOff() => (null, false),
      OscListening(:final port) => (port, false),
      OscBindFailed(:final port) => (port, true),
    };
    if (port == null) return const SizedBox.shrink();
    final t = AppText.of(context);
    final error = Theme.of(context).colorScheme.error;
    final target = ref.watch(
      appSettingsProvider.select((s) => (ip: s.oscSendIp, port: s.oscSendPort)),
    );
    return StatusBarItem(
      key: const ValueKey('status-osc'),
      narrow: narrow,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) =>
            const PreferencesDialog(section: PreferencesSection.osc),
      ),
      tooltip: failed ? 'OSC port $port is in use' : 'OSC on port $port',
      tooltipDetail: failed
          ? 'Choose another in Preferences'
          : target.ip.isEmpty
          ? null
          : 'Status to ${target.ip} port ${target.port}',
      tooltipWarning: failed,
      semanticLabel: failed ? 'OSC port $port busy' : 'OSC $port',
      children: [
        StatusBarDot(
          color: failed ? error : AppStatusColors.of(context).success,
        ),
        // One paragraph, so the mono port sits on the words' baseline; as
        // separate Texts centred in the Row it sat lower.
        Text.rich(
          TextSpan(
            children: [
              if (!narrow) const TextSpan(text: 'OSC  '),
              TextSpan(
                text: '$port',
                style: t.monoSmall.copyWith(
                  color: failed && narrow ? error : t.primary,
                ),
              ),
              if (failed && !narrow)
                TextSpan(
                  text: '  port busy',
                  style: TextStyle(color: error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
