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

  // ── Data ──────────────────────────────────────────────────────────────────
  static const Map<String, String> _lensOptions = {
    'VXX:LNEI1=+00001': 'ET-D75LE6',
    'VXX:LNEI1=+00002': 'ET-D75LE10',
    'VXX:LNEI1=+00003': 'ET-D75LE20',
    'VXX:LNEI1=+00004': 'ET-D75LE30',
    'VXX:LNEI1=+00005': 'ET-D75LE40',
    'VXX:LNEI1=+00006': 'ET-D75LE8',
    'VXX:LNEI1=+00007': 'ET-D75LE95',
    'VXX:LNEI1=+00008': 'ET-D75LE90',
    'VXX:LNEI1=+00009': 'ET-D75LE50',
  };

  static const Map<String, String> _testPatternOptions = {
    'OTS:01': 'White',
    'OTS:02': 'Black',
    'OTS:05': 'Window',
    'OTS:06': 'Reversed Window',
    'OTS:07': 'Cross Hatch',
    'OTS:08': 'Color Bar V',
    'OTS:32': 'Focus (Level 0%)',
    'OTS:33': 'Focus (Level 50%)',
    'OTS:34': 'Focus (Level 100%)',
    'OTS:51': 'Color Bar Side',
    'OTS:59': '16:9/4:3',
    'OTS:70': 'Focus Red',
    'OTS:71': 'Focus Green',
    'OTS:72': 'Focus Blue',
    'OTS:73': 'Focus Cyan',
    'OTS:74': 'Focus Magenta',
    'OTS:75': 'Focus Yellow',
    'OTS:78': 'Focus',
    'OTS:87': 'Circle',
  };

  static const List<(String, String)> _inputOptions = [
    ('DVI', 'IIS:DVI'),
    ('HDMI', 'IIS:HD1'),
    ('SDI', 'IIS:SD1'),
    ('DLINK', 'IIS:DL1'),
  ];

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

  /// Builds a labelled section title.
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _spacingSm),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
        _buildSectionHeader(context, title),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: _spacingXs,
          children: [
            _SvgBtn(
              assetPath: 'assets/icons/left_fast.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00201')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/left_normal.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00101')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/left_slow.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00001')
                  : null,
            ),
            const Spacer(),
            _SvgBtn(
              assetPath: 'assets/icons/right_slow.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00000')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/right_normal.svg',
              onPressed: enabled
                  ? () => _throttledSend('$cmdBase=+00100')
                  : null,
            ),
            _SvgBtn(
              assetPath: 'assets/icons/right_fast.svg',
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
        length: 2,
        child: Column(
          children: [
            Container(
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
                      _buildSectionHeader(context, 'Power'),
                      _buildCommandPair(
                        'On',
                        'PON',
                        'Standby',
                        'POF',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // Shutter
                      _buildSectionHeader(context, 'Shutter'),
                      _buildCommandPair(
                        'Open',
                        'OSH:0',
                        'Close',
                        'OSH:1',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // OSD
                      _buildSectionHeader(context, 'OSD'),
                      _buildCommandPair(
                        'On',
                        'OOS:1',
                        'Off',
                        'OOS:0',
                        enabled: hasSelection,
                      ),
                      const SizedBox(height: _spacingMd),

                      // Inputs
                      _buildSectionHeader(context, 'Inputs'),
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
                      const Divider(),
                      const SizedBox(height: _spacingMd),

                      // Lens Shift D-Pad
                      _buildSectionHeader(context, 'Lens Shift'),
                      Center(
                        child: Column(
                          children: [
                            _SvgBtn(
                              assetPath: 'assets/icons/up_fast.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00200')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/up_normal.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00100')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/up_slow.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00000')
                                  : null,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SvgBtn(
                                  assetPath: 'assets/icons/left_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00201')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/left_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00101')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/left_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00001')
                                      : null,
                                ),
                                const SizedBox(width: _lensShiftCenterGap),
                                _SvgBtn(
                                  assetPath: 'assets/icons/right_slow.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00000')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/right_normal.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00100')
                                      : null,
                                ),
                                const SizedBox(width: _spacingXs),
                                _SvgBtn(
                                  assetPath: 'assets/icons/right_fast.svg',
                                  onPressed: hasSelection
                                      ? () => _throttledSend('VXX:LNSI2=+00200')
                                      : null,
                                ),
                              ],
                            ),
                            _SvgBtn(
                              assetPath: 'assets/icons/down_slow.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00001')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/down_normal.svg',
                              onPressed: hasSelection
                                  ? () => _throttledSend('VXX:LNSI3=+00101')
                                  : null,
                            ),
                            const SizedBox(height: _spacingXs),
                            _SvgBtn(
                              assetPath: 'assets/icons/down_fast.svg',
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
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
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
                      const Divider(),
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
                      const Divider(),
                      const SizedBox(height: _spacingMd),

                      // Test Patterns
                      _buildSectionHeader(context, 'Test Patterns'),
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
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                ),
                              ),
                              initialSelection: _selectedTestPattern,
                              dropdownMenuEntries: _testPatternOptions.entries
                                  .map(
                                    (e) => DropdownMenuEntry<String>(
                                      value: e.key,
                                      label: e.value,
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
                  const Center(
                    child: Text('System configuration not yet implemented.'),
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

  const _SvgBtn({
    required this.assetPath,
    required this.onPressed,
  });

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
