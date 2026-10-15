import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'scroll_fade.dart';

/// Surfaces of the redesigned dialogs: the body sits below its cards, so a
/// card reads as raised in both themes.
class DialogSurfaces {
  DialogSurfaces._(this.body, this.card, this.editor, this.field, this.soft);

  factory DialogSurfaces.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final light = cs.brightness == Brightness.light;
    return DialogSurfaces._(
      cs.surfaceContainerLow,
      light ? cs.surfaceContainerLowest : cs.surfaceContainer,
      light ? cs.surfaceContainerLow : cs.surfaceContainerHigh,
      cs.surfaceContainerLowest,
      cs.surfaceContainerHighest,
    );
  }

  final Color body;
  final Color card;

  /// An open editor inside a card (Groups' inline editor): one step off the
  /// card.
  final Color editor;
  final Color field;

  /// Icon tiles and neutral pills.
  final Color soft;
}

/// Monospace text for the IP and port fields.
final monoFieldStyle = AppTheme.mono(const TextStyle(fontSize: 13.5));

/// Plain text fields: 14 px, so a field is 40 px tall like the mono ones.
const plainFieldStyle = TextStyle(fontSize: 14);

/// Height of every field in these dialogs, text fields and [AppDropdown]
/// alike, so a row of them lines up.
const double dialogFieldHeight = 40;

/// The outlined field of these dialogs: [dialogFieldHeight] tall, radius 10,
/// label above it (see [LabeledField]) rather than inside, so the help line
/// can sit under.
InputDecoration dialogFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefix,
  Widget? suffixIcon,
  bool error = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final surfaces = DialogSurfaces.of(context);
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
    // The suffix slot sets the height: a dense field's border follows its
    // text (about 32 px), and `constraints` only sizes the box around it,
    // so a field would still draw shorter than the dropdowns beside it.
    // A field without a suffix gets an empty one, which also gives the
    // right-hand padding.
    suffixIcon: suffixIcon ?? const SizedBox(width: 12),
    suffixIconConstraints: BoxConstraints(
      minWidth: suffixIcon == null ? 12 : 36,
      minHeight: dialogFieldHeight,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    this.error = false,
  });

  final String label;
  final Widget child;
  final Widget? help;

  /// Label in the error colour.
  final bool error;

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
            color: error ? cs.error : cs.onSurfaceVariant,
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

/// A raised card of these dialogs (radius 14). [borderColor] for a warning
/// border; [highlighted] for the card tied to a selection or an open form
/// (2 px primary border); [muted] for a locked card that should read as
/// unavailable at a glance.
class DialogCard extends StatelessWidget {
  const DialogCard({
    super.key,
    required this.child,
    this.borderColor,
    this.highlighted = false,
    this.muted = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color? borderColor;
  final bool highlighted;
  final bool muted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfaces = DialogSurfaces.of(context);
    final radius = BorderRadius.circular(14);
    return Container(
      // The 1 px the border used to inset the content by, kept so card
      // sizes don't change.
      padding: padding.add(const EdgeInsets.all(1)),
      clipBehavior: Clip.antiAlias,
      // The border is drawn over the content, not under it: a child with
      // its own square-cornered fill (a group row, the New group form)
      // painted over the border where it curves, and the corners looked
      // cut off.
      // Highlighted: a 2 px primary border and nothing outside it. A soft
      // ring around it read as a background larger than the card.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: highlighted ? cs.primary : borderColor ?? cs.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      decoration: BoxDecoration(
        color: muted ? surfaces.editor : surfaces.card,
        borderRadius: radius,
      ),
      child: child,
    );
  }
}

/// The square icon tile at the start of a card row: neutral by default,
/// [primary] for a card whose subject is the primary accent (Brightness).
class DialogIconTile extends StatelessWidget {
  const DialogIconTile(
    this.icon, {
    super.key,
    this.size = 34,
    this.primary = false,
  });

  final IconData icon;
  final double size;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary ? cs.primaryContainer : DialogSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.53,
        color: primary ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
    );
  }
}

/// Footer of these dialogs: a message on the left, then the actions. Pass
/// [actionLabel] for the usual Cancel + primary button; leave it null for an
/// info-only footer (dialogs that send changes right away close with ✕).
class DialogFooter extends StatelessWidget {
  const DialogFooter({
    super.key,
    this.actionLabel,
    this.widestActionLabel,
    this.onAction,
    this.actionIcon,
    this.message,
    this.actions,
  });

  final String? actionLabel;

  /// The longest label this button ever shows (`Add projectors` for `Add
  /// projector`): the button keeps that width, so a label change never
  /// moves Cancel.
  final String? widestActionLabel;
  final IconData? actionIcon;

  /// Null disables the action.
  final VoidCallback? onAction;
  final Widget? message;

  /// Replaces Cancel + the primary button (e.g. Delete / Duplicate /
  /// Schedule again).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = actionLabel;
    final widest = widestActionLabel;
    // The widest label laid out invisibly under the real one sets the width.
    final Widget labelText = label == null
        ? const SizedBox.shrink()
        : widest == null
        ? Text(label)
        : Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(widest),
              ),
              Text(label),
            ],
          );
    final buttons =
        actions ??
        [
          if (label != null) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (actionIcon != null)
              FilledButton.icon(
                key: const ValueKey('dialog-footer-action'),
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: labelText,
              )
            else
              FilledButton(
                key: const ValueKey('dialog-footer-action'),
                onPressed: onAction,
                child: labelText,
              ),
          ],
        ];
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: DialogSurfaces.of(context).card,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              child: message ?? const SizedBox.shrink(),
            ),
          ),
          for (final b in buttons) ...[const SizedBox(width: 8), b],
        ],
      ),
    );
  }
}

/// The footer line of dialogs that send every change at once: an info icon
/// and "Changes are sent to the projector right away", or, while [loading],
/// a small spinner and "Reading current values from the projector…".
class SentRightAwayNote extends StatelessWidget {
  const SentRightAwayNote({super.key, this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            loading
                ? 'Reading current values from the projector…'
                : 'Changes are sent to the projector right away',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The scrolling body of these dialogs: scrollbar and edge fade when it
/// doesn't fit (small windows), title bar and footer stay put.
class DialogScrollBody extends StatefulWidget {
  const DialogScrollBody({
    super.key,
    required this.child,
    this.padding,
    this.fill,
    this.fillGap = 0,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// Placed under [child], [fillGap] below it, and stretched to the bottom
  /// of the body (a list or preview card that should end at the same
  /// distance from the footer on every tab). It never gets less than its
  /// own height: then the body scrolls.
  final Widget? fill;
  final double fillGap;

  @override
  State<DialogScrollBody> createState() => _DialogScrollBodyState();
}

class _DialogScrollBodyState extends State<DialogScrollBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding ?? const EdgeInsets.all(24);
    final fill = widget.fill;
    return Scrollbar(
      controller: _controller,
      child: ScrollFade(
        child: fill == null
            ? SingleChildScrollView(
                controller: _controller,
                padding: padding,
                child: widget.child,
              )
            : CustomScrollView(
                controller: _controller,
                slivers: [
                  SliverPadding(
                    padding: padding.copyWith(bottom: widget.fillGap),
                    sliver: SliverToBoxAdapter(child: widget.child),
                  ),
                  // The padding goes inside: SliverFillRemaining under a
                  // SliverPadding still fills to the very bottom.
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: padding.copyWith(top: 0),
                      child: fill,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
