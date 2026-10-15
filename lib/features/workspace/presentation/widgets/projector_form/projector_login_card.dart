import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'form_parts.dart';

const _loginHint = 'Sent only if the projector is in protected mode';

/// Projector login of Add Projectors and Edit Projector. There is no
/// "protected" switch: the projector says whether it wants a login when the
/// app connects, so the fields are always there and optional.
class ProjectorLoginCard extends StatelessWidget {
  const ProjectorLoginCard({
    super.key,
    required this.login,
    required this.password,
    this.lastUsed = false,
    this.wrongLogin = false,
    this.autofocusLogin = false,
    this.onSubmitted,
  });

  final TextEditingController login;
  final TextEditingController password;

  /// The fields still hold the login saved from the last add.
  final bool lastUsed;

  /// The projector rejected this login: warning border and a note.
  final bool wrongLogin;
  final bool autofocusLogin;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = AppStatusColors.of(context);
    final muted = TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant);
    return FormCard(
      borderColor: wrongLogin ? sc.warning.withValues(alpha: 0.7) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const FormIconTile(Icons.lock_outline),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Projector login',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(_loginHint, style: muted),
                    ],
                  ),
                ),
                if (lastUsed) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.history, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text('Last used', style: muted.copyWith(fontSize: 12)),
                ],
                const SizedBox(width: 12),
                const _OptionalPill(),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Login',
                    child: TextField(
                      key: const ValueKey('projector-login'),
                      controller: login,
                      autofocus: autofocusLogin,
                      style: plainFieldStyle,
                      decoration: formFieldDecoration(context),
                      onSubmitted: (_) => onSubmitted?.call(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledField(
                    label: 'Password',
                    child: PasswordField(
                      controller: password,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (wrongLogin)
            Container(
              color: sc.warningContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: sc.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The projector rejected this login. '
                      'Check the login and password.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: sc.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Discover's one-row variant: the label goes inside each narrow field.
class CompactProjectorLogin extends StatelessWidget {
  const CompactProjectorLogin({
    super.key,
    required this.login,
    required this.password,
    this.lastUsed = false,
  });

  final TextEditingController login;
  final TextEditingController password;
  final bool lastUsed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget inner(String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
    );
    return FormCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          const FormIconTile(Icons.lock_outline, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Projector login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  lastUsed ? 'Last used, optional' : 'Optional',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: TextField(
                key: const ValueKey('projector-login'),
                controller: login,
                style: plainFieldStyle,
                decoration: formFieldDecoration(
                  context,
                  prefix: inner('Login'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: PasswordField(
                controller: password,
                prefix: inner('Password'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A password field, hidden until the eye button shows it.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.prefix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Widget? prefix;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      key: const ValueKey('projector-password'),
      controller: widget.controller,
      obscureText: !_visible,
      style: plainFieldStyle,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: formFieldDecoration(
        context,
        prefix: widget.prefix,
        suffixIcon: IconButton(
          tooltip: _visible ? 'Hide password' : 'Show password',
          iconSize: 18,
          color: cs.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

class _OptionalPill extends StatelessWidget {
  const _OptionalPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FormSurfaces.of(context).soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        'Optional',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
