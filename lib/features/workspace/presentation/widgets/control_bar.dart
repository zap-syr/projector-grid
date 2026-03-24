import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/workspace_provider.dart';

class ControlBar extends ConsumerStatefulWidget {
  const ControlBar({super.key});

  @override
  ConsumerState<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends ConsumerState<ControlBar> {
  // ── Constants ────────────────────────────────────────────────────────────
  static const double _barWidth = 320;
  static const double _spacingXs = 4;
  static const double _spacingSm = 8;
  static const double _spacingMd = 16;
  static const double _spacingLg = 24;
  static const double _lensShiftCenterGap = 30;

  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedLens = 'VXX:LNEI1=+00001';
  String _selectedTestPattern = 'OTS:87';
  bool _isSending = false;
  String _selectedPictureMode = 'VPM:STD';
  String _selectedBackColor = 'OBC:0';
  String _selectedStartupLogo = 'MLO:2';
  String _selectedProjectionMethod = 'OIL:0';
  String _selectedShutterFadeIn = 'VXX:SEFS1=0.0';
  String _selectedShutterFadeOut = 'VXX:SEFS2=0.0';

  // ── Data ──────────────────────────────────────────────────────────────────
  static const Map<String, String> _lensOptions = {
    'VXX:LNEI1=+00001': 'ET-D75LE6',
    'VXX:LNEI1=+00002': 'ET-D75LE10',
    'VXX:LNEI1=+00003': 'ET-D75LE20',
    'VXX:LNEI1=+00004': 'ET-D75LE30',
    'VXX:LNEI1=+00005': 'ET-D75LE40',
    'VXX:LNEI1=+00009': 'ET-D75LE50',
    'VXX:LNEI1=+00006': 'ET-D75LE8',
    'VXX:LNEI1=+00007': 'ET-D75LE95',
    'VXX:LNEI1=+00008': 'ET-D75LE90',
  };

  static const Map<String, String> _testPatternIcons = {
    'OTS:01': 'assets/icons/test_patterns/tp_white.svg',
    'OTS:02': 'assets/icons/test_patterns/tp_black.svg',
    'OTS:22': 'assets/icons/test_patterns/tp_red.svg',
    'OTS:23': 'assets/icons/test_patterns/tp_green.svg',
    'OTS:24': 'assets/icons/test_patterns/tp_blue.svg',
    'OTS:28': 'assets/icons/test_patterns/tp_cyan.svg',
    'OTS:29': 'assets/icons/test_patterns/tp_magenta.svg',
    'OTS:30': 'assets/icons/test_patterns/tp_yellow.svg',
    'OTS:05': 'assets/icons/test_patterns/tp_window.svg',
    'OTS:06': 'assets/icons/test_patterns/tp_reversed_window.svg',
    'OTS:08': 'assets/icons/test_patterns/tp_colorbar_vert.svg',
    'OTS:51': 'assets/icons/test_patterns/tp_colorbar_horiz.svg',
    'OTS:78': 'assets/icons/test_patterns/tp_focus.svg',
    'OTS:59': 'assets/icons/test_patterns/tp_aspect_frame.svg',
    'OTS:07': 'assets/icons/test_patterns/tp_crosshatch.svg',
    'OTS:70': 'assets/icons/test_patterns/tp_crosshatch_red.svg',
    'OTS:71': 'assets/icons/test_patterns/tp_crosshatch_green.svg',
    'OTS:72': 'assets/icons/test_patterns/tp_crosshatch_blue.svg',
    'OTS:73': 'assets/icons/test_patterns/tp_crosshatch_cyan.svg',
    'OTS:74': 'assets/icons/test_patterns/tp_crosshatch_magenta.svg',
    'OTS:75': 'assets/icons/test_patterns/tp_crosshatch_yellow.svg',
    'OTS:87': 'assets/icons/test_patterns/tp_circle.svg',
  };

  static const Map<String, String> _testPatternOptions = {
    'OTS:01': 'White',
    'OTS:02': 'Black',
    'OTS:22': 'Red',
    'OTS:23': 'Green',
    'OTS:24': 'Blue',
    'OTS:28': 'Cyan',
    'OTS:29': 'Magenta',
    'OTS:30': 'Yellow',
    'OTS:05': 'Window',
    'OTS:06': 'Reversed Window',
    'OTS:08': 'Color Bar Vert',
    'OTS:51': 'Color Bar Horiz',
    'OTS:78': 'Focus',
    // 'OTS:32': 'Focus (Level 0%)',
    // 'OTS:33': 'Focus (Level 50%)',
    // 'OTS:34': 'Focus (Level 100%)',
    'OTS:59': 'Aspect Frame',
    'OTS:07': 'Cross Hatch',
    'OTS:70': 'Cross Hatch Red',
    'OTS:71': 'Cross Hatch Green',
    'OTS:72': 'Cross Hatch Blue',
    'OTS:73': 'Cross Hatch Cyan',
    'OTS:74': 'Cross Hatch Magenta',
    'OTS:75': 'Cross Hatch Yellow',
    'OTS:87': 'Circle',
  };

  static const List<(String, String)> _inputOptions = [
    ('DVI', 'IIS:DVI'),
    ('HDMI', 'IIS:HD1'),
    ('SDI', 'IIS:SD1'),
    ('DLINK', 'IIS:DL1'),
  ];

  static const Map<String, String> _pictureModeOptions = {
    'VPM:DYN': 'Dynamic',
    'VPM:NAT': 'Natural',
    'VPM:STD': 'Standard',
    'VPM:CIN': 'Cinema',
    'VPM:GRA': 'Graphic',
    'VPM:DIC': 'DICOM Sim.',
    'VPM:USR': 'User',
  };

  static const Map<String, String> _backColorOptions = {
    'OBC:0': 'Blue',
    'OBC:1': 'Black',
    'OBC:2': 'User Logo',
    'OBC:3': 'Default Logo',
  };

  static const Map<String, String> _startupLogoOptions = {
    'MLO:0': 'Off',
    'MLO:1': 'User Logo',
    'MLO:2': 'Default Logo',
  };

  static const Map<String, String> _projectionMethodOptions = {
    'OIL:0': 'Front / Desk',
    'OIL:1': 'Rear / Desk',
    'OIL:2': 'Front / Ceiling',
    'OIL:3': 'Rear / Ceiling',
    'OIL:4': 'Front / Auto',
    'OIL:5': 'Rear / Auto',
  };

  static const Map<String, String> _shutterFadeOptions = {
    '0.0': '0.0s (OFF)',
    '0.5': '0.5s',
    '1.0': '1.0s',
    '1.5': '1.5s',
    '2.0': '2.0s',
    '2.5': '2.5s',
    '3.0': '3.0s',
    '3.5': '3.5s',
    '4.0': '4.0s',
    '5.0': '5.0s',
    '7.0': '7.0s',
    '10.0': '10.0s',
  };

  // ── Motor command throttle ────────────────────────────────────────────────
  Future<void> _throttledSend(String cmd) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await ref.read(workspaceProvider.notifier).sendCommandToSelected(cmd);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  /// Builds a group-level header — primary color, uppercase, with a line.
  Widget _buildGroupHeader(BuildContext context, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: _spacingMd),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: _spacingSm),
          Expanded(
            child: Divider(color: primary.withValues(alpha: 0.4), thickness: 1),
          ),
        ],
      ),
    );
  }

  /// Builds a setting-level label (muted, smaller).
  Widget _buildSettingLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _spacingXs),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  /// Two equally-wide `OutlinedButton`s side by side that send discrete commands.
  Widget _buildCommandPair(
    String label1,
    String cmd1,
    String label2,
    String cmd2, {
    required bool enabled,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: enabled
                ? () => ref
                      .read(workspaceProvider.notifier)
                      .sendCommandToSelected(cmd1)
                : null,
            child: Text(label1),
          ),
        ),
        const SizedBox(width: _spacingSm),
        Expanded(
          child: OutlinedButton(
            onPressed: enabled
                ? () => ref
                      .read(workspaceProvider.notifier)
                      .sendCommandToSelected(cmd2)
                : null,
            child: Text(label2),
          ),
        ),
      ],
    );
  }

  /// Six motor-control buttons (fast/normal/slow in each direction) for a
  /// single linear axis such as Focus or Zoom.
  ///
  /// [cmdBase] is the NTCONTROL command prefix, e.g. `VXX:LNSI4`.
  /// Suffix pattern: `=+SSSSSD` where SSS = speed (200/100/000) and D = direction
  /// (1 = left/near/out, 0 = right/far/in).
  Widget _buildLinearControl(
    String title,
    String cmdBase, {
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupHeader(context, title),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: _spacingXs,
          children: [
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/left_fast.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00201')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/left_normal.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00101')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/left_slow.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00001')
                  : null,
            ),
            const Spacer(),
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/right_slow.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00000')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/right_normal.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00100')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/lens_shift/right_fast.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00200')
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// A labelled dropdown + Set button row for sending a single selected command.
  Widget _buildDropdownRow(
    String title,
    Map<String, String> options,
    String selectedValue,
    void Function(String) onChanged, {
    required bool enabled,
    double menuHeight = 250,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(context, title),
        Row(
          children: [
            Expanded(
              child: DropdownMenu<String>(
                requestFocusOnTap: false,
                enableFilter: false,
                expandedInsets: EdgeInsets.zero,
                menuHeight: menuHeight,
                inputDecorationTheme: InputDecorationTheme(
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                initialSelection: selectedValue,
                dropdownMenuEntries: options.entries
                    .map(
                      (e) => DropdownMenuEntry<String>(
                        value: e.key,
                        label: e.value,
                      ),
                    )
                    .toList(),
                onSelected: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
            const SizedBox(width: _spacingSm),
            OutlinedButton(
              onPressed: enabled
                  ? () => ref
                        .read(workspaceProvider.notifier)
                        .sendCommandToSelected(selectedValue)
                  : null,
              child: const Text('Set'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasSelection = ref.watch(
      workspaceProvider.select((nodes) => nodes.any((n) => n.isSelected)),
    );

    return Container(
      width: _barWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              height: 36,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const TabBar(
                tabs: [
                  Tab(text: 'General'),
                  Tab(text: 'System'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── General Tab ──────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(_spacingMd),
                    children: [
                      // Power
                      _buildGroupHeader(context, 'Power'),
                      _buildCommandPair(
                        'On',
                        'PON',
                        'Standby',
                        'POF',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // Shutter
                      _buildGroupHeader(context, 'Shutter'),
                      _buildCommandPair(
                        'Open',
                        'OSH:0',
                        'Close',
                        'OSH:1',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // OSD
                      _buildGroupHeader(context, 'OSD'),
                      _buildCommandPair(
                        'On',
                        'OOS:1',
                        'Off',
                        'OOS:0',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // Inputs
                      _buildGroupHeader(context, 'Inputs'),
                      Row(
                        children: [
                          for (final (label, cmd) in _inputOptions) ...[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _spacingXs,
                                  ),
                                ),
                                onPressed: hasSelection
                                    ? () => ref
                                          .read(workspaceProvider.notifier)
                                          .sendCommandToSelected(cmd)
                                    : null,
                                child: FittedBox(child: Text(label)),
                              ),
                            ),
                            if (label != _inputOptions.last.$1)
                              const SizedBox(width: _spacingXs),
                          ],
                        ],
                      ),
                      const SizedBox(height: _spacingMd),
                      // const Divider(),
                      const SizedBox(height: _spacingMd),

                      // Lens Shift D-Pad
                      _buildGroupHeader(context, 'Lens Shift'),
                      Center(
                        child: Column(
                          children: [
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/up_fast.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00200')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/up_normal.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00100')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/up_slow.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00000')
                                  : null,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/left_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00201')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/left_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00101')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/left_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00001')
                                      : null,
                                ),
                                const SizedBox(width: _lensShiftCenterGap),
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/right_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00000')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/right_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00100')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/lens_shift/right_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00200')
                                      : null,
                                ),
                              ],
                            ),
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/down_slow.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00001')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/down_normal.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00101')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/lens_shift/down_fast.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00201')
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _spacingLg),

                      // Lens Home / Calibration
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasSelection
                                  ? () => ref
                                        .read(workspaceProvider.notifier)
                                        .sendCommandToSelected(
                                          'VXX:LNSI1=+00001',
                                        )
                                  : null,
                              child: const FittedBox(child: Text('Home Pos.')),
                            ),
                          ),
                          const SizedBox(width: _spacingSm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasSelection
                                  ? () => ref
                                        .read(workspaceProvider.notifier)
                                        .sendCommandToSelected(
                                          'VXX:LNSI0=+00001',
                                        )
                                  : null,
                              child: const FittedBox(
                                child: Text('Calibration'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _spacingSm),

                      // Lens type selector
                      Row(
                        children: [
                          Expanded(
                            child: DropdownMenu<String>(
                              requestFocusOnTap: false,
                              enableFilter: false,
                              expandedInsets: EdgeInsets.zero,
                              menuHeight: 250,
                              inputDecorationTheme: InputDecorationTheme(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              initialSelection: _selectedLens,
                              dropdownMenuEntries: _lensOptions.entries
                                  .map(
                                    (e) => DropdownMenuEntry<String>(
                                      value: e.key,
                                      label: e.value,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (val) {
                                if (val != null) {
                                  setState(() => _selectedLens = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: _spacingSm),
                          OutlinedButton(
                            onPressed: hasSelection
                                ? () => ref
                                      .read(workspaceProvider.notifier)
                                      .sendCommandToSelected(_selectedLens)
                                : null,
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                      const SizedBox(height: _spacingMd),
                      // const Divider(),
                      const SizedBox(height: _spacingMd),

                      // Focus
                      _buildLinearControl(
                        'Focus',
                        'VXX:LNSI4',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // Zoom
                      _buildLinearControl(
                        'Zoom',
                        'VXX:LNSI5',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      // const Divider(),
                      const SizedBox(height: _spacingMd),

                      // Test Patterns
                      _buildGroupHeader(context, 'Test Patterns'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasSelection
                                  ? () => ref
                                        .read(workspaceProvider.notifier)
                                        .sendCommandToSelected('OTS:00')
                                  : null,
                              child: const Text('OFF'),
                            ),
                          ),
                          const SizedBox(width: _spacingSm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasSelection
                                  ? () => ref
                                        .read(workspaceProvider.notifier)
                                        .sendCommandToSelected('OTS:01')
                                  : null,
                              child: const Text('White'),
                            ),
                          ),
                          const SizedBox(width: _spacingSm),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _spacingXs,
                                ),
                              ),
                              onPressed: hasSelection
                                  ? () => ref
                                        .read(workspaceProvider.notifier)
                                        .sendCommandToSelected('OTS:07')
                                  : null,
                              child: const FittedBox(
                                child: Text('Cross Hatch'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _spacingSm),

                      // Test pattern selector
                      Row(
                        children: [
                          Expanded(
                            child: DropdownMenu<String>(
                              requestFocusOnTap: false,
                              enableFilter: false,
                              expandedInsets: EdgeInsets.zero,
                              menuHeight: 300,
                              inputDecorationTheme: InputDecorationTheme(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              initialSelection: _selectedTestPattern,
                              dropdownMenuEntries: _testPatternOptions.entries
                                  .map(
                                    (e) => DropdownMenuEntry<String>(
                                      value: e.key,
                                      label: e.value,
                                      leadingIcon: _testPatternIcons.containsKey(e.key)
                                          ? SvgPicture.asset(
                                              _testPatternIcons[e.key]!,
                                              width: 20,
                                              height: 20,
                                            )
                                          : null,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (val) {
                                if (val != null) {
                                  setState(() => _selectedTestPattern = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: _spacingSm),
                          OutlinedButton(
                            onPressed: hasSelection
                                ? () => ref
                                      .read(workspaceProvider.notifier)
                                      .sendCommandToSelected(
                                        _selectedTestPattern,
                                      )
                                : null,
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                      const SizedBox(height: _spacingLg),
                    ],
                  ),

                  // ── System Tab ───────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(_spacingMd),
                    children: [
                      // System
                      _buildGroupHeader(context, 'System'),
                      _buildDropdownRow(
                        'Picture Mode',
                        _pictureModeOptions,
                        _selectedPictureMode,
                        (val) => setState(() => _selectedPictureMode = val),
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      _buildDropdownRow(
                        'Back Color',
                        _backColorOptions,
                        _selectedBackColor,
                        (val) => setState(() => _selectedBackColor = val),
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      _buildDropdownRow(
                        'Startup Logo',
                        _startupLogoOptions,
                        _selectedStartupLogo,
                        (val) => setState(() => _selectedStartupLogo = val),
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      _buildDropdownRow(
                        'Projection Method',
                        _projectionMethodOptions,
                        _selectedProjectionMethod,
                        (val) =>
                            setState(() => _selectedProjectionMethod = val),
                        enabled: hasSelection,
                        menuHeight: 300,
                      ),
                      const SizedBox(height: _spacingMd),
                      const SizedBox(height: _spacingSm),
                      // Shutter Settings
                      _buildGroupHeader(context, 'Shutter Settings'),
                      _buildDropdownRow(
                        'Fade In',
                        Map.fromEntries(
                          _shutterFadeOptions.entries.map(
                            (e) => MapEntry('VXX:SEFS1=${e.key}', e.value),
                          ),
                        ),
                        _selectedShutterFadeIn,
                        (val) => setState(() => _selectedShutterFadeIn = val),
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      _buildDropdownRow(
                        'Fade Out',
                        Map.fromEntries(
                          _shutterFadeOptions.entries.map(
                            (e) => MapEntry('VXX:SEFS2=${e.key}', e.value),
                          ),
                        ),
                        _selectedShutterFadeOut,
                        (val) => setState(() => _selectedShutterFadeOut = val),
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),
                      const SizedBox(height: _spacingSm),
                      // Quad Pixel Drive
                      _buildGroupHeader(context, 'Quad Pixel Drive'),
                      _buildCommandPair(
                        'On',
                        'VXX:QPDI1=+00001',
                        'Off',
                        'VXX:QPDI1=+00000',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingLg),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvgBtn extends StatelessWidget {
  final String assetPath;
  final VoidCallback? onPressed;

  static const double _size = 40;

  const _SvgBtn({required this.assetPath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        icon: SvgPicture.asset(
          assetPath,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            Theme.of(context).iconTheme.color ?? Colors.black,
            BlendMode.srcIn,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
