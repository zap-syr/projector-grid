import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/ip_input.dart';
import '../../providers/protocol_service_provider.dart';
import '../common/dialog_parts.dart';
import '../projector_form/port_field.dart';
import '../projector_form/projector_login_card.dart';
import 'add_tab_shared.dart';
import 'discover_results.dart';

/// A network interface Discover can sweep: its name and IPv4 address.
typedef NetInterface = ({String name, String address});

Future<List<NetInterface>> listNetInterfaces() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );
  return [
    for (final i in interfaces)
      if (i.addresses.isNotEmpty)
        (name: i.name, address: i.addresses.first.address),
  ];
}

/// Add Projectors, a sweep of the chosen interface's /24. Starts on its own
/// the first time the tab opens; the login goes with it so each projector
/// can say whether it takes that login.
class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({
    super.key,
    required this.existingIps,
    required this.login,
    required this.loadInterfaces,
    required this.onAdd,
  });

  final Set<String> existingIps;
  final AddLogin login;
  final Future<List<NetInterface>> Function() loadInterfaces;
  final AddProjectorsCallback onAdd;

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  final _port = TextEditingController(text: '$defaultNtcontrolPort');

  /// Null while the list loads.
  List<NetInterface>? _interfaces;
  String? _address;

  StreamSubscription<Map<String, dynamic>>? _scan;

  /// The /24 of the last scan (`192.168.0`), null before the first.
  String? _scannedSubnet;
  int _scannedPort = defaultNtcontrolPort;

  /// The login the scan probed with: its statuses only hold for that login.
  ({String login, String password})? _scannedLogin;
  final List<DiscoveredProjector> _found = [];
  final Set<String> _selected = {};

  bool get _scanning => _scan != null;

  @override
  void initState() {
    super.initState();
    _port.addListener(() => setState(() {}));
    _loadInterfaces();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _port.dispose();
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    final interfaces = await widget.loadInterfaces();
    if (!mounted) return;
    setState(() {
      _interfaces = interfaces;
      _address = interfaces.firstOrNull?.address;
    });
    _startScan();
  }

  void _startScan() {
    final address = _address;
    final port = parsePort(_port.text);
    if (address == null || port == null) return;
    _scan?.cancel();
    final subnet = address.substring(0, address.lastIndexOf('.'));
    final login = (
      login: widget.login.login.text,
      password: widget.login.password.text,
    );
    setState(() {
      _scannedSubnet = subnet;
      _scannedPort = port;
      _scannedLogin = login;
      _found.clear();
      _selected.clear();
    });
    _scan = ref
        .read(protocolServiceProvider)
        .scanNetwork(subnet, port, login: login.login, password: login.password)
        .listen(
          (result) {
            if (!mounted) return;
            final p = DiscoveredProjector.fromScan(result);
            setState(() {
              _found.add(p);
              if (!widget.existingIps.contains(p.ip)) _selected.add(p.ip);
            });
          },
          onDone: () {
            if (mounted) setState(() => _scan = null);
          },
        );
  }

  void _stopScan() {
    _scan?.cancel();
    setState(() => _scan = null);
  }

  List<DiscoveredProjector> get _newFound => [
    for (final p in _found)
      if (!widget.existingIps.contains(p.ip)) p,
  ];

  void _submit() {
    final picked = [
      for (final p in _newFound)
        if (_selected.contains(p.ip)) p,
    ];
    if (picked.isEmpty) return;
    // A login edited after the scan makes its statuses stale ("Wrong login"
    // fixed, or a good one mistyped): add as not yet probed so the
    // workspace checks each projector again with the login it now has.
    final loginUnchanged =
        _scannedLogin ==
        (login: widget.login.login.text, password: widget.login.password.text);
    widget.onAdd([
      for (final p in picked)
        widget.login.config(
          p.ip,
          _scannedPort,
          name: p.name,
          status: loginUnchanged ? p.status.scanStatus : 'offline',
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _newFound.length;
    final selectedCount = _selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _networkRow(context),
                const SizedBox(height: 16),
                CompactProjectorLogin(
                  login: widget.login.login,
                  password: widget.login.password,
                  lastUsed: widget.login.lastUsed,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: DiscoverResults(
                    subnet: _scannedSubnet,
                    scanning: _scanning,
                    found: _found,
                    existingIps: widget.existingIps,
                    selected: _selected,
                    onToggle: (ip, on) => setState(() {
                      on ? _selected.add(ip) : _selected.remove(ip);
                    }),
                    onToggleAll: (on) => setState(() {
                      _selected.clear();
                      if (on) _selected.addAll(_newFound.map((p) => p.ip));
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        DialogFooter(
          message: newCount == 0
              ? null
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$selectedCount',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' of $newCount new selected'),
                    ],
                  ),
                ),
          actionLabel: addProjectorsLabel(selectedCount),
          actionIcon: Icons.add,
          onAction: selectedCount > 0 && !_scanning ? _submit : null,
        ),
      ],
    );
  }

  Widget _networkRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final interfaces = _interfaces;
    final Widget network;
    if (interfaces == null) {
      network = const SizedBox(height: 40);
    } else if (interfaces.isEmpty) {
      network = SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No active network interfaces found',
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        ),
      );
    } else {
      network = DropdownButtonFormField<String>(
        key: const ValueKey('discover-network'),
        initialValue: _address,
        isExpanded: true,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        decoration: dialogFieldDecoration(context),
        items: [
          for (final i in interfaces)
            DropdownMenuItem(
              value: i.address,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      i.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    i.address,
                    style: monoFieldStyle.copyWith(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (a) => setState(() => _address = a),
      );
    }
    final canScan = _address != null && parsePort(_port.text) != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledField(label: 'Network', child: network),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: PortField(
            controller: _port,
            showDefault: false,
            onSubmitted: canScan ? _startScan : null,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          // Level with the fields, under their labels.
          padding: const EdgeInsets.only(top: 23),
          child: SizedBox(
            height: 40,
            child: _scanning
                ? FilledButton.tonalIcon(
                    onPressed: _stopScan,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: canScan ? _startScan : null,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(_scannedSubnet == null ? 'Scan' : 'Scan again'),
                  ),
          ),
        ),
      ],
    );
  }
}
