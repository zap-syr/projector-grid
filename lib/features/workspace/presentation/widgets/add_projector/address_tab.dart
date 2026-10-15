import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/ip_input.dart';
import '../common/dialog_parts.dart';
import '../projector_form/port_field.dart';
import '../projector_form/projector_login_card.dart';
import 'add_tab_shared.dart';

/// Add Projectors, one address.
class AddressTab extends StatefulWidget {
  const AddressTab({
    super.key,
    required this.existingIps,
    required this.login,
    required this.onAdd,
  });

  final Set<String> existingIps;
  final AddLogin login;
  final AddProjectorsCallback onAdd;

  @override
  State<AddressTab> createState() => _AddressTabState();
}

class _AddressTabState extends State<AddressTab> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '$defaultNtcontrolPort');

  @override
  void initState() {
    super.initState();
    for (final c in [_ip, _port]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  IpCheck get _check => checkIp(_ip.text, widget.existingIps);

  int? get _parsedPort => parsePort(_port.text);

  bool get _canAdd => _check == IpCheck.free && _parsedPort != null;

  void _submit() {
    if (!_canAdd) return;
    widget.onAdd([widget.login.config(_ip.text.trim(), _parsedPort!)]);
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final help = switch (check) {
      IpCheck.free => const FieldHelp(
        'Not in project yet',
        tone: FieldHelpTone.success,
      ),
      IpCheck.taken => const FieldHelp(
        'Already in project',
        tone: FieldHelpTone.error,
      ),
      IpCheck.invalid => const FieldHelp(
        'Not a valid IP address',
        tone: FieldHelpTone.error,
      ),
      // Nothing typed yet: an error before the first key would only nag.
      IpCheck.empty || IpCheck.unchanged => const FieldHelp(''),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DialogScrollBody(
            padding: addTabPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'IP address',
                        help: help,
                        child: TextField(
                          key: const ValueKey('add-ip'),
                          controller: _ip,
                          autofocus: true,
                          style: monoFieldStyle,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: dialogFieldDecoration(
                            context,
                            hintText: '192.168.0.10',
                            error:
                                check == IpCheck.taken ||
                                check == IpCheck.invalid,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ),
                    const SizedBox(width: addTabFieldGap),
                    SizedBox(
                      width: addTabPortWidth,
                      child: PortField(controller: _port, onSubmitted: _submit),
                    ),
                  ],
                ),
                const SizedBox(height: addTabLoginGap),
                ProjectorLoginCard(
                  login: widget.login.login,
                  password: widget.login.password,
                  lastUsed: widget.login.lastUsed,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        DialogFooter(
          actionLabel: addOneLabel,
          widestActionLabel: addManyLabel,
          actionIcon: Icons.add,
          onAction: _canAdd ? _submit : null,
        ),
      ],
    );
  }
}
