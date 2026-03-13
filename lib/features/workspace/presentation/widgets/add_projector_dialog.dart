import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../../core/services/panasonic_protocol_service.dart';

class AddProjectorDialog extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onAddProjectors;

  const AddProjectorDialog({super.key, required this.onAddProjectors});

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
        height: 600,
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
                  _ManualAddTab(onAdd: (projector) {
                    widget.onAddProjectors([projector]);
                    Navigator.of(context).pop();
                  }, onAddMultiple: (projectors) {
                    widget.onAddProjectors(projectors);
                    Navigator.of(context).pop();
                  }),
                  _AutoDiscoveryTab(onAddSelected: (projectors) {
                    widget.onAddProjectors(projectors);
                    Navigator.of(context).pop();
                  }),
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

  const _ManualAddTab({required this.onAdd, required this.onAddMultiple});

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
  final _loginController = TextEditingController(text: 'admin1');
  final _passwordController = TextEditingController(text: 'panasonic');

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
        // IP Range logic
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
        for (int i = startLast; i <= endLast; i++) {
          results.add({
            'ip': '$startPrefix.$i',
            'port': port,
            'login': login,
            'password': password,
            'status': 'offline', // default before ping
          });
        }
        widget.onAddMultiple(results);
      } else {
        // Single IP logic
        widget.onAdd({
          'ip': _ipController.text,
          'port': port,
          'login': login,
          'password': password,
          'status': 'offline', // default before ping
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
            validator: (val) {
              if (val == null || val.isEmpty) return 'Login required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            obscureText: false, // Made visible per user request
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password required';
              return null;
            },
          ),
          const SizedBox(height: 32),
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

  const _AutoDiscoveryTab({required this.onAddSelected});

  @override
  State<_AutoDiscoveryTab> createState() => _AutoDiscoveryTabState();
}

class _AutoDiscoveryTabState extends State<_AutoDiscoveryTab> {
  final _portController = TextEditingController(text: '1024');
  final _loginController = TextEditingController(text: 'admin1');
  final _passwordController = TextEditingController(text: 'panasonic');

  List<NetworkInterface> _interfaces = [];
  NetworkInterface? _selectedInterface;
  
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
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      if (mounted) {
        setState(() {
          _interfaces = interfaces;
          if (interfaces.isNotEmpty) {
            _selectedInterface = interfaces.first;
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
          _foundProjectors.add(result);
          _selectedIps.add(result['ip'] as String);
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<NetworkInterface>(
                  decoration: const InputDecoration(labelText: 'Network Interface', border: OutlineInputBorder()),
                  // ignore: deprecated_member_use
                  value: _selectedInterface,
                  items: _interfaces.map((i) {
                    final ip = i.addresses.isNotEmpty ? i.addresses.first.address : 'No IP';
                    return DropdownMenuItem(
                      value: i,
                      child: Text('${i.name} ($ip)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedInterface = val;
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
                  obscureText: false, // Made visible per user request
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
          Text('Discovered Projectors', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _foundProjectors.isEmpty && !_isScanning
                  ? const Center(child: Text('No projectors found. Click scan to search.'))
                  : ListView.builder(
                      itemCount: _foundProjectors.length,
                      itemBuilder: (context, index) {
                        final p = _foundProjectors[index];
                        final isSelected = _selectedIps.contains(p['ip']);
                        return CheckboxListTile(
                          title: Text(p['name']),
                          subtitle: Text('${p['ip']} • Status: ${p['status']}'),
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
                onPressed: _selectedIps.isEmpty || _isScanning ? null : () {
                  final port = int.tryParse(_portController.text) ?? 1024;
                  final login = _loginController.text;
                  final password = _passwordController.text;

                  final results = _foundProjectors
                    .where((p) => _selectedIps.contains(p['ip']))
                    .map((p) => {
                      'ip': p['ip'],
                      'name': p['name'],
                      'port': port,
                      'login': login,
                      'password': password,
                      'status': p['status'] == 'online' ? 'online' : 'protected',
                    }).toList();

                  widget.onAddSelected(results);
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
