import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/alert_rule.dart';
import '../../domain/web_pins.dart';
import '../providers/alert_delivery_providers.dart';
import '../providers/app_settings_provider.dart';
import '../providers/osc_provider.dart';
import '../providers/web_server_provider.dart';
import '../providers/workspace_provider.dart';
import 'dialog_title_bar.dart';
import 'settings_dropdown.dart';
import 'settings_rows.dart';
import 'settings_value_field.dart';

enum _Section {
  general('General', Icons.tune),
  alerts('Alerts', Icons.notifications_outlined),
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

  // Alerts: thresholds live in their own fields until Save.
  late AlertSettings _alerts;
  late final TextEditingController _intakeWarmController;
  late final TextEditingController _intakeHotController;
  late final TextEditingController _exhaustWarmController;
  late final TextEditingController _exhaustHotController;
  String? _intakeError;
  String? _exhaustError;

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
    _alerts = settings.alerts;
    String degrees(double c) => c.round().toString();
    _intakeWarmController = TextEditingController(
      text: degrees(_alerts.intake.warm),
    );
    _intakeHotController = TextEditingController(
      text: degrees(_alerts.intake.hot),
    );
    _exhaustWarmController = TextEditingController(
      text: degrees(_alerts.exhaust.warm),
    );
    _exhaustHotController = TextEditingController(
      text: degrees(_alerts.exhaust.hot),
    );
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
  /// messages ("Required") don't say which value they're about.
  String? get _saveError => _intakeError != null
      ? 'Intake temperature: $_intakeError'
      : _exhaustError != null
      ? 'Exhaust temperature: $_exhaustError'
      : _webPinError != null
      ? 'Viewer PIN: $_webPinError'
      : _webOperatorPinError != null
      ? 'Operator PIN: $_webOperatorPinError'
      : null;

  bool get _alertsHaveError => _intakeError != null || _exhaustError != null;
  bool get _webHasError => _webPinError != null || _webOperatorPinError != null;

  @override
  void dispose() {
    _intervalController.dispose();
    _intakeWarmController.dispose();
    _intakeHotController.dispose();
    _exhaustWarmController.dispose();
    _exhaustHotController.dispose();
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

    // Checked before anything is written, so a rejected value saves nothing.
    final intakeWarm = int.tryParse(_intakeWarmController.text);
    final intakeHot = int.tryParse(_intakeHotController.text);
    final exhaustWarm = int.tryParse(_exhaustWarmController.text);
    final exhaustHot = int.tryParse(_exhaustHotController.text);
    final intakeError = temperatureThresholdError(intakeWarm, intakeHot);
    final exhaustError = temperatureThresholdError(exhaustWarm, exhaustHot);
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
    if (intakeError != null ||
        exhaustError != null ||
        pinErrors.viewer != null ||
        pinErrors.operator != null) {
      setState(() {
        _intakeError = intakeError;
        _exhaustError = exhaustError;
        _webPinError = pinErrors.viewer;
        _webOperatorPinError = pinErrors.operator;
        _section = _alertsHaveError ? _Section.alerts : _Section.web;
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

    // Alerts
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    settingsNotifier.setAlertSettings(
      _alerts.copyWith(
        intake: (warm: intakeWarm!.toDouble(), hot: intakeHot!.toDouble()),
        exhaust: (warm: exhaustWarm!.toDouble(), hot: exhaustHot!.toDouble()),
      ),
    );

    // OSC settings
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

  Widget _numberField(
    TextEditingController controller, {
    String? unit,
    double inputWidth = 44,
  }) => SettingsValueField(
    controller: controller,
    unit: unit,
    inputWidth: inputWidth,
  );

  Widget _pinField({
    required TextEditingController controller,
    required String? error,
    required VoidCallback clearError,
    required bool isSet,
    bool enabled = true,
  }) => SettingsValueField(
    controller: controller,
    numeric: false,
    obscureText: true,
    maxLength: 8,
    width: 132,
    enabled: enabled,
    hasError: error != null,
    hintText: isSet ? 'Unchanged' : 'Not set',
    onChanged: (_) {
      if (error != null) setState(clearError);
    },
  );

  List<SettingsDropdownEntry<String>> get _interfaceEntries => [
    for (final iface in _networkInterfaces ?? const <NetworkInterface>[])
      for (final addr in iface.addresses)
        SettingsDropdownEntry(
          value: addr.address,
          label: addr.address,
          detail: iface.name,
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
            control: _numberField(_intervalController, unit: 's'),
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

  void _setRule(AlertRule rule, bool on) => setState(
    () => _alerts = _alerts.copyWith(
      enabled: on
          ? {..._alerts.enabled, rule}
          : _alerts.enabled.difference({rule}),
    ),
  );

  SettingsRow _ruleRow(
    AlertRule rule, {
    required String hint,
    AlertSeverity? severity,
    List<Widget> fields = const [],
    String? error,
  }) {
    final on = _alerts.isEnabled(rule);
    return SettingsRow(
      label: rule.label,
      hint: hint,
      error: error,
      enabled: on,
      leading: severity == null
          ? const SizedBox(width: 16)
          : _SeverityIcon(severity),
      controlWidth: 260,
      control: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          if (fields.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: fields),
          Switch(value: on, onChanged: (v) => _setRule(rule, v)),
        ],
      ),
    );
  }

  /// Warning and critical fields of one temperature rule.
  List<Widget> _thresholdFields(
    AlertRule rule,
    TextEditingController warm,
    TextEditingController hot,
    String? error,
    VoidCallback clearError,
  ) => [
    for (final (controller, severity) in [
      (warm, AlertSeverity.warning),
      (hot, AlertSeverity.critical),
    ])
      SettingsValueField(
        controller: controller,
        unit: '°C',
        inputWidth: 24,
        leading: _SeverityIcon(severity, size: 14),
        enabled: _alerts.isEnabled(rule),
        hasError: error != null,
        semanticLabel: '${rule.label} ${severity.name}',
        onChanged: (_) {
          if (error != null) setState(clearError);
        },
      ),
  ];

  Widget _scopeButton(
    AlertNotifyScope value,
    bool enabled,
    ValueChanged<AlertNotifyScope> onChanged,
  ) => SegmentedButton<AlertNotifyScope>(
    segments: const [
      ButtonSegment(value: AlertNotifyScope.critical, label: Text('Critical')),
      ButtonSegment(value: AlertNotifyScope.all, label: Text('All')),
    ],
    selected: {value},
    showSelectedIcon: false,
    onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
  );

  Widget _buildAlerts() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 20,
    children: [
      SettingsGroup(
        title: 'Rules',
        children: [
          _ruleRow(
            AlertRule.offline,
            hint: 'Poll gets no answer',
            severity: AlertSeverity.critical,
          ),
          _ruleRow(
            AlertRule.error,
            hint: 'Any error the projector reports',
            severity: AlertSeverity.critical,
          ),
          _ruleRow(
            AlertRule.signalLost,
            hint: 'Every dropout while powered on',
            severity: AlertSeverity.critical,
          ),
          _ruleRow(
            AlertRule.intakeTemp,
            hint: 'Also tints the Monitoring table',
            error: _intakeError,
            fields: _thresholdFields(
              AlertRule.intakeTemp,
              _intakeWarmController,
              _intakeHotController,
              _intakeError,
              () => _intakeError = null,
            ),
          ),
          _ruleRow(
            AlertRule.exhaustTemp,
            hint: 'Also tints the Monitoring table',
            error: _exhaustError,
            fields: _thresholdFields(
              AlertRule.exhaustTemp,
              _exhaustWarmController,
              _exhaustHotController,
              _exhaustError,
              () => _exhaustError = null,
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Notify',
        children: [
          SettingsRow(
            label: 'Desktop notification',
            control: Switch(
              value: _alerts.desktopNotification,
              onChanged: (v) => setState(
                () => _alerts = _alerts.copyWith(desktopNotification: v),
              ),
            ),
          ),
          SettingsRow(
            label: 'Notify for',
            indented: true,
            enabled: _alerts.desktopNotification,
            control: _scopeButton(
              _alerts.desktopNotifyFor,
              _alerts.desktopNotification,
              (v) => setState(
                () => _alerts = _alerts.copyWith(desktopNotifyFor: v),
              ),
            ),
          ),
          SettingsRow(
            label: 'Sound',
            control: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                // The critical sound: the one an operator must recognise.
                IconButton(
                  tooltip: 'Play sample',
                  icon: const Icon(Icons.volume_up_outlined, size: 20),
                  onPressed: () =>
                      ref.read(alertSoundServiceProvider).play(critical: true),
                ),
                Switch(
                  value: _alerts.sound,
                  onChanged: (v) =>
                      setState(() => _alerts = _alerts.copyWith(sound: v)),
                ),
              ],
            ),
          ),
          SettingsRow(
            label: 'Play for',
            indented: true,
            enabled: _alerts.sound,
            control: _scopeButton(
              _alerts.soundFor,
              _alerts.sound,
              (v) => setState(() => _alerts = _alerts.copyWith(soundFor: v)),
            ),
          ),
          SettingsRow(
            label: 'OSC message',
            hint: '/pgrid/alert/<rule> to the OSC target',
            control: Switch(
              value: _alerts.osc,
              onChanged: (v) =>
                  setState(() => _alerts = _alerts.copyWith(osc: v)),
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
            control: SettingsDropdown<String>(
              value: _selectedNetworkDevice,
              entries: [
                const SettingsDropdownEntry(
                  value: '',
                  label: 'Any interface',
                  detail: '0.0.0.0',
                  dividerAfter: true,
                ),
                ..._interfaceEntries,
              ],
              onSelected: (value) =>
                  setState(() => _selectedNetworkDevice = value),
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
            control: SettingsValueField(
              controller: _oscSendIpController,
              numeric: false,
              width: 240,
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
              control: SettingsDropdown<String>(
                value: ip,
                placeholder: 'No network',
                entries: _interfaceEntries,
                onSelected: (value) => setState(() => _webUrlIp = value),
              ),
            ),
            SettingsRow(
              label: 'Port',
              hint: 'HTTP',
              controlWidth: 120,
              control: SettingsValueField(
                controller: _webPortController,
                inputWidth: 44,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (ip != null)
              SettingsRow(
                label: 'Link',
                controlWidth: 300,
                control: _LinkField(url: _webUrl(ip)),
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
              controlWidth: 132,
              control: _pinField(
                controller: _webPinController,
                error: _webPinError,
                clearError: () => _webPinError = null,
                isSet: settings.webViewerPinHash != null,
              ),
            ),
            SettingsRow(
              label: 'Allow control',
              controlWidth: 132,
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
              controlWidth: 132,
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
              // Just the button's width, so the hint keeps one line.
              controlWidth: 140,
              control: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
    final saveError = _saveError;

    Color? dotFor(_Section section) => switch (section) {
      _Section.general => null,
      _Section.alerts => _alertsHaveError ? theme.colorScheme.error : null,
      _Section.osc => oscRunning ? Colors.green : theme.colorScheme.outline,
      _Section.web =>
        _webHasError
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
                            _Section.alerts => _buildAlerts(),
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
                      saveError ?? '',
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

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon(this.severity, {this.size = 16});

  final AlertSeverity severity;
  final double size;

  @override
  Widget build(BuildContext context) => severity == AlertSeverity.critical
      ? Icon(Icons.error, size: size, color: Colors.red)
      : Icon(Icons.warning, size: size, color: Colors.orange);
}

/// The Web Access link: read-only, so a quieter surface than the editable
/// fields, with the copy button inside.
class _LinkField extends StatelessWidget {
  const _LinkField({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              url,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            iconSize: 16,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.copy),
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          ),
        ],
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
              'Plain HTTP: PINs are sent unencrypted. '
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
