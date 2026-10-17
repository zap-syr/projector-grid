import 'package:flutter/material.dart';

import '../common/controls_card.dart';
import '../common/projector_settings_client.dart';
import 'geometry_parts.dart';
import 'geometry_settings.dart';
import 'throw_ratio_field.dart';

/// The Curved Correction controls card (§7.4): Arc, Keystone, Balance,
/// Lens and image.
class CurvedControls extends StatelessWidget {
  const CurvedControls({
    super.key,
    required this.values,
    required this.client,
    required this.onChanged,
  });

  final CurvedSettings values;
  final ProjectorSettingsClient client;

  /// A value changed locally: the dialog rebuilds so the preview follows.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = values;
    GeometrySliderRow intRow(
      String label,
      String key,
      int value,
      int range,
      void Function(int) set,
    ) => GeometrySliderRow(
      label: label,
      value: value.toDouble(),
      min: -range.toDouble(),
      max: range.toDouble(),
      onChanged: (v) {
        set(v.round());
        onChanged();
      },
      onChangeEnd: (v) => client.writeInt(key, v.round()),
    );

    return ControlsCard(
      key: geometryControlsCardKey,
      groups: [
        ControlsGroup(
          header: const ControlsGroupHeader(title: 'Arc', range: '-40 to 40'),
          rows: [
            intRow('Vertical', 'GMCI3', c.verticalArc, 40, (v) {
              c.verticalArc = v;
            }),
            intRow('Horizontal', 'GMCI7', c.horizontalArc, 40, (v) {
              c.horizontalArc = v;
            }),
          ],
        ),
        ControlsGroup(
          header: const ControlsGroupHeader(
            title: 'Keystone',
            unit: 'degrees',
            range: 'V -40 to 40, H -15 to 15',
          ),
          rows: [
            GeometrySliderRow(
              label: 'Vertical',
              value: c.vertical,
              min: -40,
              max: 40,
              step: 0.2,
              onChanged: (v) {
                c.vertical = roundDegrees(v);
                onChanged();
              },
              onChangeEnd: (v) => client.writeDeg('GMCS8', roundDegrees(v)),
            ),
            GeometrySliderRow(
              label: 'Horizontal',
              value: c.horizontal,
              min: -15,
              max: 15,
              step: 0.2,
              onChanged: (v) {
                c.horizontal = roundDegrees(v);
                onChanged();
              },
              onChangeEnd: (v) => client.writeDeg('GMCS9', roundDegrees(v)),
            ),
          ],
        ),
        ControlsGroup(
          header: const ControlsGroupHeader(
            title: 'Balance',
            range: 'V -60 to 60, H -30 to 30',
          ),
          rows: [
            intRow('Vertical', 'GMCI2', c.verticalBalance, 60, (v) {
              c.verticalBalance = v;
            }),
            intRow('Horizontal', 'GMCI6', c.horizontalBalance, 30, (v) {
              c.horizontalBalance = v;
            }),
          ],
        ),
        ControlsGroup(
          header: const ControlsGroupHeader(title: 'Lens and image'),
          rows: [
            ThrowRatioRow(
              value: c.throwRatio,
              onCommit: (v) {
                c.throwRatio = v;
                onChanged();
                client.writeThrow('GMCS0', v);
              },
            ),
            SettingRow(
              title: 'Maintain aspect ratio',
              description: 'Keep the image proportions while it bends',
              control: Switch(
                value: c.keepAspect,
                onChanged: (v) {
                  c.keepAspect = v;
                  onChanged();
                  client.writeBool('GMCIA', v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
