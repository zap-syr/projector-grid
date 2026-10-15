import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ip_input.dart';
import '../../domain/projector_node.dart';
import '../providers/workspace_provider.dart';
import 'dialog_title_bar.dart';
import 'projector_form/form_parts.dart';
import 'projector_form/port_field.dart';
import 'projector_form/projector_info_card.dart';
import 'projector_form/projector_login_card.dart';

class EditProjectorDialog extends ConsumerStatefulWidget {
  final ProjectorNode node;

  /// Every address in the project except [node]'s own.
  final Set<String> existingIps;
  final void Function(String ip, int port, String login, String password)
  onSave;

  const EditProjectorDialog({
    super.key,
    required this.node,
    required this.existingIps,
    required this.onSave,
  });

  @override
  ConsumerState<EditProjectorDialog> createState() =>
      _EditProjectorDialogState();
}

class _EditProjectorDialogState extends ConsumerState<EditProjectorDialog> {
  late final _ip = TextEditingController(text: widget.node.ipAddress);
  late final _port = TextEditingController(text: '${widget.node.port}');
  late final _login = TextEditingController(text: widget.node.login);
  late final _password = TextEditingController(text: widget.node.password);

  // Where focus starts is decided once: a projector that rejected its login
  // opens on Login, every other on the address.
  late final bool _openedOnWrongLogin =
      widget.node.connectionStatus == ConnectionStatus.unauthorized;

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
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  IpCheck get _ipCheck =>
      checkIp(_ip.text, widget.existingIps, original: widget.node.ipAddress);

  int? get _parsedPort => parsePort(_port.text);

  bool get _canSave =>
      (_ipCheck == IpCheck.unchanged || _ipCheck == IpCheck.free) &&
      _parsedPort != null;

  void _save() {
    if (!_canSave) return;
    widget.onSave(_ip.text.trim(), _parsedPort!, _login.text, _password.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wrongLogin = ref.watch(
      workspaceProvider.select(
        (nodes) =>
            (nodes.where((n) => n.id == widget.node.id).firstOrNull ??
                    widget.node)
                .connectionStatus ==
            ConnectionStatus.unauthorized,
      ),
    );
    return Dialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: FormSurfaces.of(context).body,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DialogTitleBar(
              icon: Icons.edit_outlined,
              title: 'Edit Projector',
            ),
            Flexible(
              child: FormScrollBody(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProjectorInfoCard(node: widget.node),
                    const SizedBox(height: 16),
                    _addressRow(context),
                    const SizedBox(height: 16),
                    ProjectorLoginCard(
                      login: _login,
                      password: _password,
                      wrongLogin: wrongLogin,
                      autofocusLogin: _openedOnWrongLogin,
                      onSubmitted: _save,
                    ),
                  ],
                ),
              ),
            ),
            FormFooter(actionLabel: 'Save', onAction: _canSave ? _save : null),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(BuildContext context) {
    final check = _ipCheck;
    final ipHelp = switch (check) {
      IpCheck.unchanged => const FieldHelp('Current address'),
      IpCheck.free => FieldHelp(
        'Changed from ${widget.node.ipAddress}, '
        'not used by another projector',
        tone: FieldHelpTone.success,
      ),
      IpCheck.taken => const FieldHelp(
        'Already used by another projector',
        tone: FieldHelpTone.error,
      ),
      IpCheck.invalid => const FieldHelp(
        'Not a valid IP address',
        tone: FieldHelpTone.error,
      ),
      IpCheck.empty => const FieldHelp(
        'Enter an IP address',
        tone: FieldHelpTone.error,
      ),
    };
    final ipError = check != IpCheck.unchanged && check != IpCheck.free;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledField(
            label: 'IP address',
            help: ipHelp,
            child: TextField(
              key: const ValueKey('edit-ip'),
              controller: _ip,
              autofocus: !_openedOnWrongLogin,
              style: monoFieldStyle,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: formFieldDecoration(context, error: ipError),
              onSubmitted: (_) => _save(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 110,
          child: PortField(controller: _port, onSubmitted: _save),
        ),
      ],
    );
  }
}
