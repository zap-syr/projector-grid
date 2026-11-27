import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../domain/free_grid_view.dart';
import '../../../../domain/geometry_modes.dart';
import '../../../../domain/warp_codec.dart';
import '../../../../domain/warp_session_state.dart';
import '../../common/canvas_card.dart';
import '../../common/controls_card.dart';
import '../../common/dashed_border.dart';
import '../../common/dialog_parts.dart';
import '../../common/key_caps.dart';
import '../geometry_loading.dart';
import 'free_grid_canvas.dart';
import 'free_grid_help.dart';
import 'free_grid_painter.dart';
import 'free_grid_parts.dart';

/// The key of the Free grid's canvas card, for tests.
const freeGridCanvasCardKey = ValueKey('free-grid-canvas-card');

/// `PC-1`: the label of the memory a session shows.
String freeGridSlotLabel(WarpSlot slot) => GeometryMode.forWarpSlot(slot).label;

/// The Free grid's left card: header with the count and the actions, the
/// canvas (or what stands in for it while a memory is read, fails to read or
/// is written), and a footer with the legend and one note line.
///
/// The actions are placed and disabled; selection, dragging and the actions
/// themselves come later.
class FreeGridCanvasCard extends StatefulWidget {
  const FreeGridCanvasCard({
    super.key,
    required this.session,
    required this.compact,
  });

  final WarpSessionState session;

  /// The card is narrower than [FreeGridSplit.compactBelow].
  final bool compact;

  @override
  State<FreeGridCanvasCard> createState() => _FreeGridCanvasCardState();
}

class _FreeGridCanvasCardState extends State<FreeGridCanvasCard> {
  final _focus = FocusNode(debugLabel: 'free grid canvas');

  /// Whether the movable range frame shows on the canvas, set by the canvas
  /// after it lays out, for the legend.
  final _rangeVisible = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _focus.dispose();
    _rangeVisible.dispose();
    super.dispose();
  }

  WarpSessionState get _s => widget.session;

  bool get _hasTable => _s.table != null && _s.caps != null;

  /// What the canvas shows: the drawing, or something in its place.
  bool get _showsDrawing => _hasTable && !_reading;

  bool get _reading =>
      _s.phase == WarpSessionPhase.detecting ||
      _s.phase == WarpSessionPhase.loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withValues(alpha: 0.6),
    );
    return DialogCard(
      key: freeGridCanvasCardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(session: _s, compact: widget.compact, active: _showsDrawing),
          divider,
          Expanded(child: _body(context)),
          divider,
          _Footer(
            session: _s,
            compact: widget.compact,
            rangeVisible: _rangeVisible,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final label = freeGridSlotLabel(_s.slot);
    if (_reading) {
      return GeometryLoadingView(
        title: _s.phase == WarpSessionPhase.detecting
            ? 'Reading the memory from the projector'
            : 'Reading $label from the projector',
        detail:
            'Free grid is already selected on the projector. The control '
            'points appear once the $label table is read, in about a second.',
      );
    }
    if (!_hasTable) {
      return _ReadFailed(
        title: 'Could not read $label',
        detail: _s.failureMessage ?? '',
      );
    }
    final storing = _s.phase == WarpSessionPhase.storing;
    return Stack(
      children: [
        Positioned.fill(
          child: FreeGridCanvas(
            session: _s,
            compact: widget.compact,
            enabled: !storing,
            focusNode: _focus,
            onRangeFrameVisible: (visible) => _rangeVisible.value = visible,
            clusterTrailing: widget.compact
                ? FreeGridHelpButton(enabled: !storing, size: 26, iconSize: 16)
                : null,
          ),
        ),
        if (storing) Positioned.fill(child: _StoringOverlay(session: _s)),
      ],
    );
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.compact,
    required this.active,
  });

  final WarpSessionState session;
  final bool compact;

  /// A memory is shown and no transfer runs.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final counts = session.gridCounts;
    final String? pill = switch (session.phase) {
      _ when compact => null,
      WarpSessionPhase.storing => 'Storing',
      _ when session.table != null && !session.busy =>
        '${counts.columns} x ${counts.rows} points',
      _ => null,
    };
    final separator = Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
    // Placed for the actions that come with selection and editing; none can
    // run yet.
    return SizedBox(
      height: compact ? 40 : CanvasCard.headerHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 16, 0, compact ? 4 : 6, 0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Control points',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.cardTitle,
                    ),
                  ),
                  if (pill != null) ...[
                    const SizedBox(width: 10),
                    Flexible(child: CardPill(pill)),
                  ],
                ],
              ),
            ),
            const FreeGridIconButton(
              key: ValueKey('free-grid-undo'),
              icon: FreeGridIcons.undo,
              tooltip: 'Undo',
              onPressed: null,
            ),
            const FreeGridIconButton(
              key: ValueKey('free-grid-redo'),
              icon: FreeGridIcons.redo,
              tooltip: 'Redo',
              onPressed: null,
            ),
            separator,
            const FreeGridIconButton(
              key: ValueKey('free-grid-bezier'),
              icon: FreeGridIcons.bezier,
              tooltip: 'Bezier on selection (B)',
              onPressed: null,
            ),
            const FreeGridIconButton(
              key: ValueKey('free-grid-reset-positions'),
              icon: FreeGridIcons.resetPositions,
              tooltip: 'Reset positions (R)',
              onPressed: null,
            ),
            const FreeGridIconButton(
              key: ValueKey('free-grid-mirror-horizontally'),
              icon: FreeGridIcons.mirrorHorizontally,
              tooltip: 'Mirror horizontally (H)',
              onPressed: null,
            ),
            const FreeGridIconButton(
              key: ValueKey('free-grid-mirror-vertically'),
              icon: FreeGridIcons.mirrorVertically,
              quarterTurns: 1,
              tooltip: 'Mirror vertically (V)',
              onPressed: null,
            ),
            if (!compact) ...[separator, FreeGridHelpButton(enabled: active)],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ states

/// The canvas' place while a memory could not be read.
class _ReadFailed extends StatelessWidget {
  const _ReadFailed({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FreeGridIcons.error, size: 28, color: cs.error),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: t.description,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims the canvas while a write runs and says how far it is.
class _StoringOverlay extends StatelessWidget {
  const _StoringOverlay({required this.session});

  final WarpSessionState session;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final label = freeGridSlotLabel(session.slot);
    final total = session.progressTotal;
    final text = total > 0
        ? 'Writing the table to $label, step ${session.progressDone} of $total'
        : 'Writing the table to $label';
    final fraction = total > 0
        ? (session.progressDone / total).clamp(0.0, 1.0)
        : 0.0;
    return Stack(
      children: [
        // Takes the pointer too: nothing under it may be used meanwhile.
        Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              color: DialogSurfaces.of(context).card.withValues(alpha: 0.55),
            ),
          ),
        ),
        Center(
          child: Container(
            key: const ValueKey('free-grid-storing-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sc.tooltipBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sc.tooltipBorder),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(text, style: t.description.copyWith(color: t.primary)),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: cs.outlineVariant)),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: ColoredBox(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ footer

class _Footer extends StatelessWidget {
  const _Footer({
    required this.session,
    required this.compact,
    required this.rangeVisible,
  });

  final WarpSessionState session;
  final bool compact;
  final ValueNotifier<bool> rangeVisible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: rangeVisible,
            builder: (context, visible, _) =>
                _Legend(compact: compact, showRange: visible && !compact),
          ),
          if (!compact) _NoteLine(session: session),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.compact, required this.showRange});

  final bool compact;
  final bool showRange;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final warning = AppStatusColors.of(context).warning;
    return CanvasLegend(
      items: [
        (
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: t.tertiary),
            ),
          ),
          'Panel',
        ),
        (
          Center(child: Container(height: 2, color: cs.primary)),
          compact ? 'Grid' : 'Control grid',
        ),
        if (showRange)
          (
            DashedBorder(
              color: t.tertiary,
              radius: 2,
              dash: 3,
              gap: 2,
              child: const SizedBox.expand(),
            ),
            'Movable range',
          ),
        (
          CustomPaint(painter: FreeGridFoldedSwatch(warning)),
          compact ? 'Folded' : 'Folded cell',
        ),
      ],
    );
  }
}

/// The one note line under the legend. Its height holds two lines in every
/// state, so a longer warning never moves the drawing above it.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.session});

  final WarpSessionState session;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final note = freeGridNote(session);
    final warning = AppStatusColors.of(context).warning;
    final style = t.description.copyWith(
      color: note.isWarning ? t.primary : t.secondary,
    );
    final icon = switch (note.kind) {
      _ when note.isWarning => FreeGridIcons.warning,
      FreeGridNoteKind.hint => FreeGridIcons.help,
      _ => FreeGridIcons.info,
    };
    return Stack(
      children: [
        // Two lines of the note's own text style, never shown.
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text('A\nA', style: style),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 16,
                color: note.isWarning ? warning : t.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                _span(context, note, style),
                key: const ValueKey('free-grid-note'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InlineSpan _span(BuildContext context, FreeGridNote note, TextStyle style) {
    final s = session;
    final label = freeGridSlotLabel(s.slot);
    InlineSpan cap(String key) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: KeyCap(key, small: true),
      ),
    );
    final counts = s.gridCounts;
    return switch (note.kind) {
      FreeGridNoteKind.readOnlyFit => const TextSpan(
        text:
            'This memory cannot be shown as a grid. Reset it to neutral to '
            'edit it.',
      ),
      FreeGridNoteKind.readOnlyPlanes => const TextSpan(
        text:
            'This memory holds one table per colour, the editor cannot '
            'change it.',
      ),
      FreeGridNoteKind.undescribed => TextSpan(
        text:
            'This table has detail a ${counts.columns} x ${counts.rows} grid '
            'cannot describe. Editing will replace it with the grid shape. '
            'Try a larger grid first.',
      ),
      FreeGridNoteKind.belowLegacyLimit => TextSpan(
        text:
            'Some points are below ${warpLegacyReaderLimit(s.caps!.bits)} px. '
            'The projector shows them correctly, but other Panasonic tools '
            'may read this memory as broken.',
      ),
      FreeGridNoteKind.folded => TextSpan(
        text: note.foldedCells == 1
            ? '1 cell is folded, the image shows it mirrored.'
            : '${note.foldedCells} cells are folded, the image shows them '
                  'mirrored.',
      ),
      FreeGridNoteKind.loadingBackup => const TextSpan(
        text:
            'Before the first Store, the table is saved as a backup on this '
            'computer.',
      ),
      FreeGridNoteKind.storingBackup => TextSpan(
        text:
            'The previous $label table is saved as a backup on this '
            'computer. Polling is paused.',
      ),
      FreeGridNoteKind.hint => TextSpan(
        children: [
          const TextSpan(text: 'Drag a point or an area. '),
          cap('Shift'),
          const TextSpan(text: ' or '),
          cap(freeGridModifierName),
          const TextSpan(text: ' click adds to the selection.'),
        ],
      ),
    };
  }
}
