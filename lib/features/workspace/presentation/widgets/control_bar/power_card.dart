import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'control_bar_parts.dart';

/// Power, Shutter and OSD: one row each, two command buttons per row.
class PowerCard extends ConsumerWidget {
  const PowerCard({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget button(String label, IconData icon, String cmd) => CommandButton(
      label: label,
      icon: icon,
      onPressed: enabled ? () => sendToSelected(ref, cmd) : null,
    );
    return ControlBarCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ControlBarMetrics.cardPadding,
      ),
      child: Column(
        children: [
          CommandRow(
            label: 'Power',
            first: button('On', Icons.power_settings_new, 'PON'),
            second: button('Standby', Icons.bedtime_outlined, 'POF'),
          ),
          const CardRowDivider(),
          CommandRow(
            label: 'Shutter',
            first: button('Open', Icons.visibility_outlined, 'OSH:0'),
            second: button('Close', Icons.visibility_off_outlined, 'OSH:1'),
          ),
          const CardRowDivider(),
          CommandRow(
            label: 'OSD',
            first: button('On', Icons.subtitles_outlined, 'OOS:1'),
            second: button('Off', Icons.subtitles_off_outlined, 'OOS:0'),
          ),
        ],
      ),
    );
  }
}
