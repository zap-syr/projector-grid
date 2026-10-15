import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import 'add_projector/add_tab_shared.dart';
import 'add_projector/address_tab.dart';
import 'add_projector/discover_tab.dart';
import 'add_projector/ip_range_tab.dart';
import 'common/segmented_tabs.dart';
import 'dialog_title_bar.dart';
import 'projector_form/form_parts.dart';

enum _AddTab { address, range, discover }

class AddProjectorDialog extends ConsumerStatefulWidget {
  final void Function(List<Map<String, dynamic>>) onAddProjectors;
  final List<String> existingIps;

  /// The machine's network interfaces for Discover; tests pass their own.
  final Future<List<NetInterface>> Function() loadInterfaces;

  const AddProjectorDialog({
    super.key,
    required this.onAddProjectors,
    required this.existingIps,
    this.loadInterfaces = listNetInterfaces,
  });

  @override
  ConsumerState<AddProjectorDialog> createState() => _AddProjectorDialogState();
}

class _AddProjectorDialogState extends ConsumerState<AddProjectorDialog> {
  var _tab = _AddTab.address;

  // Built on first visit, then kept: switching back keeps what was typed
  // (and a running scan) instead of starting over.
  final _visited = {_AddTab.address};

  // One login shared by the three tabs, so switching tabs keeps it.
  late final TextEditingController _login;
  late final TextEditingController _password;
  late final Set<String> _existing = widget.existingIps.toSet();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _login = TextEditingController(text: settings.lastProjectorLogin);
    _password = TextEditingController(text: settings.lastProjectorPassword);
    // The Last used marker goes once the login is edited.
    _login.addListener(_rebuild);
    _password.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isLastUsed() {
    final s = ref.read(appSettingsProvider);
    return (s.lastProjectorLogin.isNotEmpty ||
            s.lastProjectorPassword.isNotEmpty) &&
        _login.text == s.lastProjectorLogin &&
        _password.text == s.lastProjectorPassword;
  }

  void _add(List<Map<String, dynamic>> projectors) {
    ref
        .read(appSettingsProvider.notifier)
        .setLastProjectorLogin(_login.text, _password.text);
    widget.onAddProjectors(projectors);
    Navigator.of(context).pop();
  }

  Widget _tabBody(_AddTab tab, bool lastUsed) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    final login = AddLogin(
      login: _login,
      password: _password,
      lastUsed: lastUsed,
    );
    return switch (tab) {
      _AddTab.address => AddressTab(
        existingIps: _existing,
        login: login,
        onAdd: _add,
      ),
      _AddTab.range => IpRangeTab(
        existingIps: _existing,
        login: login,
        onAdd: _add,
      ),
      _AddTab.discover => DiscoverTab(
        existingIps: _existing,
        login: login,
        loadInterfaces: widget.loadInterfaces,
        onAdd: _add,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lastUsed = _isLastUsed();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: FormSurfaces.of(context).body,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(
              icon: Icons.videocam_outlined,
              title: 'Add Projectors',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: SegmentedTabs<_AddTab>(
                selected: _tab,
                onChanged: (t) => setState(() {
                  _tab = t;
                  _visited.add(t);
                }),
                tabs: const [
                  SegmentedTab(
                    value: _AddTab.address,
                    label: 'Address',
                    icon: Icons.gps_fixed,
                  ),
                  SegmentedTab(
                    value: _AddTab.range,
                    label: 'IP range',
                    icon: Icons.view_agenda_outlined,
                  ),
                  SegmentedTab(
                    value: _AddTab.discover,
                    label: 'Discover',
                    icon: Icons.radar,
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                sizing: StackFit.expand,
                children: [
                  for (final t in _AddTab.values) _tabBody(t, lastUsed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
