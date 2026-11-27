import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../domain/free_grid_view.dart';
import '../../../../domain/warp_session_state.dart';
import '../../common/dialog_parts.dart';
import '../../custom_tooltip.dart';
import 'free_grid_canvas_card.dart';
import 'free_grid_parts.dart';

/// The footer of the dialog in the Free grid: what is going on, and the one
/// filled button, `Store to PC-n`. The footer keeps the height every mode
/// has.
class FreeGridFooter extends StatelessWidget {
  const FreeGridFooter({
    super.key,
    required this.session,
    required this.compact,
  });

  final WarpSessionState session;

  /// The canvas card is compact: it has no note line, so a warning that
  /// applies is the footer's message.
  final bool compact;

  static const double storeMinWidth = 150;

  bool get _storing => session.phase == WarpSessionPhase.storing;

  bool get _reading =>
      session.phase == WarpSessionPhase.detecting ||
      session.phase == WarpSessionPhase.loading;

  @override
  Widget build(BuildContext context) {
    final label = freeGridSlotLabel(session.slot);
    return DialogFooter(
      message: _message(context, label),
      actions: [_StoreButton(label: label, storing: _storing)],
    );
  }

  Widget _message(BuildContext context, String label) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final failure = session.failureMessage;
    // A write that failed leaves the memory on screen: say what happened, in
    // the error colour, where the operator is looking. One line that ends
    // with what to do; the reason is the tooltip's.
    if (session.phase == WarpSessionPhase.failed &&
        session.table != null &&
        failure != null) {
      return _Line(
        leading: Icon(FreeGridIcons.error, size: 16, color: cs.error),
        text: failure,
        tooltip: session.failureDetail,
        style: t.description.copyWith(color: cs.error),
      );
    }
    // A read that failed has its say on the canvas; nothing can be edited.
    if (session.phase == WarpSessionPhase.failed) {
      return _Line(
        leading: Icon(FreeGridIcons.info, size: 16, color: t.secondary),
        text: '$label was not read',
      );
    }
    // A grid overlay or a cursor the projector did not take: the switch says
    // on, so the operator has to be told it is not.
    final overlayError = session.previewError;
    if (overlayError != null && !_reading && !_storing) {
      return _Line(
        leading: Icon(FreeGridIcons.error, size: 16, color: cs.error),
        text: overlayError,
        style: t.description.copyWith(color: cs.error),
      );
    }
    if (_reading) {
      return _Line(
        leading: const _Spinner(14),
        text: session.phase == WarpSessionPhase.detecting
            ? 'Reading the memory from the projector'
            : 'Reading $label from the projector',
      );
    }
    if (_storing) {
      return _Line(
        leading: const _Spinner(14),
        text: 'Storing to $label, about 1 second',
      );
    }
    final warning = AppStatusColors.of(context).warning;
    // The table is in the projector, but its stored time or grid size is
    // not: until the next read or write the operator is told.
    if (session.lastStoreIncomplete) {
      return _Line(
        leading: Icon(FreeGridIcons.warning, size: 16, color: warning),
        text:
            '$label is stored, but the projector did not keep its stored '
            'time or grid size. Reload to check.',
        tooltip:
            '$label is stored, but the projector did not keep its stored '
            'time or grid size. Reload to check.',
        style: t.description.copyWith(color: t.primary),
      );
    }
    // A compact canvas has no note line: what it would warn about goes here,
    // with the whole text in a tooltip.
    final note = freeGridNote(session);
    if (compact && note.isWarning) {
      final text = freeGridWarningText(note, session);
      return _Line(
        key: const ValueKey('free-grid-footer-warning'),
        leading: Icon(FreeGridIcons.warning, size: 16, color: warning),
        text: text,
        tooltip: text,
        style: t.description.copyWith(color: t.primary),
      );
    }
    return _Line(
      leading: Icon(FreeGridIcons.info, size: 16, color: t.secondary),
      text: 'Edits show on the projector live, Store keeps them in $label',
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.leading,
    required this.text,
    this.style,
    this.tooltip,
  });

  final Widget leading;
  final String text;
  final TextStyle? style;

  /// The whole text or the reason behind it, for a line that is cut short.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final line = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return Row(
      children: [
        // The spinner sits in the icon's 16 px box, so the text keeps its
        // place when one gives way to the other.
        SizedBox.square(dimension: 16, child: Center(child: leading)),
        const SizedBox(width: 8),
        Flexible(
          child: tooltip == null
              ? line
              : CustomTooltip(
                  message: tooltip!,
                  placement: TooltipPlacement.top,
                  maxWidth: 380,
                  child: line,
                ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner(this.size, {this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({required this.label, required this.storing});

  final String label;
  final bool storing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = storing ? 'Storing' : 'Store to $label';
    return FilledButton(
      key: const ValueKey('free-grid-store'),
      // Nothing can be stored until something is edited. While a write runs
      // the button stays filled, and a click on it does nothing.
      onPressed: storing ? () {} : null,
      // The height every footer button has, so the footer keeps its 56 px.
      style: FilledButton.styleFrom(
        minimumSize: const Size(FreeGridFooter.storeMinWidth, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (storing)
            // In the icon's 18 px box, so the label keeps its place.
            SizedBox.square(
              dimension: 18,
              child: Center(child: _Spinner(16, color: cs.onPrimary)),
            )
          else
            const Icon(FreeGridIcons.store, size: 18),
          const SizedBox(width: 8),
          // The longest label sits invisibly under the real one, so the
          // button keeps its width.
          Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text('Store to $label'),
              ),
              Text(text),
            ],
          ),
        ],
      ),
    );
  }
}
