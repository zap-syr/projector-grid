import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsDropdownEntry<T> {
  const SettingsDropdownEntry({
    required this.value,
    required this.label,
    this.detail,
    this.dividerAfter = false,
  });

  final T value;

  /// Bold main text (an IP address), with [detail] muted after it (the
  /// interface name).
  final String label;
  final String? detail;
  final bool dividerAfter;
}

/// The Preferences dropdown: the same filled surface as `SettingsValueField`,
/// with a raised menu that checks the current value.
///
/// Built on `MenuAnchor` rather than `DropdownMenu`, which is a text field
/// underneath and can only show its value as plain text.
class SettingsDropdown<T> extends StatefulWidget {
  const SettingsDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.icon = Icons.lan_outlined,
    this.width = 240,
    this.placeholder = 'None',
  });

  /// Shown as-is when no entry has it (an interface that has since gone).
  final T? value;
  final List<SettingsDropdownEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final IconData icon;
  final double width;

  /// Shown while [value] is null.
  final String placeholder;

  @override
  State<SettingsDropdown<T>> createState() => _SettingsDropdownState<T>();
}

class _SettingsDropdownState<T> extends State<SettingsDropdown<T>> {
  final _controller = MenuController();
  final _buttonFocus = FocusNode();
  var _hovered = false;
  var _open = false;

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  void _toggle() =>
      _controller.isOpen ? _controller.close() : _controller.open();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = widget.entries
        .where((e) => e.value == widget.value)
        .firstOrNull;
    final label = current?.label ?? widget.value?.toString();
    final base = colors.surfaceContainerHighest;
    final fill = _open
        ? Color.alphaBlend(colors.primary.withValues(alpha: 0.08), base)
        : _hovered
        ? Color.alphaBlend(colors.onSurface.withValues(alpha: 0.06), base)
        : base;
    final strong = _open || _buttonFocus.hasFocus;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant.withValues(alpha: 0.75),
    );

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
        minimumSize: WidgetStatePropertyAll(Size(widget.width, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        for (final e in widget.entries) ...[
          _item(context, e, selected: e.value == widget.value),
          if (e.dividerAfter) const Divider(height: 7, indent: 6, endIndent: 6),
        ],
      ],
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): _controller.open,
          const SingleActivator(LogicalKeyboardKey.arrowUp): _controller.open,
        },
        // Above the Focus: Enter / Space look up ActivateIntent from the
        // focused node upwards.
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _buttonFocus,
            onFocusChange: (_) => setState(() {}),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                onTap: () {
                  _buttonFocus.requestFocus();
                  _toggle();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: widget.width,
                  height: 32,
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundDecoration: strong
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.primary, width: 2),
                        )
                      : null,
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(
                        widget.icon,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      // One line rather than two flexible texts: those split
                      // the width in half and cut the IP while the name
                      // left room unused. Here only the name's tail is cut.
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: label ?? widget.placeholder,
                                style: TextStyle(
                                  fontWeight: label == null
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: label == null
                                      ? colors.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              if (current?.detail case final detail?)
                                TextSpan(text: '   $detail', style: muted),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    SettingsDropdownEntry<T> e, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MenuItemButton(
      // The menu opens on the current value, so arrows move from there.
      autofocus: selected,
      onPressed: () {
        widget.onSelected(e.value);
        _buttonFocus.requestFocus();
      },
      style: MenuItemButton.styleFrom(
        minimumSize: Size(widget.width - 8, 36),
        padding: const EdgeInsets.only(left: 8, right: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      leadingIcon: SizedBox(
        width: 18,
        child: selected
            ? Icon(Icons.check, size: 18, color: colors.primary)
            : null,
      ),
      trailingIcon: e.detail == null
          ? null
          : Text(
              e.detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
      child: Text(
        e.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: selected ? colors.primary : null,
        ),
      ),
    );
  }
}
