import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import '../providers/workspace_provider.dart';

class PreferencesDialog extends ConsumerStatefulWidget {
  const PreferencesDialog({super.key});

  @override
  ConsumerState<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends ConsumerState<PreferencesDialog> {
  late final TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    final current = ref.read(appSettingsProvider).pollingIntervalSeconds;
    _intervalController = TextEditingController(text: current.toString());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  void _applyInterval() {
    final value = int.tryParse(_intervalController.text);
    if (value != null && value > 0) {
      ref.read(appSettingsProvider.notifier).setPollingInterval(value);
      ref.read(workspaceProvider.notifier).setPollingInterval(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Dialog(
      child: SizedBox(
        width: 480,
        height: 360,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text(
                  'Preferences',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'OSC'),
                ],
                labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    // ── General ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Update Interval
                          Text('Update Interval', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
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
                                  onSubmitted: (_) => _applyInterval(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _applyInterval,
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Theme
                          Text('Theme', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (selection) {
                              ref.read(appSettingsProvider.notifier).setThemeMode(selection.first);
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── OSC ──────────────────────────────────────────────────
                    const Center(
                      child: Text('OSC settings coming soon.'),
                    ),
                  ],
                ),
              ),

              // Footer
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
