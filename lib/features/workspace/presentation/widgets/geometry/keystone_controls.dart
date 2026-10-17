import 'package:flutter/material.dart';

import '../common/controls_card.dart';
import '../common/projector_settings_client.dart';
import 'geometry_parts.dart';
import 'geometry_settings.dart';
import 'throw_ratio_field.dart';

/// The Keystone controls card (§7.3): Keystone, Balance, Lens.
class KeystoneControls extends StatelessWidget {
  const KeystoneControls({
    super.key,
    required this.values,
    required this.client,
    required this.onChanged,
  });

  final KeystoneSettings values;
  final ProjectorSettingsClient client;

  /// A value changed locally: the dialog rebuilds so the preview follows.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final k = values;
    return ControlsCard(
      key: geometryControlsCardKey,
      groups: [
        ControlsGroup(
          header: const ControlsGroupHeader(
            title: 'Keystone',
            unit: 'degrees',
            range: 'V -40 to 40, H -15 to 15',
          ),
          rows: [
            GeometrySliderRow(
              label: 'Vertical',
              value: k.vertical,
              min: -40,
              max: 40,
              step: 0.2,
              onChanged: (v) {
                k.vertical = roundDegrees(v);
                onChanged();
              },
              onChangeEnd: (v) => client.writeDeg('GMKS8', roundDegrees(v)),
            ),
            GeometrySliderRow(
              label: 'Horizontal',
              value: k.horizontal,
              min: -15,
              max: 15,
              step: 0.2,
              onChanged: (v) {
                k.horizontal = roundDegrees(v);
                onChanged();
              },
              onChangeEnd: (v) => client.writeDeg('GMKS9', roundDegrees(v)),
            ),
          ],
        ),
        ControlsGroup(
          header: const ControlsGroupHeader(
            title: 'Balance',
            range: 'V -60 to 60, H -30 to 30',
          ),
          rows: [
            GeometrySliderRow(
              label: 'Vertical',
              value: k.verticalBalance.toDouble(),
              min: -60,
              max: 60,
              onChanged: (v) {
                k.verticalBalance = v.round();
                onChanged();
              },
              onChangeEnd: (v) => client.writeInt('GMKI4', v.round()),
            ),
            GeometrySliderRow(
              label: 'Horizontal',
              value: k.horizontalBalance.toDouble(),
              min: -30,
              max: 30,
              onChanged: (v) {
                k.horizontalBalance = v.round();
                onChanged();
              },
              onChangeEnd: (v) => client.writeInt('GMKI7', v.round()),
            ),
          ],
        ),
        ControlsGroup(
          header: const ControlsGroupHeader(title: 'Lens'),
          rows: [
            ThrowRatioRow(
              value: k.throwRatio,
              onCommit: (v) {
                k.throwRatio = v;
                onChanged();
                client.writeThrow('GMKS0', v);
              },
            ),
          ],
        ),
      ],
    );
  }
}
