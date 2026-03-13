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
  String _selectedLens = 'VXX:LNEI1=+00001';
  String _selectedTestPattern = 'OTS:87';

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(workspaceProvider.notifier);

    return Container(
      width: 320,
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
                  // General Tab
                  ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildSectionHeader(context, 'Power'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('PON'),
                              child: const Text('On'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('POF'),
                              child: const Text('Standby'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Shutter'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OSH:0'),
                              child: const Text('Open'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OSH:1'),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'OSD'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OOS:1'),
                              child: const Text('On'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OOS:0'),
                              child: const Text('Off'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Inputs'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              onPressed: () =>
                                  notifier.sendCommandToSelected('IIS:DVI'),
                              child: const FittedBox(child: Text('DVI')),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              onPressed: () =>
                                  notifier.sendCommandToSelected('IIS:HD1'),
                              child: const FittedBox(child: Text('HDMI')),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              onPressed: () =>
                                  notifier.sendCommandToSelected('IIS:SD1'),
                              child: const FittedBox(child: Text('SDI')),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              onPressed: () =>
                                  notifier.sendCommandToSelected('IIS:DL1'),
                              child: const FittedBox(child: Text('DLINK')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Lens Shift'),
                      // D-Pad for Lens Shift
                      Center(
                        child: Column(
                          children: [
                            _SvgBtn(
                              'assets/icons/up_fast.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00200',
                              ),
                            ),
                            const SizedBox(height: 2),
                            _SvgBtn(
                              'assets/icons/up_normal.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00100',
                              ),
                            ),
                            const SizedBox(height: 2),
                            _SvgBtn(
                              'assets/icons/up_slow.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00000',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SvgBtn(
                                  'assets/icons/left_fast.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00201',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _SvgBtn(
                                  'assets/icons/left_normal.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00101',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _SvgBtn(
                                  'assets/icons/left_slow.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00001',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _SvgBtn(
                                  'assets/icons/right_slow.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00000',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _SvgBtn(
                                  'assets/icons/right_normal.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00100',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _SvgBtn(
                                  'assets/icons/right_fast.svg',
                                  () => notifier.sendCommandToSelected(
                                    'VXX:LNSI2=+00200',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _SvgBtn(
                              'assets/icons/down_slow.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00001',
                              ),
                            ),
                            const SizedBox(height: 2),
                            _SvgBtn(
                              'assets/icons/down_normal.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00101',
                              ),
                            ),
                            const SizedBox(height: 2),
                            _SvgBtn(
                              'assets/icons/down_fast.svg',
                              () => notifier.sendCommandToSelected(
                                'VXX:LNSI3=+00201',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lens Assignment
                      Row(
                        children: [
                          const Text('Lens:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              menuMaxHeight: 250,
                              // ignore: deprecated_member_use
                              value: _selectedLens,
                              items: const [
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00001',
                                  child: Text(
                                    'ET-D75LE6',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00002',
                                  child: Text(
                                    'ET-D75LE10',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00003',
                                  child: Text(
                                    'ET-D75LE20',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00004',
                                  child: Text(
                                    'ET-D75LE30',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00005',
                                  child: Text(
                                    'ET-D75LE40',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00006',
                                  child: Text(
                                    'ET-D75LE8',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00007',
                                  child: Text(
                                    'ET-D75LE95',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00008',
                                  child: Text(
                                    'ET-D75LE90',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'VXX:LNEI1=+00009',
                                  child: Text(
                                    'ET-D75LE50',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedLens = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => notifier.sendCommandToSelected(
                                'VXX:LNSI1=+00001',
                              ),
                              child: const FittedBox(child: Text('Home Pos.')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => notifier.sendCommandToSelected(
                                'VXX:LNSI0=+00001',
                              ),
                              child: const FittedBox(
                                child: Text('Calibration'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              notifier.sendCommandToSelected(_selectedLens),
                          child: const Text('Set Lens'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Focus'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SvgBtn(
                            'assets/icons/left_fast.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00201',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/left_normal.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00101',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/left_slow.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00001',
                            ),
                          ),
                          const Spacer(),
                          _SvgBtn(
                            'assets/icons/right_slow.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00000',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/right_normal.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00100',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/right_fast.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI4=+00200',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Zoom'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SvgBtn(
                            'assets/icons/left_fast.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00201',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/left_normal.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00101',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/left_slow.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00001',
                            ),
                          ),
                          const Spacer(),
                          _SvgBtn(
                            'assets/icons/right_slow.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00000',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/right_normal.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00100',
                            ),
                          ),
                          _SvgBtn(
                            'assets/icons/right_fast.svg',
                            () => notifier.sendCommandToSelected(
                              'VXX:LNSI5=+00200',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context, 'Test Patterns'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OTS:00'),
                              child: const Text('OFF'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OTS:01'),
                              child: const Text('White'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              onPressed: () =>
                                  notifier.sendCommandToSelected('OTS:07'),
                              child: const FittedBox(
                                child: Text('Cross Hatch'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              menuMaxHeight: 300,
                              // ignore: deprecated_member_use
                              value: _selectedTestPattern,
                              items: const [
                                DropdownMenuItem(
                                  value: 'OTS:00',
                                  child: Text(
                                    'Off',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:01',
                                  child: Text(
                                    'White',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:02',
                                  child: Text(
                                    'Black',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:05',
                                  child: Text(
                                    'Window',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:06',
                                  child: Text(
                                    'Reversed Window',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:07',
                                  child: Text(
                                    'Cross Hatch',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:08',
                                  child: Text(
                                    'Color Bar V',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:32',
                                  child: Text(
                                    'Focus (Level 0%)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:33',
                                  child: Text(
                                    'Focus (Level 50%)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:34',
                                  child: Text(
                                    'Focus (Level 100%)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:51',
                                  child: Text(
                                    'Color Bar Side',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:59',
                                  child: Text(
                                    '16:9/4:3',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:70',
                                  child: Text(
                                    'Focus Red',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:71',
                                  child: Text(
                                    'Focus Green',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:72',
                                  child: Text(
                                    'Focus Blue',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:73',
                                  child: Text(
                                    'Focus Cyan',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:74',
                                  child: Text(
                                    'Focus Magenta',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:75',
                                  child: Text(
                                    'Focus Yellow',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:78',
                                  child: Text(
                                    'Focus',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:80',
                                  child: Text(
                                    '3D-1',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:81',
                                  child: Text(
                                    '3D-2',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:82',
                                  child: Text(
                                    '3D-3',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:83',
                                  child: Text(
                                    '3D-4',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'OTS:87',
                                  child: Text(
                                    'Circle',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedTestPattern = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              notifier.sendCommandToSelected(
                                _selectedTestPattern,
                              );
                            },
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                  // System Tab
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SvgBtn extends StatelessWidget {
  final String assetPath;
  final VoidCallback onPressed;

  const _SvgBtn(this.assetPath, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
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
