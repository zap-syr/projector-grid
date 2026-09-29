import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/osc_provider.dart';
import '../providers/web_server_provider.dart';
import '../providers/workspace_provider.dart';
import 'dialog_title_bar.dart';

class PreferencesDialog extends ConsumerStatefulWidget {
  const PreferencesDialog({super.key});

  @override
  ConsumerState<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends ConsumerState<PreferencesDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
  String? _webUrlIp;

  List<NetworkInterface>? _networkInterfaces;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  void dispose() {
    _intervalController.dispose();
    _oscReceivePortController.dispose();
    _oscSendIpController.dispose();
    _oscSendPortController.dispose();
    _webPortController.dispose();
    _webPinController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    // Captured before any OSC field writes below, so we can tell whether the
    // connection parameters actually changed (needed to decide whether a
    // live socket needs rebinding, not just whether OSC was toggled).
    final oldSettings = ref.read(appSettingsProvider);

    // Checked before anything is written, so a rejected PIN saves nothing.
    final pin = _webPinController.text;
    final pinError = pin.isNotEmpty && (pin.length < 4 || pin.length > 8)
        ? '4–8 digits'
        : _webEnabled && pin.isEmpty && oldSettings.webViewerPinHash == null
        ? 'Required'
        : null;
    if (pinError != null) {
      setState(() => _webPinError = pinError);
      _tabController.animateTo(2);
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
    if (_webEnabled && !oldSettings.webEnabled) {
      webNotifier.start();
    } else if (!_webEnabled && oldSettings.webEnabled) {
      webNotifier.stop();
    } else if (_webEnabled && webPortValid && webPort != oldSettings.webPort) {
      webNotifier.restart();
    }

    Navigator.of(context).pop();
  }

  List<DropdownMenuEntry<String>> _buildNetworkDeviceEntries() {
    final entries = <DropdownMenuEntry<String>>[
      const DropdownMenuEntry(value: '', label: 'Any (0.0.0.0)'),
    ];
    if (_networkInterfaces != null) {
      for (final iface in _networkInterfaces!) {
        for (final addr in iface.addresses) {
          entries.add(
            DropdownMenuEntry(
              value: addr.address,
              label: '${iface.name}  ${addr.address}',
            ),
          );
        }
      }
    }
    return entries;
  }

  Widget _buildWebAccessTab(ThemeData theme) {
    final ip = _webUrlIp;
    final running = ref.watch(webServerProvider);
    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Web Access', style: theme.textTheme.titleSmall),
              const Spacer(),
              Switch(
                value: _webEnabled,
                onChanged: (value) => setState(() => _webEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Port', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webPortController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: fieldDecoration,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Viewer PIN', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: (_) {
                        if (_webPinError != null) {
                          setState(() => _webPinError = null);
                        }
                      },
                      decoration: fieldDecoration.copyWith(
                        errorText: _webPinError,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Address', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownMenu<String>(
            // Rebuilt once the interface list arrives so the first address
            // shows as selected.
            key: ValueKey(_networkInterfaces == null),
            initialSelection: ip,
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: false,
            enableFilter: false,
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            dropdownMenuEntries: [
              for (final iface
                  in _networkInterfaces ?? const <NetworkInterface>[])
                for (final addr in iface.addresses)
                  DropdownMenuEntry(
                    value: addr.address,
                    label: '${iface.name}  ${addr.address}',
                  ),
            ],
            onSelected: (value) => setState(() => _webUrlIp = value),
          ),
          if (ip != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _webUrl(ip),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _webUrl(ip))),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plain HTTP — the PIN is sent unencrypted',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: running
                    ? ref.read(webServerProvider.notifier).signOutAll
                    : null,
                child: const Text('Sign out all clients'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(title: 'Preferences'),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'OSC'),
                Tab(text: 'Web Access'),
              ],
              labelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 1),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── General ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Interval',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _intervalController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              suffixText: 's',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'How often projectors are polled '
                          '(${AppSettings.minPollingIntervalSeconds}-${AppSettings.maxPollingIntervalSeconds}s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Theme', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
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
                      ],
                    ),
                  ),

                  // ── OSC ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active toggle
                        Row(
                          children: [
                            Text(
                              'OSC Active',
                              style: theme.textTheme.titleSmall,
                            ),
                            const Spacer(),
                            Switch(
                              value: _oscActive,
                              onChanged: (value) {
                                setState(() => _oscActive = value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Network device
                        Text(
                          'Network Device',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        DropdownMenu<String>(
                          initialSelection: _selectedNetworkDevice,
                          expandedInsets: EdgeInsets.zero,
                          requestFocusOnTap: false,
                          enableFilter: false,
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          dropdownMenuEntries: _buildNetworkDeviceEntries(),
                          onSelected: (value) {
                            if (value != null) {
                              setState(() => _selectedNetworkDevice = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Receive port + Send IP + Send port
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Receive Port',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _oscReceivePortController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send IP',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _oscSendIpController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send Port',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _oscSendPortController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Web Access ───────────────────────────────────────
                  _buildWebAccessTab(theme),
                ],
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
