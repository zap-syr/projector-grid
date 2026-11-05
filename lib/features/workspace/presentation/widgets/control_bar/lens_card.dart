import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/command_source.dart';
import '../../../domain/control_options.dart';
import '../../../domain/lens_commands.dart';
import '../../providers/selected_lens_lock_provider.dart';
import '../../providers/workspace_provider.dart';
import '../common/dialog_parts.dart';
import '../custom_tooltip.dart';
import 'control_bar_parts.dart';

/// Direction of one lens step button, named after its chevron SVG.
enum LensDirection { up, down, left, right }

/// Key of a lens step button: `lens-up-fast`, `focus-left-slow`, …
ValueKey<String> lensButtonKey(
  String prefix,
  LensDirection direction,
  LensSpeed speed,
) => ValueKey('$prefix-${direction.name}-${speed.name}');

String _asset(LensDirection direction, LensSpeed speed) =>
    'assets/icons/lens_shift/${direction.name}_${speed.name}.svg';

/// Lens shift cross, Focus and Zoom rows and the collapsible Lens setup
/// (calibration, lens type). Home position sits in the header, away from
/// the arrows, so it isn't hit by mistake.
class LensCard extends ConsumerStatefulWidget {
  const LensCard({super.key});

  @override
  ConsumerState<LensCard> createState() => _LensCardState();
}

class _LensCardState extends ConsumerState<LensCard> {
  static final _calibrationItems = dropdownItems(kLensCalibrationOptions);
  static final _lensTypeItems = dropdownItems(kLensTypeOptions);

  // Seven 38 px buttons and six gaps fill 284 of the card's 296 px.
  static const double _crossButton = 38;
  static const double _crossRowGap = 5;
  static const double _crossColumnGap = 3;
  static const double _linearButton = 36;

  bool _isSending = false;
  bool _setupOpen = false;
  String _calibration = 'VXX:LNSI0=+00001';
  String _lensType = 'VXX:LNEI1=+00001';

  // A motor step is dropped while the previous one is still in flight, so
  // holding a key or clicking fast doesn't queue up moves.
  Future<void> _throttledSend(String cmd) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await ref
          .read(workspaceProvider.notifier)
          .sendCommandToSelected(cmd, source: CommandSource.controlBar);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // The whole selection has Lens lock on: every motor button is disabled in
  // place. A partly locked selection keeps them enabled; the dispatch skips
  // the locked projectors.
  bool _locked = false;

  Widget _step(
    String keyPrefix,
    LensDirection direction,
    LensAxis axis,
    LensSpeed speed, {
    required bool plus,
    double size = _crossButton,
  }) => LensStepButton(
    key: lensButtonKey(keyPrefix, direction, speed),
    asset: _asset(direction, speed),
    size: size,
    onPressed: _locked
        ? null
        : () => _throttledSend(lensStepCommand(axis, plus: plus, speed: speed)),
  );

  Widget _cross() {
    Widget v(LensDirection d, LensSpeed s) =>
        _step('lens', d, LensAxis.shiftV, s, plus: d == LensDirection.up);
    Widget h(LensDirection d, LensSpeed s) =>
        _step('lens', d, LensAxis.shiftH, s, plus: d == LensDirection.right);
    const rowGap = SizedBox(height: _crossRowGap);
    const columnGap = SizedBox(width: _crossColumnGap);
    return Column(
      children: [
        v(LensDirection.up, LensSpeed.fast),
        rowGap,
        v(LensDirection.up, LensSpeed.normal),
        rowGap,
        v(LensDirection.up, LensSpeed.slow),
        rowGap,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            h(LensDirection.left, LensSpeed.fast),
            columnGap,
            h(LensDirection.left, LensSpeed.normal),
            columnGap,
            h(LensDirection.left, LensSpeed.slow),
            // The empty centre cell and its two gaps.
            const SizedBox(width: _crossButton + 2 * _crossColumnGap),
            h(LensDirection.right, LensSpeed.slow),
            columnGap,
            h(LensDirection.right, LensSpeed.normal),
            columnGap,
            h(LensDirection.right, LensSpeed.fast),
          ],
        ),
        rowGap,
        v(LensDirection.down, LensSpeed.slow),
        rowGap,
        v(LensDirection.down, LensSpeed.normal),
        rowGap,
        v(LensDirection.down, LensSpeed.fast),
      ],
    );
  }

  /// Focus or Zoom: three steps towards near / out, a gap, three towards
  /// far / in, fast on the outside.
  Widget _linear(String label, LensAxis axis) {
    final prefix = label.toLowerCase();
    Widget b(LensDirection d, LensSpeed s) => _step(
      prefix,
      d,
      axis,
      s,
      plus: d == LensDirection.right,
      size: _linearButton,
    );
    const gap = SizedBox(width: _crossColumnGap);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.of(context).body
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          b(LensDirection.left, LensSpeed.fast),
          gap,
          b(LensDirection.left, LensSpeed.normal),
          gap,
          b(LensDirection.left, LensSpeed.slow),
          const SizedBox(width: 12),
          b(LensDirection.right, LensSpeed.slow),
          gap,
          b(LensDirection.right, LensSpeed.normal),
          gap,
          b(LensDirection.right, LensSpeed.fast),
        ],
      ),
    );
  }

  Widget _homeButton() {
    return CustomTooltip(
      message: 'Home position',
      child: SizedBox.square(
        dimension: 30,
        child: OutlinedButton(
          key: const ValueKey('lens-home'),
          style: commandButtonStyle(
            context,
            height: 30,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          onPressed: _locked
              ? null
              : () => sendToSelected(ref, kLensHomeCommand),
          child: const Icon(Icons.home_outlined, size: 16),
        ),
      ),
    );
  }

  /// Lens lock of the selection: outlined with an open lock when none of
  /// it is locked, filled when all of it is, outlined in blue with a dot
  /// when part of it is. A click locks all unless all is locked already.
  Widget _lockButton(({LensLockState state, int locked, int total}) lock) {
    final cs = Theme.of(context).colorScheme;
    String projectors(int n) => n == 1 ? '1 projector' : '$n projectors';
    final message = switch (lock.state) {
      LensLockState.none =>
        lock.total == 0 ? 'Lock lens' : 'Lock lens (${projectors(lock.total)})',
      LensLockState.all => 'Unlock lens (${projectors(lock.total)})',
      LensLockState.some =>
        'Lens locked on ${lock.locked} of ${projectors(lock.total)}. '
            'Click to lock all',
    };
    void toggle() => ref
        .read(workspaceProvider.notifier)
        .toggleLensLockOfSelected(source: CommandSource.controlBar);
    const shape = CircleBorder();
    final Widget button = switch (lock.state) {
      LensLockState.all => FilledButton(
        key: const ValueKey('lens-lock'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.square(30),
          maximumSize: const Size.square(30),
          visualDensity: VisualDensity.standard,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
        ),
        onPressed: toggle,
        child: const Icon(Icons.lock, size: 16),
      ),
      LensLockState.some => OutlinedButton(
        key: const ValueKey('lens-lock'),
        style:
            commandButtonStyle(
              context,
              height: 30,
              padding: EdgeInsets.zero,
              shape: shape,
              iconColor: cs.primary,
            ).copyWith(
              side: WidgetStatePropertyAll(
                BorderSide(color: cs.primary, width: 1.5),
              ),
            ),
        onPressed: toggle,
        child: const Icon(Icons.lock_outline, size: 16),
      ),
      LensLockState.none => OutlinedButton(
        key: const ValueKey('lens-lock'),
        style: commandButtonStyle(
          context,
          height: 30,
          padding: EdgeInsets.zero,
          shape: shape,
        ),
        onPressed: toggle,
        child: const Icon(Icons.lock_open_outlined, size: 16),
      ),
    };
    return CustomTooltip(
      message: message,
      child: SizedBox.square(
        dimension: 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: button),
            if (lock.state == LensLockState.some)
              Positioned(
                top: -2,
                right: -2,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('lens-lock-partial'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DialogSurfaces.of(context).card,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupToggle() {
    final t = AppText.of(context);
    return Semantics(
      button: true,
      expanded: _setupOpen,
      child: InkWell(
        key: const ValueKey('lens-setup-toggle'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _setupOpen = !_setupOpen),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(Icons.tune, size: 16, color: t.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lens setup',
                  style: t.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              AnimatedRotation(
                turns: _setupOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.expand_more, size: 20, color: t.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setup() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownSendRow<String>(
            label: 'Calibration',
            items: _calibrationItems,
            value: _calibration,
            onChanged: (v) => setState(() => _calibration = v),
            // Calibration runs the lens through its whole range.
            onSend: _locked ? null : () => sendToSelected(ref, _calibration),
          ),
          const SizedBox(height: ControlBarMetrics.settingGap),
          DropdownSendRow<String>(
            label: 'Lens type',
            items: _lensTypeItems,
            value: _lensType,
            onChanged: (v) => setState(() => _lensType = v),
            onSend: () => sendToSelected(ref, _lensType),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(selectedLensLockProvider);
    _locked = lock.state == LensLockState.all;
    return ControlBarCard(
      icon: Icons.center_focus_weak,
      title: 'Lens shift',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_lockButton(lock), const SizedBox(width: 8), _homeButton()],
      ),
      headerGap: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cross(),
          const SizedBox(height: 16),
          const CardRowDivider(),
          _linear('Focus', LensAxis.focus),
          const CardRowDivider(),
          _linear('Zoom', LensAxis.zoom),
          const CardRowDivider(),
          _setupToggle(),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _setupOpen
                ? _setup()
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
