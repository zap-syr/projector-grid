import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/scroll_fade.dart';

/// Surfaces of the Add Projectors / Edit Projector look: the dialog body sits
/// below its cards, so a card reads as raised in both themes.
class FormSurfaces {
  FormSurfaces._(this.body, this.card, this.field, this.soft);

  factory FormSurfaces.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return FormSurfaces._(
      cs.surfaceContainerLow,
      light ? cs.surfaceContainerLowest : cs.surfaceContainer,
      cs.surfaceContainerLowest,
      cs.surfaceContainerHighest,
    );
  }

  final Color body;
  final Color card;
  final Color field;

  /// Icon tiles and neutral pills.
  final Color soft;
}

/// Monospace text for the IP and port fields.
final monoFieldStyle = AppTheme.mono(const TextStyle(fontSize: 13.5));

/// Plain text fields: 14 px, so a field is 40 px tall like the mono ones.
const plainFieldStyle = TextStyle(fontSize: 14);

/// The outlined field of these dialogs: 40 px, radius 10, label above it
/// (see [LabeledField]) rather than inside, so the help line can sit under.
InputDecoration formFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefix,
  Widget? suffixIcon,
  bool error = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final surfaces = FormSurfaces.of(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  final idle = error ? cs.error : cs.outline.withValues(alpha: 0.6);
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: surfaces.field,
    hintText: hintText,
    hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
    prefix: prefix,
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: border(idle),
    focusedBorder: border(error ? cs.error : cs.primary, 2),
    border: border(idle),
  );
}

/// Bold label above a field and an optional help line under it.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.help,
  });

  final String label;
  final Widget child;
  final Widget? help;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (help != null) ...[const SizedBox(height: 6), help!],
      ],
    );
  }
}

enum FieldHelpTone { muted, success, error }

/// One line under a field: plain help, a green check or an error.
class FieldHelp extends StatelessWidget {
  const FieldHelp(this.text, {super.key, this.tone = FieldHelpTone.muted});

  final String text;
  final FieldHelpTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (tone) {
      FieldHelpTone.muted => cs.onSurfaceVariant,
      FieldHelpTone.success => AppStatusColors.of(context).success,
      FieldHelpTone.error => cs.error,
    };
    final icon = switch (tone) {
      FieldHelpTone.muted => null,
      FieldHelpTone.success => Icons.check,
      FieldHelpTone.error => Icons.error_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}

/// A raised card of these dialogs, with an optional warning border.
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FormSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? cs.outlineVariant),
      ),
      child: child,
    );
  }
}

/// The square icon tile at the start of a card row.
class FormIconTile extends StatelessWidget {
  const FormIconTile(this.icon, {super.key, this.size = 34});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FormSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.53, color: cs.onSurfaceVariant),
    );
  }
}

/// Footer of these dialogs: a message on the left, Cancel and the primary
/// action on the right.
class FormFooter extends StatelessWidget {
  const FormFooter({
    super.key,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
    this.message,
  });

  final String actionLabel;
  final IconData? actionIcon;

  /// Null disables the action.
  final VoidCallback? onAction;
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: FormSurfaces.of(context).card,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              child: message ?? const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          if (actionIcon != null)
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 18),
              label: Text(actionLabel),
            )
          else
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// The scrolling body of these dialogs: scrollbar and edge fade when it
/// doesn't fit (small windows), title bar and footer stay put.
class FormScrollBody extends StatefulWidget {
  const FormScrollBody({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<FormScrollBody> createState() => _FormScrollBodyState();
}

class _FormScrollBodyState extends State<FormScrollBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: ScrollFade(
        child: SingleChildScrollView(
          controller: _controller,
          padding: widget.padding ?? const EdgeInsets.all(24),
          child: widget.child,
        ),
      ),
    );
  }
}
