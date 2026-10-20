import 'package:flutter/material.dart';

/// The outlined, rounded chip of the mockups' bars: the Monitoring quick
/// filters and Group by, the event log's filters. Selected, it fills with
/// the primary container.
class BarChip extends StatelessWidget {
  const BarChip({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.children,
    this.padding = BarChip.defaultPadding,
    this.height = BarChip.defaultHeight,
  });

  static const double defaultHeight = 32;
  static const double defaultPadding = 12;
  static const double gap = 7;

  final bool selected;

  /// Null greys the chip out: a filter with nothing behind it.
  final VoidCallback? onPressed;
  final List<Widget> children;

  /// Horizontal padding; a bar short of room passes less.
  final double padding;

  /// The alerts panel's filter row takes 30 (plan §7m.1).
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
    );
    return Opacity(
      opacity: onPressed == null && !selected ? 0.45 : 1,
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected ? null : onPressed,
          customBorder: shape,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: gap,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
