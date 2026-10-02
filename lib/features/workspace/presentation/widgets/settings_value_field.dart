import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Preferences text field: filled, no outline at rest, a 2px primary
/// border while editing, the unit inside. Focusing it selects the whole
/// value; Enter keeps the edit and leaves, Esc puts the old value back and
/// leaves without closing the dialog.
class SettingsValueField extends StatefulWidget {
  const SettingsValueField({
    super.key,
    required this.controller,
    this.unit,
    this.leading,
    this.width,
    this.inputWidth = 40,
    this.numeric = true,
    this.obscureText = false,
    this.maxLength,
    this.hintText,
    this.hasError = false,
    this.enabled = true,
    this.onChanged,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String? unit;

  /// Small icon in front of the value (the alert severity icons).
  final Widget? leading;

  /// Fixed field width, the text taking what's left. Null sizes the field to
  /// [inputWidth] plus the leading icon and unit.
  final double? width;
  final double inputWidth;

  /// Digits only, right-aligned, tabular. Otherwise left-aligned free text
  /// (IP addresses; PINs set [obscureText] and stay digits-only).
  final bool numeric;
  final bool obscureText;
  final int? maxLength;
  final String? hintText;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;

  @override
  State<SettingsValueField> createState() => _SettingsValueFieldState();
}

class _SettingsValueFieldState extends State<SettingsValueField> {
  final _focusNode = FocusNode();
  var _hovered = false;

  /// The value when editing started, for Esc.
  var _before = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _before = widget.controller.text;
      // A click places the caret after focus arrives, so selecting right
      // away would be undone; select once that has happened.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_focusNode.hasFocus) return;
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      });
    }
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !_focusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    widget.controller.text = _before;
    widget.onChanged?.call(_before);
    _focusNode.unfocus();
    // Handled here so the dialog's own Esc (close) never sees it.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final editing = _focusNode.hasFocus;
    final accent = widget.hasError ? colors.error : colors.primary;
    final base = colors.surfaceContainerHighest;
    final fill = widget.hasError
        ? Color.alphaBlend(colors.error.withValues(alpha: 0.08), base)
        : editing
        ? Color.alphaBlend(colors.primary.withValues(alpha: 0.08), base)
        : _hovered && widget.enabled
        ? Color.alphaBlend(colors.onSurface.withValues(alpha: 0.06), base)
        : base;
    final borderWidth = editing ? 2.0 : (widget.hasError ? 1.0 : 0.0);

    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: widget.numeric ? FontWeight.w600 : FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: widget.obscureText ? 2.5 : null,
    );
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      fontStyle: FontStyle.italic,
      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
    );

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      textAlign: widget.numeric ? TextAlign.end : TextAlign.start,
      keyboardType: widget.numeric || widget.obscureText
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: [
        if (widget.numeric || widget.obscureText)
          FilteringTextInputFormatter.digitsOnly
        else
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        if (widget.maxLength case final max?)
          LengthLimitingTextInputFormatter(max),
      ],
      style: valueStyle,
      decoration: InputDecoration.collapsed(
        hintText: widget.hintText,
        hintStyle: hintStyle,
      ),
      onChanged: widget.onChanged,
      onSubmitted: (_) => _focusNode.unfocus(),
    );

    final row = Row(
      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
      spacing: 5,
      children: [
        ?widget.leading,
        if (widget.width == null)
          SizedBox(width: widget.inputWidth, child: field)
        else
          Expanded(child: field),
        if (widget.unit case final unit?)
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
      ],
    );

    return Semantics(
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.text
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.enabled ? _focusNode.requestFocus : null,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.45,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: widget.width,
                height: 32,
                padding: EdgeInsets.only(
                  left: widget.numeric ? 8 : 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                ),
                // A foreground border: a decoration border would pad the
                // content and shift the text when it appears.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: borderWidth == 0
                      ? null
                      : Border.all(color: accent, width: borderWidth),
                ),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
