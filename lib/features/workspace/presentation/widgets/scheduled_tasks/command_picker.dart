import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/scheduled_commands.dart';
import '../common/dialog_parts.dart';
import '../common/scroll_fade.dart';
import 'command_field.dart';

const _bodyHeight = 236.0;
const _tileHeight = 40.0;
const _gap = 6.0;

/// The open command picker, under the command field inside the editor:
/// search on top, categories with counts on the left, the commands as tiles
/// in three columns, and a way out to a typed command string. The search
/// keeps the focus; arrows move through the tiles, Enter picks, Esc closes.
class CommandPicker extends StatefulWidget {
  const CommandPicker({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onPick,
    required this.onCommandString,
    required this.onClose,
  });

  final List<ScheduledCommand> catalog;
  final ScheduledCommand? selected;
  final ValueChanged<ScheduledCommand> onPick;
  final VoidCallback onCommandString;
  final VoidCallback onClose;

  @override
  State<CommandPicker> createState() => _CommandPickerState();
}

class _CommandPickerState extends State<CommandPicker> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _tileKeys = <ScheduledCommand, GlobalKey>{};
  CommandCategory? _category;
  int _highlight = -1;
  int _columns = 3;

  @override
  void initState() {
    super.initState();
    final selected = widget.selected;
    if (selected != null) _highlight = _results.indexOf(selected);
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<ScheduledCommand> get _results =>
      searchScheduledCommands(widget.catalog, _query.text, category: _category);

  int _count(CommandCategory? category) => searchScheduledCommands(
    widget.catalog,
    _query.text,
    category: category,
  ).length;

  void _setCategory(CommandCategory? category) => setState(() {
    _category = category;
    _highlight = -1;
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final results = _results;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (results.isNotEmpty) {
        widget.onPick(results[_highlight < 0 ? 0 : _highlight]);
      }
      return KeyEventResult.handled;
    }
    final step = switch (key) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown => _columns,
      LogicalKeyboardKey.arrowUp => -_columns,
      _ => 0,
    };
    // Left and right stay with the text while there's text to move in.
    if (step == 0 ||
        results.isEmpty ||
        (step.abs() == 1 && _query.text.isNotEmpty && _highlight < 0)) {
      return KeyEventResult.ignored;
    }
    final next = _highlight < 0
        ? 0
        : (_highlight + step).clamp(0, results.length - 1);
    setState(() => _highlight = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tileKeys[results[next]]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: step > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfaces = DialogSurfaces.of(context);
    final divider = Divider(
      height: 1,
      color: cs.outlineVariant.withValues(alpha: 0.6),
    );
    final results = _results;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                key: const ValueKey('command-search'),
                controller: _query,
                autofocus: true,
                style: plainFieldStyle,
                decoration: dialogFieldDecoration(
                  context,
                  hintText: 'Search commands',
                  prefixIcon: Icons.search,
                ),
                onChanged: (_) => setState(() => _highlight = -1),
              ),
            ),
          ),
          divider,
          SizedBox(
            height: _bodyHeight,
            child: LayoutBuilder(
              builder: (context, box) {
                final railWidth = box.maxWidth >= 520 ? 150.0 : 124.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: railWidth,
                      color: surfaces.editor,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          for (final c in [null, ...CommandCategory.values])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _RailItem(
                                label: c?.label ?? 'All',
                                icon: commandCategoryIcon(c),
                                count: _count(c),
                                selected: _category == c,
                                onTap: () => _setCategory(c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    Expanded(child: _grid(context, results)),
                  ],
                );
              },
            ),
          ),
          divider,
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            child: Row(
              children: [
                Flexible(
                  child: TextButton.icon(
                    onPressed: widget.onCommandString,
                    icon: const Icon(Icons.code, size: 18),
                    label: const Text(
                      'Enter a command string…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<ScheduledCommand> results) {
    final t = AppText.of(context);
    if (results.isEmpty) {
      final noCustoms =
          _category == CommandCategory.custom && _query.text.trim().isEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            noCustoms
                ? 'No custom commands in this project'
                : 'No commands match',
            textAlign: TextAlign.center,
            style: t.description,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        const pad = EdgeInsets.fromLTRB(12, 4, 12, 12);
        final width = box.maxWidth - pad.horizontal;
        _columns = width >= 330 ? 3 : 2;
        final tileWidth = (width - (_columns - 1) * _gap) / _columns;

        Widget tiles(Iterable<ScheduledCommand> commands) => Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final c in commands)
              SizedBox(
                key: _tileKeys.putIfAbsent(c, GlobalKey.new),
                width: tileWidth,
                child: _CommandTile(
                  command: c,
                  selected: c == widget.selected,
                  highlighted:
                      _highlight >= 0 &&
                      _highlight < results.length &&
                      results[_highlight] == c,
                  onTap: () => widget.onPick(c),
                ),
              ),
          ],
        );

        return Scrollbar(
          controller: _scroll,
          child: ScrollFade(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _category != null
                    ? [const SizedBox(height: 8), tiles(results)]
                    : [
                        for (final cat in CommandCategory.values)
                          if (results.any((c) => c.category == cat)) ...[
                            _GroupHeader(label: cat.label),
                            tiles(results.where((c) => c.category == cat)),
                          ],
                      ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final fg = selected ? cs.onPrimaryContainer : null;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: fg ?? t.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                  Text('$count', style: t.caption.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Row(
        children: [
          Text(label, style: t.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// A command by name only. The current one has a primary border and a
/// check; the keyboard's position (and the mouse) a soft fill.
class _CommandTile extends StatefulWidget {
  const _CommandTile({
    required this.command,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final ScheduledCommand command;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_CommandTile> createState() => _CommandTileState();
}

class _CommandTileState extends State<_CommandTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppText.of(context);
    final surfaces = DialogSurfaces.of(context);
    final lit = _hover || widget.highlighted;
    final radius = BorderRadius.circular(10);
    final fill = widget.selected
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.08), surfaces.field)
        : lit
        ? surfaces.soft
        : surfaces.field;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: fill,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            canRequestFocus: false,
            onTap: widget.onTap,
            child: Container(
              height: _tileHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: widget.selected
                      ? cs.primary
                      : lit
                      ? cs.outline
                      : cs.outlineVariant,
                  width: widget.selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.command.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.selected) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 14, color: cs.onPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
