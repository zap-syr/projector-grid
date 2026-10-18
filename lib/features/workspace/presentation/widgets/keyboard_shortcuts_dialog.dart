import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/keyboard_shortcuts.dart';
import 'common/dashed_border.dart';
import 'common/dialog_parts.dart';
import 'common/key_caps.dart';
import 'common/scroll_fade.dart';
import 'dialog_title_bar.dart';

class KeyboardShortcutsDialog extends StatefulWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  State<KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<KeyboardShortcutsDialog> {
  /// Below this width the two columns of cards stack into one.
  static const _twoColumnMinWidth = 600.0;

  final _sections = shortcutSections(macOS: Platform.isMacOS);
  late final int _total = shortcutCount(_sections);
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final searching = _search.text.trim().isNotEmpty;
    final hits = filterShortcuts(_sections, _search.text);
    final shown = hits.fold(0, (n, s) => n + s.hits.length);

    final cards = [
      for (final s in hits)
        _SectionCard(
          key: ValueKey(s.section.id),
          hits: s,
          searching: searching,
        ),
    ];

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        // Full size whatever the search leaves, so the dialog doesn't
        // shrink and jump while typing.
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DialogTitleBar(
                icon: Icons.keyboard_outlined,
                title: 'Keyboard Shortcuts',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                child: _SearchField(
                  controller: _search,
                  count: searching ? '$shown of $_total' : '$_total shortcuts',
                  onChanged: () => setState(() {}),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  child: ScrollFade(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns =
                              constraints.maxWidth >= _twoColumnMinWidth;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (twoColumns)
                                _BalancedColumns(children: cards)
                              else
                                _CardColumn(cards),
                              if (searching) ...[
                                if (hits.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'No shortcuts match "${_search.text.trim()}".',
                                      style: t.body,
                                    ),
                                  )
                                else
                                  const SizedBox(height: 10),
                                Text(
                                  'Matches descriptions and keys: try "ctrl g" or "esc".',
                                  style: t.description,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _cardGap = 10.0;
const _columnGap = 14.0;

/// Two columns of cards whose bottoms end as close as the cards allow: in
/// list order, each card goes under the column that is shorter so far. The
/// cards are measured at the column width, so wrapped rows count, and a
/// search that hides sections rebalances what is left.
class _BalancedColumns extends MultiChildRenderObjectWidget {
  const _BalancedColumns({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBalancedColumns();
}

class _ColumnParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBalancedColumns extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ColumnParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ColumnParentData) {
      child.parentData = _ColumnParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final columnWidth = (width - _columnGap) / 2;
    final heights = [0.0, 0.0];
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: columnWidth),
        parentUsesSize: true,
      );
      final column = heights[1] < heights[0] ? 1 : 0;
      final top = heights[column] == 0 ? 0.0 : heights[column] + _cardGap;
      final data = child.parentData! as _ColumnParentData;
      data.offset = Offset(column * (columnWidth + _columnGap), top);
      heights[column] = top + child.size.height;
      child = data.nextSibling;
    }
    size = constraints.constrain(
      Size(width, heights[0] > heights[1] ? heights[0] : heights[1]),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _CardColumn extends StatelessWidget {
  const _CardColumn(this.cards);

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          card,
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String count;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: (_) => onChanged(),
      style: plainFieldStyle,
      decoration: dialogFieldDecoration(
        context,
        hintText: 'Search shortcuts',
        prefixIcon: Icons.search,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(count, style: AppText.of(context).description),
              // The clear button's slot is kept while empty, so the count
              // doesn't move when typing starts.
              SizedBox.square(
                dimension: 32,
                child: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.hits, required this.searching});

  final ShortcutSectionHits hits;
  final bool searching;

  static IconData _icon(ShortcutSectionId id) => switch (id) {
    ShortcutSectionId.project => Icons.folder_outlined,
    ShortcutSectionId.canvasNavigation => Icons.pan_tool_outlined,
    ShortcutSectionId.edit => Icons.edit_outlined,
    ShortcutSectionId.view => Icons.visibility_outlined,
    ShortcutSectionId.selection => Icons.select_all,
    ShortcutSectionId.projectorControl => Icons.videocam_outlined,
    ShortcutSectionId.alignment => Icons.center_focus_strong,
    ShortcutSectionId.lensShift => Icons.control_camera,
    ShortcutSectionId.edgeBlending => Icons.blur_linear,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final section = hits.section;
    final note = searching
        ? '${hits.hits.length} of ${section.entries.length}'
        : section.note;
    return DialogCard(
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            // The title keeps its full width first and the note gets what is
            // left; in a narrow column the title ellipsizes instead of
            // overflowing.
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  DialogIconTile(_icon(section.id), size: 30),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(
                        0,
                        constraints.maxWidth - 40 - (note == null ? 0 : 8),
                      ),
                    ),
                    child: Text(
                      section.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.cardTitle,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          for (final (i, hit) in hits.hits.indexed)
            _ShortcutRow(hit: hit, divider: i > 0),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.hit, required this.divider});

  final ShortcutHit hit;
  final bool divider;

  // Shortcut data is written generically ('Ctrl'); macOS shows the symbols.
  // Every shortcut is registered with both control and meta modifiers
  // (projector_workspace.dart), so Cmd is what's really bound there.
  static String _platformLabel(String label) {
    if (!Platform.isMacOS) return label;
    return switch (label) {
      'Ctrl' => '⌘',
      'Shift' => '⇧',
      _ => label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = AppText.of(context).body.copyWith(height: 1.35);
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      decoration: divider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Wide enough for Shift or Ctrl and the four arrows on one line:
          // at 150 the lens shift combinations broke onto two.
          SizedBox(
            width: 176,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final input in hit.entry.inputs)
                  input.mouse
                      ? _MousePill(input.label)
                      : KeyCap(_platformLabel(input.label)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              _highlighted(hit.entry.description, hit.highlights, cs),
              style: base,
            ),
          ),
        ],
      ),
    );
  }

  static TextSpan _highlighted(
    String text,
    List<(int, int)> ranges,
    ColorScheme cs,
  ) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: cs.onSurface,
            backgroundColor: cs.primary.withValues(alpha: 0.22),
          ),
        ),
      );
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }
}

/// A mouse action: dashed, with a mouse icon, so it never reads as a key.
class _MousePill extends StatelessWidget {
  const _MousePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return DashedBorder(
      radius: 11,
      color: t.tertiary,
      child: Container(
        height: 22,
        padding: const EdgeInsets.only(left: 6, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mouse_outlined, size: 14, color: t.secondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: t.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
