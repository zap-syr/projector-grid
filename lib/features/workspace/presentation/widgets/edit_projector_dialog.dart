import 'package:flutter/material.dart';
import '../../domain/projector_node.dart';

class EditProjectorDialog extends StatefulWidget {
  final ProjectorNode node;
  final Function(String ip, String login, String password) onSave;

  const EditProjectorDialog({super.key, required this.node, required this.onSave});

  @override
  State<EditProjectorDialog> createState() => _EditProjectorDialogState();
}

class _EditProjectorDialogState extends State<EditProjectorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ipController;
  late TextEditingController _loginController;
  late TextEditingController _passwordController;

  final _ipRegex = RegExp(r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.node.ipAddress);
    _loginController = TextEditingController(text: widget.node.login);
    _passwordController = TextEditingController(text: widget.node.password);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(_ipController.text, _loginController.text, _passwordController.text);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Projector', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'IP Address', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'IP Address is required';
                  if (!_ipRegex.hasMatch(val)) return 'Invalid IP Address format';
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
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
