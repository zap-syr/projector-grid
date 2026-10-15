import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/ip_input.dart';
import '../common/dialog_parts.dart';
import '../projector_form/port_field.dart';
import '../projector_form/projector_login_card.dart';
import 'add_tab_shared.dart';
import 'range_preview.dart';

/// Add Projectors, a run of addresses in one /24. Only the last octet of To
/// is typed: a range never leaves the From address's subnet.
class IpRangeTab extends StatefulWidget {
  const IpRangeTab({
    super.key,
    required this.existingIps,
    required this.login,
    required this.onAdd,
  });

  final Set<String> existingIps;
  final AddLogin login;
  final AddProjectorsCallback onAdd;

  @override
  State<IpRangeTab> createState() => _IpRangeTabState();
}

class _IpRangeTabState extends State<IpRangeTab> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _port = TextEditingController(text: '$defaultNtcontrolPort');

  @override
  void initState() {
    super.initState();
    for (final c in [_from, _to, _port]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _port.dispose();
    super.dispose();
  }

  IpRangeInput get _range => parseIpRange(_from.text, _to.text);

  List<String> get _newIps => switch (_range) {
    IpRangeValid r => [
      for (final ip in r.addresses)
        if (!widget.existingIps.contains(ip)) ip,
    ],
    _ => const [],
  };

  void _submit() {
    final port = parsePort(_port.text);
    final ips = _newIps;
    if (port == null || ips.isEmpty) return;
    widget.onAdd([for (final ip in ips) widget.login.config(ip, port)]);
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final newCount = _newIps.length;
    final portOk = parsePort(_port.text) != null;
    final fromText = _from.text.trim();
    final fromError = fromText.isNotEmpty && !isValidIpv4(fromText);
    final prefix = ipPrefix(fromText);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DialogScrollBody(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'From',
                        help: fromError
                            ? const FieldHelp(
                                'Not a valid IP address',
                                tone: FieldHelpTone.error,
                              )
                            : null,
                        child: TextField(
                          key: const ValueKey('range-from'),
                          controller: _from,
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
                            error: fromError,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ),
                    Padding(
                      // Level with the fields, under their labels.
                      padding: const EdgeInsets.fromLTRB(12, 32, 12, 0),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: LabeledField(
                        label: 'To',
                        help: range is IpRangeReversed
                            ? FieldHelp(
                                'Not lower than .${range.firstOctet}',
                                tone: FieldHelpTone.error,
                              )
                            : null,
                        child: TextField(
                          key: const ValueKey('range-to'),
                          controller: _to,
                          style: monoFieldStyle,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: dialogFieldDecoration(
                            context,
                            hintText: prefix == null ? 'Last number' : null,
                            error: range is IpRangeReversed,
                            prefix: prefix == null
                                ? null
                                : Text(
                                    prefix,
                                    style: monoFieldStyle.copyWith(
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: PortField(
                        controller: _port,
                        showDefault: false,
                        onSubmitted: _submit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                switch (range) {
                  IpRangeValid r => RangePreview(
                    range: r,
                    existingIps: widget.existingIps,
                  ),
                  _ => const RangePreviewPlaceholder(),
                },
                const SizedBox(height: 18),
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
          actionLabel: addProjectorsLabel(newCount),
          actionIcon: Icons.add,
          onAction: newCount > 0 && portOk ? _submit : null,
        ),
      ],
    );
  }
}
