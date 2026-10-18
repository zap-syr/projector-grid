import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/workspace_provider.dart';
import 'common/status_pill.dart';

/// The title bar every dialog in the app uses: an icon tile, a title and a
/// close (✕) button — the one dismiss affordance across the app, replacing
/// the mix of a bottom "Close" text button some dialogs used and a corner ✕
/// others did.
///
/// Deliberately carries no other controls: an "Add"/action button here would
/// sit right next to ✕, inviting mis-clicks between "do something" and
/// "close everything". Dialogs that need one put it near what it acts on
/// instead (e.g. a footer button under a list). Read-only information (the
/// projector a dialog was opened for, its group and status) is fine.
///
/// Includes the divider beneath it; callers just drop this in as the first
/// child of their dialog's content column.
class DialogTitleBar extends StatelessWidget {
  const DialogTitleBar({
    super.key,
    required this.icon,
    required this.title,
    this.onClose,
    this.projectorId,
    this.pairIds,
    this.subtitle,
    this.badges = const [],
  });

  final IconData icon;
  final String title;

  /// Defaults to popping the current route. Override when closing needs a
  /// side effect first (e.g. a warning that a setting stays active).
  final VoidCallback? onClose;

  /// The projector a per-projector dialog was opened for: its model + IP go
  /// under the title, its group pill and connection badge before ✕, kept
  /// live while the dialog is open.
  final String? projectorId;

  /// The two projectors of a pair (Edge Blending): `Pair: RQ25K
  /// (192.168.0.41), RQ25K (192.168.0.42)` under the title and their group
  /// pill when both are in the same group, kept live. The status is the
  /// dialog's to say (whether each one replies to it), so it goes in
  /// [badges]. Ignored when [projectorId] is set.
  final (String, String)? pairIds;

  /// Monospace line under the title for dialogs that span several projectors
  /// (a grid); ignored when [projectorId] or [pairIds] is set.
  final String? subtitle;

  /// Read-only pills before ✕ for the multi-projector cases.
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.of(context).dialogTitle,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: cs.surfaceContainerHigh,
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: projectorId != null
                    ? _ProjectorInfo(id: projectorId!, title: titleText)
                    : pairIds != null
                    ? _PairInfo(ids: pairIds!, title: titleText, badges: badges)
                    : Row(
                        children: [
                          Expanded(
                            child: _TitleBlock(
                              title: titleText,
                              subtitle: subtitle,
                            ),
                          ),
                          for (final b in badges) ...[
                            const SizedBox(width: 8),
                            b,
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  color: cs.onSurfaceVariant,
                  tooltip: 'Close',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, this.subtitle});

  final Widget title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (subtitle == null) return title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.of(context).monoSmall.copyWith(height: 1.25),
        ),
      ],
    );
  }
}

/// Watches only the fields the bar shows, so a polling tick that changes a
/// temperature doesn't rebuild it.
class _ProjectorInfo extends ConsumerWidget {
  const _ProjectorInfo({required this.id, required this.title});

  final String id;
  final Widget title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(workspaceProvider.notifier);
    final info = ref.watch(
      workspaceProvider.select((nodes) {
        final node = nodes.where((n) => n.id == id).firstOrNull;
        if (node == null) return null;
        final group = notifier.groups
            .where((g) => g.id == node.groupId)
            .firstOrNull;
        return (
          model: node.name,
          ip: node.ipAddress,
          groupName: group?.name,
          groupColor: group?.color,
          status: node.connectionStatus,
        );
      }),
    );
    if (info == null) return title;
    return Row(
      children: [
        Expanded(
          child: _TitleBlock(
            title: title,
            subtitle: projectorLabel(info.model, info.ip),
          ),
        ),
        // Not Flexible: next to the Expanded title it would take half the
        // bar and leave the pills short of ✕. The pill caps its own width.
        if (info.groupName != null) ...[
          const SizedBox(width: 8),
          GroupPill(name: info.groupName!, color: Color(info.groupColor!)),
        ],
        const SizedBox(width: 8),
        ConnectionStatusBadge(status: info.status),
      ],
    );
  }
}

/// A pair's line and shared group, watched like [_ProjectorInfo].
class _PairInfo extends ConsumerWidget {
  const _PairInfo({
    required this.ids,
    required this.title,
    required this.badges,
  });

  final (String, String) ids;
  final Widget title;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(workspaceProvider.notifier);
    final info = ref.watch(
      workspaceProvider.select((nodes) {
        final a = nodes.where((n) => n.id == ids.$1).firstOrNull;
        final b = nodes.where((n) => n.id == ids.$2).firstOrNull;
        if (a == null || b == null) return null;
        final group = a.groupId == b.groupId
            ? notifier.groups.where((g) => g.id == a.groupId).firstOrNull
            : null;
        return (
          a: projectorLabel(a.name, a.ipAddress),
          b: projectorLabel(b.name, b.ipAddress),
          groupName: group?.name,
          groupColor: group?.color,
        );
      }),
    );
    return Row(
      children: [
        Expanded(
          child: _TitleBlock(
            title: title,
            subtitle: info == null ? null : 'Pair: ${info.a}, ${info.b}',
          ),
        ),
        if (info?.groupName != null) ...[
          const SizedBox(width: 8),
          GroupPill(name: info!.groupName!, color: Color(info.groupColor!)),
        ],
        for (final b in badges) ...[const SizedBox(width: 8), b],
      ],
    );
  }
}

/// `RZ34K (192.168.0.41)`: how a dialog names one projector. The model
/// alone repeats across a rig, so the IP always goes with it.
String projectorLabel(String model, String ip) =>
    model.isEmpty || model == ip ? ip : '$model ($ip)';
