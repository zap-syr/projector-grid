import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/custom_command.dart';
import '../providers/custom_commands_provider.dart';
import '../providers/workspace_provider.dart';
import 'custom_command_dialog.dart';

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
  String _selectedTestPattern = 'OTS:01';
  bool _isSending = false;
  String _selectedPictureMode = 'VPM:STD';
  String _selectedBackColor = 'OBC:0';
  String _selectedStartupLogo = 'MLO:2';
  String _selectedProjectionMethod = 'OIL:0';
  String _selectedShutterFadeIn = 'VXX:SEFS1=0.0';
  String _selectedShutterFadeOut = 'VXX:SEFS2=0.0';
  List<String> _favorites = [];

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

  static const Map<String, String> _shutterFadeInOptions = {
    'VXX:SEFS1=0.0': '0.0s (OFF)',
    'VXX:SEFS1=0.5': '0.5s',
    'VXX:SEFS1=1.0': '1.0s',
    'VXX:SEFS1=1.5': '1.5s',
    'VXX:SEFS1=2.0': '2.0s',
    'VXX:SEFS1=2.5': '2.5s',
    'VXX:SEFS1=3.0': '3.0s',
    'VXX:SEFS1=3.5': '3.5s',
    'VXX:SEFS1=4.0': '4.0s',
    'VXX:SEFS1=5.0': '5.0s',
    'VXX:SEFS1=7.0': '7.0s',
    'VXX:SEFS1=10.0': '10.0s',
  };

  static const Map<String, String> _shutterFadeOutOptions = {
    'VXX:SEFS2=0.0': '0.0s (OFF)',
    'VXX:SEFS2=0.5': '0.5s',
    'VXX:SEFS2=1.0': '1.0s',
    'VXX:SEFS2=1.5': '1.5s',
    'VXX:SEFS2=2.0': '2.0s',
    'VXX:SEFS2=2.5': '2.5s',
    'VXX:SEFS2=3.0': '3.0s',
    'VXX:SEFS2=3.5': '3.5s',
    'VXX:SEFS2=4.0': '4.0s',
    'VXX:SEFS2=5.0': '5.0s',
    'VXX:SEFS2=7.0': '7.0s',
    'VXX:SEFS2=10.0': '10.0s',
  };

  static Widget? _testPatternIconBuilder(String key) {
    final path = _testPatternIcons[key];
    return path != null ? SvgPicture.asset(path, width: 18, height: 18) : null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ── Favorites persistence ─────────────────────────────────────────────────

  static String get _favoritesFilePath {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\ProjectorGrid\\test_pattern_favorites.json';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/ProjectorGrid/test_pattern_favorites.json';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/.config/ProjectorGrid/test_pattern_favorites.json';
    }
  }

  void _loadFavorites() {
    try {
      final file = File(_favoritesFilePath);
      if (!file.existsSync()) return;
      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      _favorites = list
          .cast<String>()
          .where(_testPatternOptions.containsKey)
          .take(4)
          .toList();
    } catch (_) {}
  }

  void _saveFavorites() {
    try {
      final file = File(_favoritesFilePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_favorites));
    } catch (_) {}
  }

  void _addFavorite() {
    if (_favorites.length >= 4) return;
    if (_favorites.contains(_selectedTestPattern)) return;
    setState(() => _favorites.add(_selectedTestPattern));
    _saveFavorites();
  }

  void _clearFavorite(int index) {
    if (index >= _favorites.length) return;
    setState(() => _favorites.removeAt(index));
    _saveFavorites();
  }

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
        length: 3,
        child: Column(
          children: [
            Container(
              height: 36,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const TabBar(
                tabs: [
                  Tab(text: 'General'),
                  Tab(text: 'System'),
                  Tab(text: 'Custom'),
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
                              assetPath:
                                  'assets/icons/lens_shift/up_normal.svg',
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
                                  assetPath:
                                      'assets/icons/lens_shift/left_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00201')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath:
                                      'assets/icons/lens_shift/left_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00101')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath:
                                      'assets/icons/lens_shift/left_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00001')
                                      : null,
                                ),
                                const SizedBox(width: _lensShiftCenterGap),
                                _SvgBtn(
                                  assetPath:
                                      'assets/icons/lens_shift/right_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00000')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath:
                                      'assets/icons/lens_shift/right_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00100')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath:
                                      'assets/icons/lens_shift/right_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00200')
                                      : null,
                                ),
                              ],
                            ),
                            _SvgBtn(
                              assetPath:
                                  'assets/icons/lens_shift/down_slow.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00001')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath:
                                  'assets/icons/lens_shift/down_normal.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00101')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath:
                                  'assets/icons/lens_shift/down_fast.svg',
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
                      _DropdownRow(
                        options: _lensOptions,
                        selectedValue: _selectedLens,
                        onChanged: (val) => setState(() => _selectedLens = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedLens)
                            : null,
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

                      // Full-width OFF button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: hasSelection
                              ? () => ref
                                    .read(workspaceProvider.notifier)
                                    .sendCommandToSelected('OTS:00')
                              : null,
                          child: const Text('OFF'),
                        ),
                      ),
                      const SizedBox(height: _spacingSm),

                      // Favorites row — always 4 slots
                      Row(
                        children: List.generate(4, (i) {
                          final code = i < _favorites.length
                              ? _favorites[i]
                              : null;
                          final canAdd =
                              code == null &&
                              !_favorites.contains(_selectedTestPattern);
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i > 0 ? _spacingXs : 0,
                              ),
                              child: _PatternSlot(
                                code: code,
                                iconPath: code != null
                                    ? _testPatternIcons[code]
                                    : null,
                                label: code != null
                                    ? _testPatternOptions[code]
                                    : null,
                                selectedLabel: canAdd
                                    ? (_testPatternOptions[_selectedTestPattern] ??
                                          _selectedTestPattern)
                                    : null,
                                onSend: code != null && hasSelection
                                    ? () => ref
                                          .read(workspaceProvider.notifier)
                                          .sendCommandToSelected(code)
                                    : null,
                                onAdd: canAdd ? _addFavorite : null,
                                onClear: code != null
                                    ? () => _clearFavorite(i)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: _spacingSm),

                      // Pattern dropdown + Send button
                      _DropdownRow(
                        options: _testPatternOptions,
                        selectedValue: _selectedTestPattern,
                        onChanged: (val) =>
                            setState(() => _selectedTestPattern = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedTestPattern)
                            : null,
                        menuHeight: 300,
                        iconBuilder: _testPatternIconBuilder,
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
                      _DropdownRow(
                        title: 'Picture Mode',
                        options: _pictureModeOptions,
                        selectedValue: _selectedPictureMode,
                        onChanged: (val) =>
                            setState(() => _selectedPictureMode = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedPictureMode)
                            : null,
                      ),
                      const SizedBox(height: _spacingMd),
                      _DropdownRow(
                        title: 'Back Color',
                        options: _backColorOptions,
                        selectedValue: _selectedBackColor,
                        onChanged: (val) =>
                            setState(() => _selectedBackColor = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedBackColor)
                            : null,
                      ),
                      const SizedBox(height: _spacingMd),
                      _DropdownRow(
                        title: 'Startup Logo',
                        options: _startupLogoOptions,
                        selectedValue: _selectedStartupLogo,
                        onChanged: (val) =>
                            setState(() => _selectedStartupLogo = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedStartupLogo)
                            : null,
                      ),
                      const SizedBox(height: _spacingMd),
                      _DropdownRow(
                        title: 'Projection Method',
                        options: _projectionMethodOptions,
                        selectedValue: _selectedProjectionMethod,
                        onChanged: (val) =>
                            setState(() => _selectedProjectionMethod = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(
                                    _selectedProjectionMethod,
                                  )
                            : null,
                        menuHeight: 300,
                      ),
                      const SizedBox(height: _spacingMd),
                      const SizedBox(height: _spacingSm),
                      // Shutter Settings
                      _buildGroupHeader(context, 'Shutter Settings'),
                      _DropdownRow(
                        title: 'Fade In',
                        options: _shutterFadeInOptions,
                        selectedValue: _selectedShutterFadeIn,
                        onChanged: (val) =>
                            setState(() => _selectedShutterFadeIn = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(_selectedShutterFadeIn)
                            : null,
                      ),
                      const SizedBox(height: _spacingMd),
                      _DropdownRow(
                        title: 'Fade Out',
                        options: _shutterFadeOutOptions,
                        selectedValue: _selectedShutterFadeOut,
                        onChanged: (val) =>
                            setState(() => _selectedShutterFadeOut = val),
                        onSet: hasSelection
                            ? () => ref
                                  .read(workspaceProvider.notifier)
                                  .sendCommandToSelected(
                                    _selectedShutterFadeOut,
                                  )
                            : null,
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

                  // ── Custom Tab ───────────────────────────────────────────
                  _CustomCommandsTab(hasSelection: hasSelection),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Commands Tab ───────────────────────────────────────────────────────

class _CustomCommandsTab extends ConsumerWidget {
  final bool hasSelection;

  const _CustomCommandsTab({required this.hasSelection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(customCommandsProvider);
    final notifier = ref.read(customCommandsProvider.notifier);

    return Column(
      children: [
        if (commands.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No custom commands yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              buildDefaultDragHandles: false,
              itemCount: commands.length,
              onReorder: notifier.reorder,
              itemBuilder: (context, index) {
                final cmd = commands[index];
                return _CustomCommandTile(
                  key: ValueKey(cmd.id),
                  index: index,
                  command: cmd,
                  hasSelection: hasSelection,
                  onRun: () => ref
                      .read(workspaceProvider.notifier)
                      .sendCommandToSelected(cmd.command),
                  onEdit: () => showDialog(
                    context: context,
                    builder: (_) => CustomCommandDialog(existing: cmd),
                  ),
                  onDelete: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Command'),
                      content: Text(
                        'Are you sure you want to delete "${cmd.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            notifier.remove(cmd.id);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Command'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const CustomCommandDialog(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomCommandTile extends StatelessWidget {
  final int index;
  final CustomCommand command;
  final bool hasSelection;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomCommandTile({
    super.key,
    required this.index,
    required this.command,
    required this.hasSelection,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Drag handle — functional via ReorderableDragStartListener
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          // Name + command
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  command.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  command.command,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Actions
          SizedBox(
            height: 28,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: hasSelection ? onRun : null,
              child: const Text('Run'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 16,
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            iconSize: 16,
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Reusable dropdown row: optional label + DropdownMenu + Set button.
class _DropdownRow extends StatelessWidget {
  final String? title;
  final Map<String, String> options;
  final String selectedValue;
  final void Function(String) onChanged;
  final VoidCallback? onSet;
  final double menuHeight;

  /// Optional icon per key — shown in the text field (leading) and each entry.
  final Widget? Function(String key)? iconBuilder;

  const _DropdownRow({
    this.title,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.onSet,
    this.menuHeight = 250,
    this.iconBuilder,
  });

  static const _borderRadius = BorderRadius.all(Radius.circular(100));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  iconButtonTheme: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                child: DropdownMenu<String>(
                  requestFocusOnTap: false,
                  enableFilter: false,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: menuHeight,
                  leadingIcon: iconBuilder != null
                      ? UnconstrainedBox(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 4),
                            child:
                                iconBuilder!(selectedValue) ??
                                const SizedBox.shrink(),
                          ),
                        )
                      : null,
                  trailingIcon: const UnconstrainedBox(
                    child: Icon(Icons.arrow_drop_down, size: 20),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    constraints: const BoxConstraints.tightFor(height: 32),
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: iconBuilder != null ? 0 : 10,
                      right: 10,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minHeight: 32,
                      minWidth: 32,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minHeight: 32,
                      minWidth: 32,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: _borderRadius,
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: _borderRadius,
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: _borderRadius,
                      borderSide: BorderSide(
                        color: colorScheme.primary,
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
                          leadingIcon: iconBuilder?.call(e.key),
                        ),
                      )
                      .toList(),
                  onSelected: (val) {
                    if (val != null) onChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(width: _ControlBarState._spacingSm),
            OutlinedButton(onPressed: onSet, child: const Text('Set')),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// One cell in the always-visible 4-slot favorites row.
///
/// Empty slot: click saves the currently selected test pattern.
/// Filled slot: normal click sends the command; Ctrl+click clears the slot.
class _PatternSlot extends StatelessWidget {
  final String? code;
  final String? iconPath;
  final String? label;

  /// Label of the currently selected pattern — used for the empty-slot tooltip.
  final String? selectedLabel;
  final VoidCallback? onSend;
  final VoidCallback? onAdd;
  final VoidCallback? onClear;

  const _PatternSlot({
    this.code,
    this.iconPath,
    this.label,
    this.selectedLabel,
    this.onSend,
    this.onAdd,
    this.onClear,
  });

  static final _slotStyle = OutlinedButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    if (code == null) {
      // Empty slot — click to save the current dropdown selection.
      final tip = selectedLabel != null ? 'Save "$selectedLabel"' : '';
      final button = OutlinedButton(
        style: _slotStyle,
        onPressed: onAdd,
        child: Icon(
          Icons.add,
          size: 14,
          color: onAdd != null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      );
      return tip.isEmpty ? button : _CustomTooltip(message: tip, child: button);
    }
    // Filled slot — normal click sends, Ctrl+click clears.
    return _CustomTooltip(
      message: '${label ?? code!}\nCtrl+click to remove',
      child: OutlinedButton(
        style: _slotStyle,
        onPressed: () {
          if (HardwareKeyboard.instance.isControlPressed) {
            onClear?.call();
          } else {
            onSend?.call();
          }
        },
        child: iconPath != null
            ? SvgPicture.asset(iconPath!, width: 18, height: 18)
            : FittedBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label ?? code!,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A tooltip that is transparent to the mouse pointer via [IgnorePointer].
///
/// Visibility is driven solely by the button's [MouseRegion], so the tooltip
/// never blocks hover/click events on elements behind it, and it disappears
/// the moment the cursor leaves the button — even if it physically moves over
/// the tooltip overlay.
class _CustomTooltip extends StatefulWidget {
  final String message;
  final Widget child;

  const _CustomTooltip({required this.message, required this.child});

  @override
  State<_CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<_CustomTooltip> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null || !mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(overlayContext).colorScheme;
        final lines = widget.message.split('\n');
        return Positioned(
          // Anchor at horizontal center of the button, 6px above its top edge.
          left: position.dx + size.width / 2,
          top: position.dy - 6,
          child: FractionalTranslation(
            // Shift left by 50% of own width (centers it) and up by 100% of own
            // height (places it fully above the button).
            translation: const Offset(-0.5, -1.0),
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (int i = 0; i < lines.length; i++)
                        Text(
                          lines[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontSize: 12,
                            fontStyle: i > 0
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
