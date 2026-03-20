import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import '../providers/osc_provider.dart';
import '../providers/workspace_provider.dart';

class PreferencesDialog extends ConsumerStatefulWidget {
  const PreferencesDialog({super.key});

  @override
  ConsumerState<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends ConsumerState<PreferencesDialog> {
  // General
  late final TextEditingController _intervalController;
  late ThemeMode _selectedTheme;

  // OSC
  late bool _oscActive;
  late String _selectedNetworkDevice;
  late final TextEditingController _oscReceivePortController;
  late final TextEditingController _oscSendIpController;
  late final TextEditingController _oscSendPortController;

  List<NetworkInterface>? _networkInterfaces;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _intervalController = TextEditingController(text: settings.pollingIntervalSeconds.toString());
    _selectedTheme = settings.themeMode;
    _oscActive = settings.oscActive;
    _selectedNetworkDevice = settings.oscNetworkDevice;
    _oscReceivePortController = TextEditingController(text: settings.oscReceivePort.toString());
    _oscSendIpController = TextEditingController(text: settings.oscSendIp);
    _oscSendPortController = TextEditingController(text: settings.oscSendPort.toString());
    _loadNetworkInterfaces();
  }

  Future<void> _loadNetworkInterfaces() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    if (mounted) setState(() => _networkInterfaces = interfaces);
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _oscReceivePortController.dispose();
    _oscSendIpController.dispose();
    _oscSendPortController.dispose();
    super.dispose();
  }

  void _save() {
    // General
    final interval = int.tryParse(_intervalController.text);
    if (interval != null && interval > 0) {
      ref.read(appSettingsProvider.notifier).setPollingInterval(interval);
      ref.read(workspaceProvider.notifier).setPollingInterval(interval);
    }
    ref.read(appSettingsProvider.notifier).setThemeMode(_selectedTheme);

    // OSC settings
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    settingsNotifier.setOscNetworkDevice(_selectedNetworkDevice);
    final recvPort = int.tryParse(_oscReceivePortController.text);
    if (recvPort != null && recvPort > 0) settingsNotifier.setOscReceivePort(recvPort);
    settingsNotifier.setOscSendIp(_oscSendIpController.text.trim());
    final sendPort = int.tryParse(_oscSendPortController.text);
    if (sendPort != null && sendPort > 0) settingsNotifier.setOscSendPort(sendPort);

    // OSC active toggle — compare against persisted setting, not auto-dispose provider state
    final oscNotifier = ref.read(oscProvider.notifier);
    final wasActive = ref.read(appSettingsProvider).oscActive;
    if (_oscActive && !wasActive) {
      oscNotifier.start();
    } else if (!_oscActive && wasActive) {
      oscNotifier.stop();
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
          entries.add(DropdownMenuEntry(
            value: addr.address,
            label: '${iface.name}  ${addr.address}',
          ));
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        height: 480,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text('Preferences', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'OSC'),
                ],
                labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    // ── General ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Update Interval', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _intervalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                suffixText: 's',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Theme', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                            ],
                            selected: {_selectedTheme},
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
                              Text('OSC Active', style: theme.textTheme.titleSmall),
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
                          Text('Network Device', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          DropdownMenu<String>(
                            initialSelection: _selectedNetworkDevice,
                            expandedInsets: EdgeInsets.zero,
                            requestFocusOnTap: false,
                            enableFilter: false,
                            inputDecorationTheme: const InputDecorationTheme(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Text('Receive Port', style: theme.textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _oscReceivePortController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Text('Send IP', style: theme.textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _oscSendIpController,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Text('Send Port', style: theme.textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _oscSendPortController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
