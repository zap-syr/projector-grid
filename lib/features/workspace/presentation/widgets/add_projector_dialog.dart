import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../../core/services/panasonic_protocol_service.dart';

class AddProjectorDialog extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onAddProjectors;
  final List<String> existingIps;

  const AddProjectorDialog({super.key, required this.onAddProjectors, required this.existingIps});

  @override
  State<AddProjectorDialog> createState() => _AddProjectorDialogState();
}

class _AddProjectorDialogState extends State<AddProjectorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        height: 620,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Manual Add'),
                  Tab(text: 'Auto Discovery'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ManualAddTab(
                    existingIps: widget.existingIps,
                    onAdd: (projector) {
                      widget.onAddProjectors([projector]);
                      Navigator.of(context).pop();
                    },
                    onAddMultiple: (projectors) {
                      widget.onAddProjectors(projectors);
                      Navigator.of(context).pop();
                    },
                  ),
                  _AutoDiscoveryTab(
                    existingIps: widget.existingIps,
                    onAddSelected: (projectors) {
                      widget.onAddProjectors(projectors);
                      Navigator.of(context).pop();
                    },
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

class _ManualAddTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  final Function(List<Map<String, dynamic>>) onAddMultiple;
  final List<String> existingIps;

  const _ManualAddTab({required this.onAdd, required this.onAddMultiple, required this.existingIps});

  @override
  State<_ManualAddTab> createState() => _ManualAddTabState();
}

class _ManualAddTabState extends State<_ManualAddTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isRange = false;

  final _ipController = TextEditingController();
  final _startIpController = TextEditingController();
  final _endIpController = TextEditingController();
  final _portController = TextEditingController(text: '1024');
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  final _ipRegex = RegExp(r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");

  @override
  void dispose() {
    _ipController.dispose();
    _startIpController.dispose();
    _endIpController.dispose();
    _portController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final port = int.tryParse(_portController.text) ?? 1024;
      final login = _loginController.text;
      final password = _passwordController.text;

      if (_isRange) {
        final startParts = _startIpController.text.split('.');
        final endParts = _endIpController.text.split('.');

        final startPrefix = startParts.sublist(0, 3).join('.');
        final endPrefix = endParts.sublist(0, 3).join('.');

        if (startPrefix != endPrefix) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Start and End IP must be in the same subnet (first 3 octets)')),
          );
          return;
        }

        final startLast = int.parse(startParts[3]);
        final endLast = int.parse(endParts[3]);

        if (startLast > endLast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Start IP must be lower or equal to End IP')),
          );
          return;
        }

        List<Map<String, dynamic>> results = [];
        List<String> duplicates = [];
        for (int i = startLast; i <= endLast; i++) {
          final ip = '$startPrefix.$i';
          if (widget.existingIps.contains(ip)) {
            duplicates.add(ip);
            continue;
          }
          results.add({
            'ip': ip,
            'port': port,
            'login': login,
            'password': password,
            'status': 'offline',
          });
        }

        if (duplicates.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Skipped ${duplicates.length} duplicate IP(s)')),
          );
        }
        if (results.isNotEmpty) {
          widget.onAddMultiple(results);
        }
      } else {
        final ip = _ipController.text;
        if (widget.existingIps.contains(ip)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IP Address already exists in project')),
          );
          return;
        }

        widget.onAdd({
          'ip': ip,
          'port': port,
          'login': login,
          'password': password,
          'status': 'offline',
        });
      }
    }
  }

  String? _validateIp(String? value) {
    if (value == null || value.isEmpty) return 'IP Address is required';
    if (!_ipRegex.hasMatch(value)) return 'Invalid IP Address format';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Single Projector')),
              ButtonSegment(value: true, label: Text('IP Range')),
            ],
            selected: {_isRange},
            onSelectionChanged: (set) {
              setState(() {
                _isRange = set.first;
              });
            },
          ),
          const SizedBox(height: 24),
          if (!_isRange)
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'IP Address', border: OutlineInputBorder()),
              validator: _validateIp,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startIpController,
                    decoration: const InputDecoration(labelText: 'Start IP Address', border: OutlineInputBorder()),
                    validator: _validateIp,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endIpController,
                    decoration: const InputDecoration(labelText: 'End IP Address', border: OutlineInputBorder()),
                    validator: _validateIp,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (val) {
              if (val == null || val.isEmpty) return 'Port required';
              final p = int.tryParse(val);
              if (p == null || p < 1 || p > 65535) return 'Invalid port (1-65535)';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginController,
            decoration: const InputDecoration(labelText: 'Login', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Credentials are not required for projectors in non-protected mode.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoDiscoveryTab extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onAddSelected;
  final List<String> existingIps;

  const _AutoDiscoveryTab({required this.onAddSelected, required this.existingIps});

  @override
  State<_AutoDiscoveryTab> createState() => _AutoDiscoveryTabState();
}

class _AutoDiscoveryTabState extends State<_AutoDiscoveryTab> {
  final _portController = TextEditingController(text: '1024');
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  List<NetworkInterface> _interfaces = [];
  NetworkInterface? _selectedInterface;
  String? _selectedIp;

  bool _isScanning = false;
  List<Map<String, dynamic>> _foundProjectors = [];
  final Set<String> _selectedIps = {};

  final _protocolService = PanasonicProtocolService();

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _portController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      if (mounted) {
        setState(() {
          _interfaces = interfaces;
          if (interfaces.isNotEmpty) {
            _selectedInterface = interfaces.first;
            _selectedIp = interfaces.first.addresses.first.address;
          }
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _startScan() async {
    if (_selectedInterface == null || _selectedInterface!.addresses.isEmpty) return;

    setState(() {
      _isScanning = true;
      _foundProjectors = [];
      _selectedIps.clear();
    });

    final address = _selectedInterface!.addresses.first.address;
    final parts = address.split('.');
    if (parts.length != 4) {
      setState(() {
        _isScanning = false;
      });
      return;
    }

    final subnet = parts.sublist(0, 3).join('.');
    final port = int.tryParse(_portController.text) ?? 1024;
    final login = _loginController.text;
    final password = _passwordController.text;

    final stream = _protocolService.scanNetwork(subnet, port, login: login, password: password);

    stream.listen((result) {
      if (mounted) {
        setState(() {
          final ip = result['ip'] as String;
          if (!widget.existingIps.contains(ip)) {
            _foundProjectors.add(result);
            _selectedIps.add(ip);
          }
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_interfaces.isEmpty)
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Text(
                  'No active network interfaces found',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownMenu<String>(
                    initialSelection: _selectedIp,
                    expandedInsets: EdgeInsets.zero,
                    requestFocusOnTap: false,
                    enableFilter: false,
                    label: const Text('Network Interface'),
                    inputDecorationTheme: const InputDecorationTheme(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    dropdownMenuEntries: _interfaces.map((i) {
                      final ip = i.addresses.first.address;
                      return DropdownMenuEntry(value: ip, label: '${i.name}  $ip');
                    }).toList(),
                    onSelected: (ip) {
                      if (ip == null) return;
                      setState(() {
                        _selectedIp = ip;
                        _selectedInterface = _interfaces.firstWhere(
                          (i) => i.addresses.any((a) => a.address == ip),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _loginController,
                  decoration: const InputDecoration(labelText: 'Login', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Credentials are not required for projectors in non-protected mode.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning Subnet...' : 'Scan Network'),
            ),
          ),
          const Divider(height: 32),
          Text('Discovered Projectors', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _foundProjectors.isEmpty && !_isScanning
                  ? const Center(child: Text('No projectors found. Click scan to search.'))
                  : ListView.builder(
                      itemCount: _foundProjectors.length,
                      itemBuilder: (context, index) {
                        final p = _foundProjectors[index];
                        final isSelected = _selectedIps.contains(p['ip']);
                        final isAuthError = p['status'] == 'auth_error';
                        final isUnprotected = p['status'] == 'unprotected';
                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(p['name'])),
                              if (isAuthError) ...[
                                const SizedBox(width: 6),
                                const Tooltip(
                                  message: 'Projector found but credentials are incorrect',
                                  child: Icon(Icons.lock_outline, size: 14, color: Colors.amber),
                                ),
                              ],
                              if (isUnprotected) ...[
                                const SizedBox(width: 6),
                                const Tooltip(
                                  message: 'Projector is in non-protected mode — no credentials required',
                                  child: Icon(Icons.lock_open, size: 14, color: Colors.blue),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isAuthError
                                ? '${p['ip']} • Auth Error — check login/password'
                                : isUnprotected
                                    ? '${p['ip']} • Non-protected mode'
                                    : '${p['ip']} • Online',
                            style: isAuthError
                                ? TextStyle(color: Colors.amber.shade700)
                                : isUnprotected
                                    ? TextStyle(color: Colors.blue.shade600)
                                    : null,
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIps.add(p['ip']);
                              } else {
                                _selectedIps.remove(p['ip']);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: _selectedIps.isEmpty || _isScanning
                    ? null
                    : () {
                        final port = int.tryParse(_portController.text) ?? 1024;
                        final login = _loginController.text;
                        final password = _passwordController.text;

                        final results = _foundProjectors
                            .where((p) => _selectedIps.contains(p['ip']))
                            .where((p) => !widget.existingIps.contains(p['ip']))
                            .map((p) => {
                                  'ip': p['ip'],
                                  'name': p['name'],
                                  'port': port,
                                  'login': login,
                                  'password': password,
                                  'status': switch (p['status']) {
                                    'online' => 'online',
                                    'unprotected' => 'unprotected',
                                    _ => 'auth_error',
                                  },
                                })
                            .toList();

                        final originalCount = _selectedIps.length;
                        if (results.length < originalCount) {
                          final duplicates = originalCount - results.length;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Skipped $duplicates duplicate IP(s) already in project')),
                          );
                        }

                        if (results.isNotEmpty) {
                          widget.onAddSelected(results);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text('Add Selected (${_selectedIps.length})'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
