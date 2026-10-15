import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/projector_node.dart';
import '../common/dialog_parts.dart';
import '../common/scroll_fade.dart';
import '../common/status_pill.dart';

/// One answer of `PanasonicProtocolService.scanNetwork`.
class DiscoveredProjector {
  const DiscoveredProjector({
    required this.ip,
    required this.name,
    required this.status,
  });

  /// The scan reports `online`, `unprotected` or `auth_error`.
  factory DiscoveredProjector.fromScan(Map<String, dynamic> result) =>
      DiscoveredProjector(
        ip: result['ip'] as String,
        name: result['name'] as String,
        status: switch (result['status']) {
          'online' => ConnectionStatus.connected,
          'unprotected' => ConnectionStatus.unprotected,
          _ => ConnectionStatus.unauthorized,
        },
      );

  final String ip;

  /// The model, or the IP when the projector refused the login before
  /// saying it.
  final String name;
  final ConnectionStatus status;

  bool get modelKnown => name != ip;
}

extension DiscoveredStatus on ConnectionStatus {
  /// Back to the scan's word, which `addProjectors` reads.
  String get scanStatus => switch (this) {
    ConnectionStatus.connected => 'online',
    ConnectionStatus.unprotected => 'unprotected',
    _ => 'auth_error',
  };
}

const _checkCol = 44.0;
const _ipCol = 150.0;
const _statusCol = 130.0;

/// Discover's results card: what the sweep found so far, with a checkbox
/// per projector that isn't in the project yet.
class DiscoverResults extends StatelessWidget {
  const DiscoverResults({
    super.key,
    required this.subnet,
    required this.scanning,
    required this.found,
    required this.existingIps,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  /// `192.168.0` of the running or last scan, null before the first.
  final String? subnet;
  final bool scanning;
  final List<DiscoveredProjector> found;
  final Set<String> existingIps;
  final Set<String> selected;
  final void Function(String ip, bool on) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final newIps = [
      for (final p in found)
        if (!existingIps.contains(p.ip)) p.ip,
    ];
    final allSelected = newIps.isNotEmpty && selected.length == newIps.length;
    final muted = TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant);
    final count = found.length;
    final headline = switch ((scanning, count)) {
      _ when subnet == null => 'Not scanned yet',
      (true, 0) => 'Scanning',
      (false, 0) => 'No projectors found',
      (_, 1) => '1 projector found',
      _ => '$count projectors found',
    };
    return DialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (scanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    count > 0 ? Icons.check : Icons.search_off,
                    size: 18,
                    color: count > 0
                        ? AppStatusColors.of(context).success
                        : cs.onSurfaceVariant,
                  ),
                const SizedBox(width: 10),
                Text(
                  headline,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: subnet == null
                      ? const SizedBox.shrink()
                      : Text(
                          'on $subnet.0/24',
                          style: muted,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (subnet != null && !scanning)
                  Text('Scan complete', style: muted)
                else if (scanning && count > 0)
                  Text('Scanning', style: muted),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child: scanning
                ? const LinearProgressIndicator(minHeight: 2)
                : Divider(height: 2, color: cs.outlineVariant),
          ),
          _HeaderRow(
            allSelected: allSelected,
            someSelected: selected.isNotEmpty,
            enabled: newIps.isNotEmpty,
            onToggleAll: onToggleAll,
          ),
          Expanded(
            child: ScrollFade(
              child: ListView.builder(
                itemCount: found.length,
                itemBuilder: (context, i) {
                  final p = found[i];
                  final inProject = existingIps.contains(p.ip);
                  return _ResultRow(
                    projector: p,
                    inProject: inProject,
                    selected: selected.contains(p.ip),
                    onToggle: inProject ? null : (on) => onToggle(p.ip, on),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.allSelected,
    required this.someSelected,
    required this.enabled,
    required this.onToggleAll,
  });

  final bool allSelected;
  final bool someSelected;
  final bool enabled;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _checkCol,
            child: Checkbox(
              tristate: true,
              visualDensity: VisualDensity.compact,
              value: allSelected ? true : (someSelected ? null : false),
              onChanged: enabled ? (_) => onToggleAll(!allSelected) : null,
            ),
          ),
          Expanded(child: Text('Projector', style: style)),
          SizedBox(
            width: _ipCol,
            child: Text('IP address', style: style),
          ),
          SizedBox(
            width: _statusCol,
            child: Text('Status', style: style),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.projector,
    required this.inProject,
    required this.selected,
    required this.onToggle,
  });

  final DiscoveredProjector projector;
  final bool inProject;
  final bool selected;

  /// Null for a projector already in the project.
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurfaceVariant.withValues(alpha: 0.6);
    final p = projector;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onToggle == null ? null : () => onToggle!(!selected),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _checkCol,
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: !inProject && selected,
                  onChanged: onToggle == null
                      ? null
                      : (v) => onToggle!(v ?? false),
                ),
              ),
              Expanded(
                child: Text(
                  p.modelKnown ? p.name : 'Model unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: inProject || !p.modelKnown
                        ? FontWeight.w400
                        : FontWeight.w500,
                    color: inProject || !p.modelKnown ? dim : null,
                  ),
                ),
              ),
              SizedBox(
                width: _ipCol,
                child: Text(
                  p.ip,
                  style: AppTheme.mono(
                    TextStyle(fontSize: 13, color: inProject ? dim : null),
                  ),
                ),
              ),
              SizedBox(
                width: _statusCol,
                // Shrinks a badge rather than overflow where a font runs wide.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: inProject
                      ? StatusPill(
                          label: 'In project',
                          color: cs.onSurfaceVariant,
                        )
                      : ConnectionStatusBadge(status: p.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
