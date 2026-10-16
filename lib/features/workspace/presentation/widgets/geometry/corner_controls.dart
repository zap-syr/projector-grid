import 'package:flutter/material.dart';

import '../../../domain/geometry_corners.dart';
import '../common/projector_settings_client.dart';
import '../common/segmented_tabs.dart';
import '../custom_tooltip.dart';
import 'corner_canvas.dart';
import 'corner_row.dart';
import 'geometry_parts.dart';
import 'geometry_settings.dart';

/// The Corner Correction controls card (§7.5): the four corners with their
/// H / V fields, then Linearity and pincushion with Auto / Manual.
class CornerControls extends StatelessWidget {
  const CornerControls({
    super.key,
    required this.model,
    required this.client,
    required this.compact,
    required this.onCommit,
    required this.onCornerTap,
  });

  final CornerModel model;
  final ProjectorSettingsClient client;
  final bool compact;
  final Future<void> Function(List<(String, int)>) onCommit;

  /// A corner row was clicked (after the selection changed): the canvas
  /// takes focus so the arrow keys move it.
  final VoidCallback onCornerTap;

  static const _linearity = [('Vertical', 'GMFI5'), ('Horizontal', 'GMFIA')];
  static const _pincushion = [
    ('Upper', 'GMFIB'),
    ('Lower', 'GMFIC'),
    ('Left', 'GMFID'),
    ('Right', 'GMFIE'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final extended = model.extended;
        final manual = model.manual;

        GeometrySliderRow shapeRow((String, String) row, int range) {
          final (label, key) = row;
          return GeometrySliderRow(
            label: label,
            value: model.shape(key).toDouble(),
            min: -range.toDouble(),
            max: range.toDouble(),
            snap: false,
            onChanged: manual ? (v) => model.setShape(key, v.round()) : null,
            onChangeEnd: manual ? (v) => client.writeInt(key, v.round()) : null,
          );
        }

        return GeometryControlsCard(
          groups: [
            GeometryGroup(
              header: GeometryGroupHeader(
                title: 'Corners',
                unit: 'panel pixels',
                trailing: extended
                    ? CustomTooltip(
                        message: 'Extended inward range',
                        detail:
                            'Quad Pixel Drive doubles the inward range of '
                            'every corner on this model.',
                        child: GeometryPill(
                          compact ? 'Extended' : 'Extended inward range',
                        ),
                      )
                    : null,
              ),
              rows: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoLines =
                        constraints.maxWidth < CornerRow.oneLineWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: [
                        for (final c in GeometryCorner.values)
                          CornerRow(
                            corner: c,
                            h: model.h(c),
                            v: model.v(c),
                            hRange: cornerRangeH(c, extended: extended),
                            vRange: cornerRangeV(c, extended: extended),
                            selected: model.isSelected(c),
                            twoLines: twoLines,
                            onTap: () {
                              model.select(
                                c,
                                additive: cornerMultiSelectHeld(),
                              );
                              onCornerTap();
                            },
                            // The field commits on Enter and again on the
                            // focus loss that follows: send a value once.
                            onH: (v) {
                              if (v == model.h(c)) return;
                              model.setRaw(c, h: v);
                              onCommit(model.commandsFor(c));
                            },
                            onV: (v) {
                              if (v == model.v(c)) return;
                              model.setRaw(c, v: v);
                              onCommit(model.commandsFor(c));
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            GeometryGroup(
              header: GeometryGroupHeader(
                title: compact
                    ? 'Linearity, pincushion'
                    : 'Linearity and pincushion',
                trailing: SegmentedTabs<bool>(
                  expand: false,
                  selected: manual,
                  tabs: const [
                    SegmentedTab(value: false, label: 'Auto'),
                    SegmentedTab(value: true, label: 'Manual'),
                  ],
                  onChanged: (v) {
                    model.manual = v;
                    client.writeInt('GMFIF', v ? 1 : 0);
                  },
                ),
              ),
              rows: [
                const GeometrySubHeader(
                  title: 'Linearity',
                  range: '-127 to 127',
                ),
                for (final row in _linearity) shapeRow(row, 127),
                const GeometrySubHeader(
                  title: 'Pincushion',
                  range: '-100 to 100',
                ),
                for (final row in _pincushion) shapeRow(row, 100),
              ],
            ),
          ],
        );
      },
    );
  }
}
