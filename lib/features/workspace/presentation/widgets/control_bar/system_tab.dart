import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'control_bar_parts.dart';
import 'control_bar_scroll.dart';

/// Display labels only: the keys are the NTCONTROL commands sent as they
/// are.
const Map<String, String> kPictureModeOptions = {
  'VPM:DYN': 'Dynamic',
  'VPM:NAT': 'Natural',
  'VPM:STD': 'Standard',
  'VPM:CIN': 'Cinema',
  'VPM:GRA': 'Graphic',
  'VPM:DIC': 'DICOM sim.',
  'VPM:USR': 'User',
};

const Map<String, String> kBackColorOptions = {
  'OBC:0': 'Blue',
  'OBC:1': 'Black',
  'OBC:2': 'User logo',
  'OBC:3': 'Default logo',
};

const Map<String, String> kStartupLogoOptions = {
  'MLO:0': 'Off',
  'MLO:1': 'User logo',
  'MLO:2': 'Default logo',
};

const Map<String, String> kProjectionMethodOptions = {
  'OIL:0': 'Front, desk',
  'OIL:1': 'Rear, desk',
  'OIL:2': 'Front, ceiling',
  'OIL:3': 'Rear, ceiling',
  'OIL:4': 'Front, auto',
  'OIL:5': 'Rear, auto',
};

const _fadeSeconds = [
  '0.0',
  '0.5',
  '1.0',
  '1.5',
  '2.0',
  '2.5',
  '3.0',
  '3.5',
  '4.0',
  '5.0',
  '7.0',
  '10.0',
];

/// `VXX:SEFS1=1.5` → `1.5 s`; zero reads `Off`.
Map<String, String> shutterFadeOptions(int which) => {
  for (final s in _fadeSeconds)
    'VXX:SEFS$which=$s': s == '0.0' ? 'Off' : '$s s',
};

final kShutterFadeInOptions = shutterFadeOptions(1);
final kShutterFadeOutOptions = shutterFadeOptions(2);

class SystemTab extends ConsumerStatefulWidget {
  const SystemTab({super.key});

  @override
  ConsumerState<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends ConsumerState<SystemTab> {
  static final _pictureModeItems = dropdownItems(kPictureModeOptions);
  static final _backColorItems = dropdownItems(kBackColorOptions);
  static final _startupLogoItems = dropdownItems(kStartupLogoOptions);
  static final _projectionItems = dropdownItems(kProjectionMethodOptions);
  static final _fadeInItems = dropdownItems(kShutterFadeInOptions);
  static final _fadeOutItems = dropdownItems(kShutterFadeOutOptions);

  String _pictureMode = 'VPM:STD';
  String _backColor = 'OBC:0';
  String _startupLogo = 'MLO:2';
  String _projection = 'OIL:0';
  String _fadeIn = 'VXX:SEFS1=0.0';
  String _fadeOut = 'VXX:SEFS2=0.0';

  @override
  Widget build(BuildContext context) {
    VoidCallback send(String cmd) =>
        () => sendToSelected(ref, cmd);
    const gap = SizedBox(height: ControlBarMetrics.settingGap);
    return ControlBarScroll(
      children: [
        ControlBarCard(
          icon: Icons.image_outlined,
          title: 'Picture',
          child: DropdownSendRow<String>(
            label: 'Picture mode',
            items: _pictureModeItems,
            value: _pictureMode,
            onChanged: (v) => setState(() => _pictureMode = v),
            onSend: send(_pictureMode),
          ),
        ),
        ControlBarCard(
          icon: Icons.desktop_windows_outlined,
          title: 'Display',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownSendRow<String>(
                label: 'Back color',
                items: _backColorItems,
                value: _backColor,
                onChanged: (v) => setState(() => _backColor = v),
                onSend: send(_backColor),
              ),
              gap,
              DropdownSendRow<String>(
                label: 'Startup logo',
                items: _startupLogoItems,
                value: _startupLogo,
                onChanged: (v) => setState(() => _startupLogo = v),
                onSend: send(_startupLogo),
              ),
              gap,
              DropdownSendRow<String>(
                label: 'Projection method',
                items: _projectionItems,
                value: _projection,
                menuHeight: 300,
                onChanged: (v) => setState(() => _projection = v),
                onSend: send(_projection),
              ),
            ],
          ),
        ),
        ControlBarCard(
          icon: Icons.visibility_off_outlined,
          title: 'Shutter fade',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownSendRow<String>(
                label: 'Fade in',
                items: _fadeInItems,
                value: _fadeIn,
                onChanged: (v) => setState(() => _fadeIn = v),
                onSend: send(_fadeIn),
              ),
              gap,
              DropdownSendRow<String>(
                label: 'Fade out',
                items: _fadeOutItems,
                value: _fadeOut,
                onChanged: (v) => setState(() => _fadeOut = v),
                onSend: send(_fadeOut),
              ),
            ],
          ),
        ),
        ControlBarCard(
          padding: const EdgeInsets.symmetric(
            horizontal: ControlBarMetrics.cardPadding,
          ),
          child: CommandRow(
            label: 'Quad Pixel Drive',
            labelWidth: 128,
            first: CommandButton(
              label: 'On',
              onPressed: send('VXX:QPDI1=+00001'),
            ),
            second: CommandButton(
              label: 'Off',
              onPressed: send('VXX:QPDI1=+00000'),
            ),
          ),
        ),
      ],
    );
  }
}
