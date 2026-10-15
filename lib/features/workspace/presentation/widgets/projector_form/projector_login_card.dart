import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../common/dialog_parts.dart';

const _loginHint = 'Sent only if the projector is in protected mode';

// The heading row (lock tile, title, subtitle) is the same height in the
// full card and in Discover's one-row card, field-high with the same
// padding, so switching tabs moves neither the card's text nor what is
// under it.
// 12 + 40 + 12 + borders = 66: 8 px over the one-row card's old 58, which
// the 8 px smaller gap above it gives back, so Discover's list keeps its
// height.
const _headingPadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

class _LoginHeading extends StatelessWidget {
  const _LoginHeading({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const DialogIconTile(Icons.lock_outline),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Projector login',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    return DialogCard(
      borderColor: wrongLogin ? sc.warning.withValues(alpha: 0.7) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: _headingPadding,
            child: SizedBox(
              height: dialogFieldHeight,
              child: Row(
                children: [
                  const Expanded(child: _LoginHeading(subtitle: _loginHint)),
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
                    child: LoginField(
                      controller: login,
                      autofocus: autofocusLogin,
                      onSubmitted: onSubmitted,
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
    return DialogCard(
      child: Padding(
        padding: _headingPadding,
        child: SizedBox(
          height: dialogFieldHeight,
          child: Row(
            children: [
              Expanded(
                child: _LoginHeading(
                  subtitle: lastUsed ? 'Last used, optional' : 'Optional',
                ),
              ),
              const SizedBox(width: 12),
              // No labels in these narrow fields: a hint names each one
              // until it takes focus. Fixed widths, the heading takes the
              // rest: Flexible fields left their unused share empty at the
              // right, so Password stopped short of the card's padding.
              SizedBox(
                width: 180,
                child: LoginField(controller: login, hintText: 'Login'),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 200,
                child: PasswordField(
                  controller: password,
                  hintText: 'Password',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The login field: a ✕ inside clears it, since it comes prefilled with
/// the last used login and a projector without protection needs none.
class LoginField extends StatefulWidget {
  const LoginField({
    super.key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Names the field while it is empty and not focused (Discover, where
  /// the fields have no label above them).
  final String? hintText;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> with _FocusHint {
  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('projector-login'),
      controller: widget.controller,
      focusNode: focusNode,
      autofocus: widget.autofocus,
      style: plainFieldStyle,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: dialogFieldDecoration(
        context,
        hintText: hintFor(widget.hintText),
        suffixIcon: _FieldActions(
          children: [
            _ClearButton(
              key: const ValueKey('clear-login'),
              controller: widget.controller,
              tooltip: 'Clear login',
            ),
          ],
        ),
      ),
    );
  }
}

/// A password field, hidden until the eye button shows it, with the same
/// ✕ as [LoginField].
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> with _FocusHint {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      key: const ValueKey('projector-password'),
      controller: widget.controller,
      focusNode: focusNode,
      obscureText: !_visible,
      style: plainFieldStyle,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: dialogFieldDecoration(
        context,
        hintText: hintFor(widget.hintText),
        suffixIcon: _FieldActions(
          children: [
            _ClearButton(
              key: const ValueKey('clear-password'),
              controller: widget.controller,
              tooltip: 'Clear password',
            ),
            _SmallIconButton(
              tooltip: _visible ? 'Hide password' : 'Show password',
              icon: _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: cs.onSurfaceVariant,
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ],
        ),
      ),
    );
  }
}

/// The field's own focus node, and its hint shown only while unfocused: a
/// hint here names the field, so it goes as soon as the user is in it.
mixin _FocusHint<T extends StatefulWidget> on State<T> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  String? hintFor(String? hint) => focusNode.hasFocus ? null : hint;
}

/// The buttons at the end of a field, in a fixed-width row so the ✕
/// appearing or going never changes the field's text area.
class _FieldActions extends StatelessWidget {
  const _FieldActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// ✕ that empties [controller]; keeps its place while the field is empty.
class _ClearButton extends StatelessWidget {
  const _ClearButton({
    super.key,
    required this.controller,
    required this.tooltip,
  });

  final TextEditingController controller;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Visibility(
        visible: controller.text.isNotEmpty,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: _SmallIconButton(
          tooltip: tooltip,
          icon: Icons.close,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          onPressed: controller.clear,
        ),
      ),
    );
  }
}

/// 28 px, so it stays inside the field's 40 px: the default tap target
/// would make the field taller than the others.
class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 17,
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      icon: Icon(icon),
      onPressed: onPressed,
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
        color: DialogSurfaces.of(context).soft,
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
