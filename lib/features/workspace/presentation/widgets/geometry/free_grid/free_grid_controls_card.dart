import 'package:material_ui/material_ui.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../domain/free_grid_view.dart';
import '../../../../domain/warp_codec.dart';
import '../../../../domain/warp_control_grid.dart';
import '../../../../domain/warp_session_state.dart';
import '../../common/controls_card.dart';
import '../../common/dialog_parts.dart';
import '../../common/segmented_tabs.dart';
import '../../common/skeleton.dart';
import '../../custom_tooltip.dart';
import '../../sleek_stepper_input.dart';
import 'free_grid_canvas_card.dart';
import 'free_grid_memory_menu.dart';
import 'free_grid_parts.dart';

/// The key of the Free grid's controls card, for tests.
const freeGridControlsCardKey = ValueKey('free-grid-controls-card');

/// What the "On the projector" group holds. The grid overlay is sent to the
/// projector; the cursor and the live preview only keep their state until
/// there are points to follow and drags to preview.
class FreeGridProjectorSettings {
  const FreeGridProjectorSettings({
    this.cursorOn = true,
    this.gridOverlayOn = false,
    this.overlayRgb = freeGridDefaultOverlayRgb,
    this.livePreview = true,
  });

  final bool cursorOn;

  /// Off at the start: opening the dialog must not change the picture.
  final bool gridOverlayOn;
  final int overlayRgb;
  final bool livePreview;

  FreeGridProjectorSettings copyWith({
    bool? cursorOn,
    bool? gridOverlayOn,
    int? overlayRgb,
    bool? livePreview,
  }) => FreeGridProjectorSettings(
    cursorOn: cursorOn ?? this.cursorOn,
    gridOverlayOn: gridOverlayOn ?? this.gridOverlayOn,
    overlayRgb: overlayRgb ?? this.overlayRgb,
    livePreview: livePreview ?? this.livePreview,
  );
}

/// The Free grid's right card, 296 px wide: Memory, Grid, Selected points
/// and On the projector. Groups that cannot act yet are present and
/// disabled, so the layout is final.
class FreeGridControlsCard extends StatelessWidget {
  const FreeGridControlsCard({
    super.key,
    required this.session,
    required this.compact,
    required this.settings,
    required this.onSelectMemory,
    required this.onReload,
    required this.onRestoreBackup,
    required this.onDiscardChanges,
    required this.onReset,
    required this.onCursor,
    required this.onGridOverlay,
    required this.onOverlayColor,
    required this.onLivePreview,
  });

  final WarpSessionState session;
  final bool compact;
  final FreeGridProjectorSettings settings;
  final ValueChanged<WarpSlot> onSelectMemory;
  final VoidCallback onReload;
  final VoidCallback onRestoreBackup;
  final VoidCallback? onDiscardChanges;
  final VoidCallback onReset;
  final ValueChanged<bool> onCursor;
  final ValueChanged<bool> onGridOverlay;
  final ValueChanged<int> onOverlayColor;
  final ValueChanged<bool> onLivePreview;

  bool get _reading =>
      session.phase == WarpSessionPhase.detecting ||
      session.phase == WarpSessionPhase.loading;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.6),
    );
    final List<Widget> groups = _reading
        ? const [
            _SkeletonGroup(title: 'Memory', rows: 1),
            _SkeletonGroup(title: 'Grid', rows: 1),
            _SkeletonGroup(title: 'Selected points', rows: 2),
            _SkeletonGroup(title: 'On the projector', rows: 4),
          ]
        : [
            _MemoryGroup(
              session: session,
              onSelectMemory: onSelectMemory,
              onReload: onReload,
              onRestoreBackup: onRestoreBackup,
              onDiscardChanges: onDiscardChanges,
              onReset: onReset,
            ),
            _GridGroup(session: session),
            _SelectedGroup(session: session, compact: compact),
            _ProjectorGroup(
              session: session,
              settings: settings,
              onCursor: onCursor,
              onGridOverlay: onGridOverlay,
              onOverlayColor: onOverlayColor,
              onLivePreview: onLivePreview,
            ),
          ];
    return DialogCard(
      key: freeGridControlsCardKey,
      child: DialogScrollBody(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, g) in groups.indexed) ...[
              if (i > 0) divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: g,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ shared

/// A group's header line: [title] left, [caption] and [trailing] right, at
/// least 24 px high.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, this.caption, this.trailing});

  final String title;
  final Widget? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 24),
      child: Row(
        children: [
          Text(title, maxLines: 1, style: t.label),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption,
                child: caption ?? const SizedBox.shrink(),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.header, required this.rows});

  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [header, ...rows],
  );
}

/// A 32 px row.
class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 32, child: Row(spacing: 6, children: children));
}

/// `H`, `V`, `X`, `Y`: the 12 px letter before a field.
class _FieldLetter extends StatelessWidget {
  const _FieldLetter(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    child: Text(
      letter,
      textAlign: TextAlign.center,
      style: AppText.of(context).caption.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// A field that cannot be used yet: shown dimmed and out of reach.
class _Disabled extends StatelessWidget {
  const _Disabled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: Opacity(opacity: 0.38, child: child));
}

class _SkeletonGroup extends StatelessWidget {
  const _SkeletonGroup({required this.title, required this.rows});

  final String title;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return _Group(
      header: _GroupHeader(title: title),
      rows: [
        SkeletonPulse(
          child: Column(
            spacing: 4,
            children: [
              for (var i = 0; i < rows; i++)
                const Skeleton(height: 32, radius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ memory

class _MemoryGroup extends StatelessWidget {
  const _MemoryGroup({
    required this.session,
    required this.onSelectMemory,
    required this.onReload,
    required this.onRestoreBackup,
    required this.onDiscardChanges,
    required this.onReset,
  });

  final WarpSessionState session;
  final ValueChanged<WarpSlot> onSelectMemory;
  final VoidCallback onReload;
  final VoidCallback onRestoreBackup;
  final VoidCallback? onDiscardChanges;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final label = freeGridSlotLabel(session.slot);
    final usable = !session.busy;
    final stored = session.storedAt;
    final String? caption = session.table == null
        ? null
        : stored == null
        ? 'Not stored yet'
        : 'Stored ${freeGridTimeLabel(stored)}';
    return _Group(
      header: _GroupHeader(
        title: 'Memory',
        caption: caption == null ? null : Text(caption),
        trailing: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: FreeGridMemoryMenu(
            slotLabel: label,
            // Every entry writes to a memory that has been read.
            enabled: usable && session.table != null,
            backupTakenAt: session.backupTakenAt,
            onRestoreBackup: onRestoreBackup,
            onDiscardChanges: onDiscardChanges,
            onReset: onReset,
          ),
        ),
      ),
      rows: [
        _Row(
          children: [
            Expanded(
              child: SegmentedTabs<WarpSlot>(
                key: const ValueKey('free-grid-memory-tabs'),
                dense: true,
                enabled: usable,
                selected: session.slot,
                onChanged: onSelectMemory,
                tabs: [
                  for (final slot in const [
                    WarpSlot.pc1,
                    WarpSlot.pc2,
                    WarpSlot.pc3,
                  ])
                    SegmentedTab(
                      value: slot,
                      label: freeGridSlotLabel(slot),
                      // Unstored edits set it; none can exist yet.
                      marker: false,
                    ),
                ],
              ),
            ),
            FreeGridIconButton(
              key: const ValueKey('free-grid-reload'),
              icon: FreeGridIcons.reload,
              tooltip: 'Reload $label from the projector',
              onPressed: usable ? onReload : null,
              placement: TooltipPlacement.top,
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- grid

class _GridGroup extends StatelessWidget {
  const _GridGroup({required this.session});

  final WarpSessionState session;

  @override
  Widget build(BuildContext context) {
    final counts = session.gridCounts;
    return _Group(
      header: const _GroupHeader(
        title: 'Grid',
        caption: Text('Resizing keeps the shape'),
      ),
      rows: [
        _Row(
          children: [
            const _FieldLetter('H'),
            _Disabled(
              child: SleekStepperInput(
                width: 60,
                initialValue: '${counts.columns}',
                min: 2,
                max: warpGridMaxColumns.toDouble(),
                onValueChanged: (_) {},
              ),
            ),
            const _FieldLetter('V'),
            _Disabled(
              child: SleekStepperInput(
                width: 60,
                initialValue: '${counts.rows}',
                min: 2,
                max: warpGridMaxRows.toDouble(),
                onValueChanged: (_) {},
              ),
            ),
            const Spacer(),
            const _TonalButton(label: '1/2'),
            const _TonalButton(label: '2x'),
          ],
        ),
      ],
    );
  }
}

/// A 32 px rounded tonal button; disabled until the grid can be resized.
class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: null,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Text(label),
  );
}

// ---------------------------------------------------------------- selected

class _SelectedGroup extends StatelessWidget {
  const _SelectedGroup({required this.session, required this.compact});

  final WarpSessionState session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final counts = session.gridCounts;
    // The canvas card's header has no room for the count in a compact
    // window, so it is shown here while nothing is selected.
    final Widget caption = compact
        ? CardPill('${counts.columns} x ${counts.rows} points')
        : const Text('none');
    return _Group(
      header: _GroupHeader(title: 'Selected points', caption: caption),
      rows: [
        _PositionRow(label: 'Position'),
        _PositionRow(label: 'Offset'),
      ],
    );
  }
}

/// `Position X [ ] Y [ ]`: empty and dimmed with no selection.
class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return _Disabled(
      child: _Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: t.secondary),
            ),
          ),
          const _FieldLetter('X'),
          SleekStepperInput(
            initialValue: '',
            min: -99999,
            max: 99999,
            onValueChanged: (_) {},
          ),
          const _FieldLetter('Y'),
          SleekStepperInput(
            initialValue: '',
            min: -99999,
            max: 99999,
            onValueChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ on projector

class _ProjectorGroup extends StatelessWidget {
  const _ProjectorGroup({
    required this.session,
    required this.settings,
    required this.onCursor,
    required this.onGridOverlay,
    required this.onOverlayColor,
    required this.onLivePreview,
  });

  final WarpSessionState session;
  final FreeGridProjectorSettings settings;
  final ValueChanged<bool> onCursor;
  final ValueChanged<bool> onGridOverlay;
  final ValueChanged<int> onOverlayColor;
  final ValueChanged<bool> onLivePreview;

  @override
  Widget build(BuildContext context) {
    // The projector can only be told something while a memory is loaded and
    // no transfer runs.
    final usable = session.table != null && !session.busy;
    return _Group(
      header: const _GroupHeader(title: 'On the projector'),
      rows: [
        _SwitchRow(
          switchKey: const ValueKey('free-grid-switch-cursor'),
          label: 'Cursor on the selected point',
          value: settings.cursorOn,
          onChanged: usable ? onCursor : null,
        ),
        _SwitchRow(
          switchKey: const ValueKey('free-grid-switch-overlay'),
          label: 'Grid overlay',
          value: settings.gridOverlayOn,
          onChanged: usable ? onGridOverlay : null,
        ),
        _ColorRow(
          rgb: settings.overlayRgb,
          dimmed: !settings.gridOverlayOn,
          onChanged: usable ? onOverlayColor : null,
        ),
        _SwitchRow(
          switchKey: const ValueKey('free-grid-switch-live'),
          label: 'Live preview while dragging',
          value: settings.livePreview,
          onChanged: usable ? onLivePreview : null,
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return _Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(
              color: onChanged == null ? t.disabled : t.secondary,
            ),
          ),
        ),
        Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}

/// The overlay colour: seven swatches, always shown, dimmed while the
/// overlay is off.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.rgb,
    required this.dimmed,
    required this.onChanged,
  });

  final int rgb;
  final bool dimmed;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    return Opacity(
      opacity: dimmed || !enabled ? 0.38 : 1,
      child: _Row(
        children: [
          SizedBox(
            width: 54,
            child: Text('Color', style: t.body.copyWith(color: t.secondary)),
          ),
          for (final c in freeGridOverlayColors)
            CustomTooltip(
              message: c.name,
              child: Semantics(
                button: true,
                selected: c.rgb == rgb,
                label: c.name,
                child: GestureDetector(
                  key: ValueKey('free-grid-swatch-${c.name}'),
                  behavior: HitTestBehavior.opaque,
                  // The chosen colour does nothing when tapped again.
                  onTap: enabled && c.rgb != rgb
                      ? () => onChanged!(c.rgb)
                      : null,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cs.outline),
                      // A 2 px gap in the card colour, then a 2 px ring.
                      boxShadow: c.rgb == rgb
                          ? [
                              BoxShadow(
                                color: DialogSurfaces.of(context).card,
                                spreadRadius: 2,
                              ),
                              BoxShadow(color: t.primary, spreadRadius: 4),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
