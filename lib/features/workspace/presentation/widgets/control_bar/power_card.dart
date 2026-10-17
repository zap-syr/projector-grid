import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import 'control_bar_parts.dart';

/// Power, Shutter and OSD: one row each, two command buttons per row. The
/// icons carry the projector card's status colours: green for what turns
/// the picture on, red for what turns it off.
class PowerCard extends ConsumerWidget {
  const PowerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = AppStatusColors.of(context).success;
    final off = Theme.of(context).colorScheme.error;
    Widget button(String label, IconData icon, String cmd, [Color? color]) =>
        CommandButton(
          label: label,
          icon: icon,
          iconColor: color,
          alignStart: true,
          onPressed: () => sendToSelected(ref, cmd),
        );
    return ControlBarCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ControlBarMetrics.cardPadding,
      ),
      child: Column(
        children: [
          CommandRow(
            label: 'Power',
            first: button('On', Icons.power_settings_new, 'PON', on),
            second: button('Standby', Icons.bedtime_outlined, 'POF', off),
          ),
          const CardRowDivider(),
          CommandRow(
            label: 'Shutter',
            first: button('Open', Icons.visibility_outlined, 'OSH:0', on),
            second: button(
              'Close',
              Icons.visibility_off_outlined,
              'OSH:1',
              off,
            ),
          ),
          const CardRowDivider(),
          CommandRow(
            label: 'OSD',
            first: button('On', Icons.subtitles_outlined, 'OOS:1', on),
            second: button('Off', Icons.subtitles_off_outlined, 'OOS:0', off),
          ),
        ],
      ),
    );
  }
}
