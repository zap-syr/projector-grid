import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/web_pins.dart';
import '../providers/app_settings_provider.dart';
import '../providers/osc_provider.dart';
import '../providers/web_server_provider.dart';
import '../providers/workspace_provider.dart';
import 'dialog_title_bar.dart';
import 'settings_rows.dart';

enum _Section {
  general('General', Icons.tune),
  osc('OSC', Icons.sensors),
  web('Web Access', Icons.language);

  const _Section(this.label, this.icon);

  final String label;
  final IconData icon;
}

class PreferencesDialog extends ConsumerStatefulWidget {
  const PreferencesDialog({super.key});

  @override
  ConsumerState<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends ConsumerState<PreferencesDialog> {
  var _section = _Section.general;

  // General
  late final TextEditingController _intervalController;
  late ThemeMode _selectedTheme;

  // OSC
  late bool _oscActive;
  late String _selectedNetworkDevice;
  late final TextEditingController _oscReceivePortController;
  late final TextEditingController _oscSendIpController;
  late final TextEditingController _oscSendPortController;

  // Web Access
  late bool _webEnabled;
  late final TextEditingController _webPortController;
  final _webPinController = TextEditingController();
  String? _webPinError;
  late bool _webAllowControl;
  final _webOperatorPinController = TextEditingController();
  String? _webOperatorPinError;
  String? _webUrlIp;

  List<NetworkInterface>? _networkInterfaces;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _intervalController = TextEditingController(
      text: settings.pollingIntervalSeconds.toString(),
    );
    _selectedTheme = settings.themeMode;
    _oscActive = settings.oscActive;
    _selectedNetworkDevice = settings.oscNetworkDevice;
    _oscReceivePortController = TextEditingController(
      text: settings.oscReceivePort.toString(),
    );
    _oscSendIpController = TextEditingController(text: settings.oscSendIp);
    _oscSendPortController = TextEditingController(
      text: settings.oscSendPort.toString(),
    );
    _webEnabled = settings.webEnabled;
    _webAllowControl = settings.webAllowControl;
    _webPortController = TextEditingController(
      text: settings.webPort.toString(),
    );
    _loadNetworkInterfaces();
  }

  Future<void> _loadNetworkInterfaces() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    if (mounted) {
      setState(() {
        _networkInterfaces = interfaces;
        _webUrlIp = _localIps.firstOrNull;
      });
    }
  }

  List<String> get _localIps => [
    for (final iface in _networkInterfaces ?? const <NetworkInterface>[])
      for (final addr in iface.addresses) addr.address,
  ];

  String _webUrl(String ip) => 'http://$ip:${_webPortController.text}';

  /// Footer summary of a rejected Save; names the field because the bare
  /// messages ("Required") don't say which PIN they're about.
  String? get _webError => _webPinError != null
      ? 'Viewer PIN: $_webPinError'
      : _webOperatorPinError != null
      ? 'Operator PIN: $_webOperatorPinError'
      : null;

  @override
  void dispose() {
    _intervalController.dispose();
    _oscReceivePortController.dispose();
    _oscSendIpController.dispose();
    _oscSendPortController.dispose();
    _webPortController.dispose();
    _webPinController.dispose();
    _webOperatorPinController.dispose();
    super.dispose();
  }

  void _save() {
    // Captured before any OSC field writes below, so we can tell whether the
    // connection parameters actually changed (needed to decide whether a
    // live socket needs rebinding, not just whether OSC was toggled).
    final oldSettings = ref.read(appSettingsProvider);

    // Checked before anything is written, so a rejected PIN saves nothing.
    final pin = _webPinController.text;
    final operatorPin = _webOperatorPinController.text;
    final pinErrors = validateWebPins(
      viewerPin: pin,
      operatorPin: operatorPin,
      enabled: _webEnabled,
      allowControl: _webAllowControl,
      viewerHash: oldSettings.webViewerPinHash,
      operatorHash: oldSettings.webOperatorPinHash,
    );
    if (pinErrors.viewer != null || pinErrors.operator != null) {
      setState(() {
        _webPinError = pinErrors.viewer;
        _webOperatorPinError = pinErrors.operator;
        _section = _Section.web;
      });
      return;
    }

    // General
    final parsed = int.tryParse(_intervalController.text);
    if (parsed != null) {
      final interval = parsed.clamp(
        AppSettings.minPollingIntervalSeconds,
        AppSettings.maxPollingIntervalSeconds,
      );
      // Reflect the clamped value back so the field never shows a rejected entry.
      _intervalController.text = interval.toString();
      ref.read(appSettingsProvider.notifier).setPollingInterval(interval);
      ref.read(workspaceProvider.notifier).setPollingInterval(interval);
    }
    ref.read(appSettingsProvider.notifier).setThemeMode(_selectedTheme);

    // OSC settings
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    settingsNotifier.setOscNetworkDevice(_selectedNetworkDevice);
    final recvPort = int.tryParse(_oscReceivePortController.text);
    if (recvPort != null && recvPort > 0) {
      settingsNotifier.setOscReceivePort(recvPort);
    }
    final sendIp = _oscSendIpController.text.trim();
    settingsNotifier.setOscSendIp(sendIp);
    final sendPort = int.tryParse(_oscSendPortController.text);
    if (sendPort != null && sendPort > 0) {
      settingsNotifier.setOscSendPort(sendPort);
    }

    // OSC active toggle — compare against persisted setting, not auto-dispose provider state
    final oscNotifier = ref.read(oscProvider.notifier);
    final wasActive = oldSettings.oscActive;
    final connectionParamsChanged =
        _selectedNetworkDevice != oldSettings.oscNetworkDevice ||
        (recvPort != null &&
            recvPort > 0 &&
            recvPort != oldSettings.oscReceivePort) ||
        sendIp != oldSettings.oscSendIp ||
        (sendPort != null &&
            sendPort > 0 &&
            sendPort != oldSettings.oscSendPort);

    if (_oscActive && !wasActive) {
      oscNotifier.start();
    } else if (!_oscActive && wasActive) {
      oscNotifier.stop();
    } else if (_oscActive && wasActive && connectionParamsChanged) {
      // OSC stays enabled but the receive port/device or send IP/port
      // changed — the already-bound socket won't pick that up on its own,
      // so rebind it with the new settings.
      oscNotifier.restart();
    }

    // Web Access — port and PIN are saved first because start() reads them.
    final webPort = int.tryParse(_webPortController.text);
    final webPortValid = webPort != null && webPort > 0 && webPort <= 65535;
    if (webPortValid) settingsNotifier.setWebPort(webPort);
    final webNotifier = ref.read(webServerProvider.notifier);
    if (pin.isNotEmpty) webNotifier.setViewerPin(pin);
    if (operatorPin.isNotEmpty) webNotifier.setOperatorPin(operatorPin);
    if (_webAllowControl != oldSettings.webAllowControl) {
      webNotifier.setAllowControl(_webAllowControl);
    }
    if (_webEnabled && !oldSettings.webEnabled) {
      webNotifier.start();
    } else if (!_webEnabled && oldSettings.webEnabled) {
      webNotifier.stop();
    } else if (_webEnabled && webPortValid && webPort != oldSettings.webPort) {
      webNotifier.restart();
    }

    Navigator.of(context).pop();
  }

  InputDecoration _decoration({
    String? hintText,
    String? suffixText,
    bool hasError = false,
  }) {
    final error = Theme.of(context).colorScheme.error;
    // The message itself sits under the row label (SettingsRow.error);
    // errorText here would squeeze it into the narrow field.
    return InputDecoration(
      border: const OutlineInputBorder(),
      enabledBorder: hasError
          ? OutlineInputBorder(borderSide: BorderSide(color: error))
          : null,
      focusedBorder: hasError
          ? OutlineInputBorder(borderSide: BorderSide(color: error, width: 2))
          : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintText: hintText,
      suffixText: suffixText,
    );
  }

  Widget _numberField(TextEditingController controller, {String? suffix}) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _decoration(suffixText: suffix),
      );

  Widget _pinField({
    required TextEditingController controller,
    required String? error,
    required VoidCallback clearError,
    required bool isSet,
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(8),
    ],
    onChanged: (_) {
      if (error != null) setState(clearError);
    },
    decoration: _decoration(
      hintText: isSet ? 'Unchanged' : 'Not set',
      hasError: error != null,
    ),
  );

  Widget _addressDropdown({
    required Key key,
    required String? initialSelection,
    required List<DropdownMenuEntry<String>> entries,
    required ValueChanged<String?> onSelected,
  }) => DropdownMenu<String>(
    key: key,
    initialSelection: initialSelection,
    expandedInsets: EdgeInsets.zero,
    requestFocusOnTap: false,
    enableFilter: false,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    dropdownMenuEntries: entries,
    onSelected: onSelected,
  );

  List<DropdownMenuEntry<String>> get _interfaceEntries => [
    for (final iface in _networkInterfaces ?? const <NetworkInterface>[])
      for (final addr in iface.addresses)
        DropdownMenuEntry(
          value: addr.address,
          label: '${iface.name}  ${addr.address}',
        ),
  ];

  Widget _buildGeneral() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 20,
    children: [
      SettingsGroup(
        title: 'Monitoring',
        children: [
          SettingsRow(
            label: 'Update interval',
            hint:
                '${AppSettings.minPollingIntervalSeconds}–${AppSettings.maxPollingIntervalSeconds} s',
            controlWidth: 120,
            control: _numberField(_intervalController, suffix: 's'),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Appearance',
        children: [
          SettingsRow(
            label: 'Theme',
            control: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_selectedTheme},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _selectedTheme = selection.first);
              },
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildOsc(bool running, int listeningPort) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 20,
    children: [
      _ServiceCard(
        title: 'OSC server',
        running: running,
        status: running ? 'Listening on UDP $listeningPort' : 'Stopped',
        value: _oscActive,
        onChanged: (value) => setState(() => _oscActive = value),
      ),
      SettingsGroup(
        title: 'Receive',
        dimmed: !_oscActive,
        children: [
          SettingsRow(
            label: 'Network interface',
            control: _addressDropdown(
              key: ValueKey(_networkInterfaces == null),
              initialSelection: _selectedNetworkDevice,
              entries: [
                const DropdownMenuEntry(value: '', label: 'Any (0.0.0.0)'),
                ..._interfaceEntries,
              ],
              onSelected: (value) {
                if (value != null) {
                  setState(() => _selectedNetworkDevice = value);
                }
              },
            ),
          ),
          SettingsRow(
            label: 'Port',
            hint: 'UDP',
            controlWidth: 120,
            control: _numberField(_oscReceivePortController),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Status feedback',
        dimmed: !_oscActive,
        children: [
          SettingsRow(
            label: 'Target IP',
            control: TextField(
              controller: _oscSendIpController,
              decoration: _decoration(),
            ),
          ),
          SettingsRow(
            label: 'Target port',
            controlWidth: 120,
            control: _numberField(_oscSendPortController),
          ),
        ],
      ),
    ],
  );

  Widget _buildWeb(bool running, AppSettings settings) {
    final theme = Theme.of(context);
    final ip = _webUrlIp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        _ServiceCard(
          title: 'Web server',
          running: running,
          status: running ? 'Running' : 'Stopped',
          value: _webEnabled,
          onChanged: (value) => setState(() => _webEnabled = value),
        ),
        SettingsGroup(
          title: 'Server',
          dimmed: !_webEnabled,
          children: [
            SettingsRow(
              label: 'Address',
              control: _addressDropdown(
                // Rebuilt once the interface list arrives so the first
                // address shows as selected.
                key: ValueKey(_networkInterfaces == null),
                initialSelection: ip,
                entries: _interfaceEntries,
                onSelected: (value) => setState(() => _webUrlIp = value),
              ),
            ),
            SettingsRow(
              label: 'Port',
              hint: 'HTTP',
              controlWidth: 120,
              control: TextField(
                controller: _webPortController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: _decoration(),
              ),
            ),
            if (ip != null)
              SettingsRow(
                label: 'Link',
                controlWidth: 300,
                control: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          _webUrl(ip),
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _webUrl(ip))),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: 'Access',
          dimmed: !_webEnabled,
          children: [
            SettingsRow(
              label: 'Viewer PIN',
              hint: '4–8 digits',
              error: _webPinError,
              controlWidth: 120,
              control: _pinField(
                controller: _webPinController,
                error: _webPinError,
                clearError: () => _webPinError = null,
                isSet: settings.webViewerPinHash != null,
              ),
            ),
            SettingsRow(
              label: 'Allow control',
              controlWidth: 120,
              control: Switch(
                value: _webAllowControl,
                onChanged: (value) => setState(() {
                  _webAllowControl = value;
                  _webOperatorPinError = null;
                }),
              ),
            ),
            SettingsRow(
              label: 'Operator PIN',
              hint: '4–8 digits',
              error: _webOperatorPinError,
              indented: true,
              enabled: _webAllowControl,
              controlWidth: 120,
              control: _pinField(
                controller: _webOperatorPinController,
                error: _webOperatorPinError,
                clearError: () => _webOperatorPinError = null,
                isSet: settings.webOperatorPinHash != null,
                enabled: _webAllowControl,
              ),
            ),
          ],
        ),
        const _PlainHttpNote(),
        SettingsGroup(
          title: 'Sessions',
          children: [
            SettingsRow(
              label: 'Signed-in clients',
              hint: 'Forces every browser to enter the PIN again',
              control: OutlinedButton(
                onPressed: running
                    ? ref.read(webServerProvider.notifier).signOutAll
                    : null,
                child: const Text('Sign out all'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final oscRunning = ref.watch(oscProvider);
    final webRunning = ref.watch(webServerProvider);
    final webError = _webError;

    Color? dotFor(_Section section) => switch (section) {
      _Section.general => null,
      _Section.osc => oscRunning ? Colors.green : theme.colorScheme.outline,
      _Section.web =>
        webError != null
            ? theme.colorScheme.error
            : webRunning
            ? Colors.green
            : theme.colorScheme.outline,
    };

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(title: 'Preferences'),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 196,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      border: Border(
                        right: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Column(
                      spacing: 2,
                      children: [
                        for (final section in _Section.values)
                          _NavItem(
                            label: section.label,
                            icon: section.icon,
                            selected: section == _section,
                            dotColor: dotFor(section),
                            onTap: () => setState(() => _section = section),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      // Each section opens scrolled to the top.
                      key: ValueKey(_section),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          Text(
                            _section.label,
                            style: theme.textTheme.titleLarge,
                          ),
                          switch (_section) {
                            _Section.general => _buildGeneral(),
                            _Section.osc => _buildOsc(
                              oscRunning,
                              settings.oscReceivePort,
                            ),
                            _Section.web => _buildWeb(webRunning, settings),
                          },
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      webError ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.dotColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// Live state of the section's service; null for sections without one.
  final Color? dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer
          : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, size: 20, color: foreground),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (dotColor case final color?) StatusDot(color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Master switch of a background service plus its actual state, which can
/// differ from the switch until Save applies it.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.running,
    required this.status,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool running;
  final String status;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  spacing: 6,
                  children: [
                    StatusDot(
                      color: running ? Colors.green : theme.colorScheme.outline,
                    ),
                    Text(
                      status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PlainHttpNote extends StatelessWidget {
  const _PlainHttpNote();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isLight
        ? const Color(0xFFFFF4E0)
        : const Color(0xFF3A2C12);
    final foreground = isLight
        ? const Color(0xFF7A4B00)
        : const Color(0xFFFFD08A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: foreground),
          Expanded(
            child: Text(
              'Plain HTTP — PINs are sent unencrypted. '
              'Use on a trusted network only.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
