import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../common/key_caps.dart';
import 'free_grid_parts.dart';

/// The keyboard icon of the canvas card: its tooltip lists the mouse and
/// keyboard controls of the canvas.
class FreeGridHelpButton extends StatelessWidget {
  const FreeGridHelpButton({
    super.key,
    this.enabled = true,
    this.size = 32,
    this.iconSize = 18,
  });

  final bool enabled;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => FreeGridIconButton(
    key: const ValueKey('free-grid-help'),
    icon: FreeGridIcons.help,
    tooltip: 'Mouse and keyboard',
    size: size,
    iconSize: iconSize,
    // The tooltip is the help: a click has nothing more to show.
    onPressed: enabled ? () {} : null,
    tooltipBody: (_) => const FreeGridHelpTable(),
    // Wide enough for every description on one line.
    tooltipMaxWidth: 420,
  );
}

/// The ten rows of the help: keys on the left, what they do on the right.
class FreeGridHelpTable extends StatelessWidget {
  const FreeGridHelpTable({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final mod = freeGridModifierName;
    final textStyle = t.description.copyWith(color: t.primary);

    // A Row, never a Wrap: the keys stay on one line and the column is as
    // wide as the widest of them.
    Widget keys(List<Object> parts) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final p in parts)
          p is _Key
              ? KeyCap(p.label, small: true)
              : Text(p as String, style: textStyle, softWrap: false),
      ],
    );

    Widget does(String text, {bool withShift = false}) => withShift
        ? Text.rich(
            TextSpan(
              style: t.description,
              children: [
                const TextSpan(text: 'Move the selection 1 px, with '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: const KeyCap('Shift', small: true),
                ),
                const TextSpan(text: ' 10 px'),
              ],
            ),
            softWrap: false,
          )
        : Text(text, style: t.description, softWrap: false);

    final rows = <(List<Object>, Widget)>[
      ([const _Key('Arrows')], does('', withShift: true)),
      (
        [const _Key('Tab'), const _Key('Shift'), const _Key('Tab')],
        does('Next or previous point, row by row'),
      ),
      ([const _Key('Shift'), _Key(mod), 'click'], does('Add to the selection')),
      (['Drag on empty space'], does('Select an area')),
      ([_Key(mod), 'wheel'], does('Zoom at the cursor')),
      (
        ['Wheel,', const _Key('Shift'), 'wheel'],
        does('Scroll up and down, sideways'),
      ),
      (['Middle drag,', const _Key('Space'), 'drag'], does('Pan')),
      ([const _Key('Esc')], does('Clear the selection')),
      (
        [const _Key('B'), const _Key('R')],
        does('Bezier on selection, reset positions'),
      ),
      (
        [const _Key('H'), const _Key('V')],
        does('Mirror horizontally, vertically'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          for (final (left, right) in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 3, bottom: 3),
                  child: keys(left),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: right,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Key {
  const _Key(this.label);

  final String label;
}
