import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../providers/active_alerts_request_provider.dart';
import '../../providers/workspace_provider.dart';
import '../custom_tooltip.dart';
import '../monitoring/monitoring_actions.dart';

/// A row's hover actions (plan §7k.2), laid over the row's right end on
/// their own fill so the text and pills under them don't show through.
class EventLogRowActions extends StatelessWidget {
  const EventLogRowActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.windowBackground(Theme.of(context).colorScheme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: children,
      ),
    );
  }
}

/// The short text button of a hover action, as Monitoring's rows have:
/// *Locate*, *Open alerts*, *Retry failed*.
class EventLogTextAction extends StatelessWidget {
  const EventLogTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 28),
      fixedSize: const Size.fromHeight(28),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: t.description.copyWith(fontWeight: FontWeight.w500),
    );
    final icon = this.icon;
    if (icon == null) {
      return TextButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// *Locate*: switches to Controls, selects the projector's card and
/// scrolls to it. The row knows the IP, not the id, so the projector is
/// looked up by IP; the button is gone once the projector is.
class EventLogLocateButton extends ConsumerWidget {
  const EventLogLocateButton({super.key, required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeId = ref.watch(
      workspaceProvider.select(
        (nodes) => nodes.where((n) => n.ipAddress == ip).firstOrNull?.id,
      ),
    );
    if (nodeId == null) return const SizedBox.shrink();
    return EventLogTextAction(
      key: const ValueKey('event-log-locate'),
      icon: Icons.my_location,
      label: 'Locate',
      onPressed: () => findOnCanvas(
        ProviderScope.containerOf(context, listen: false),
        nodeId,
      ),
    );
  }
}

/// *Open alerts* on an alert row: the status bar's Active alerts panel.
class EventLogOpenAlertsButton extends ConsumerWidget {
  const EventLogOpenAlertsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => EventLogTextAction(
    key: const ValueKey('event-log-open-alerts'),
    icon: Icons.notifications_none,
    label: 'Open alerts',
    onPressed: () => ref.read(activeAlertsRequestProvider.notifier).open(),
  );
}

/// *Copy row*: the row as Copy writes it, its lines too. A check shows for
/// a second instead of a SnackBar, as on the header's Copy.
class EventLogCopyRowButton extends StatefulWidget {
  const EventLogCopyRowButton({super.key, required this.text});

  /// Built on click: only the hovered row's text is ever needed.
  final String Function() text;

  @override
  State<EventLogCopyRowButton> createState() => _EventLogCopyRowButtonState();
}

class _EventLogCopyRowButtonState extends State<EventLogCopyRowButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text()));
    _timer?.cancel();
    setState(() => _copied = true);
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomTooltip(
      message: _copied ? 'Copied' : 'Copy row',
      child: IconButton(
        key: const ValueKey('event-log-copy-row'),
        icon: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 16),
        color: AppText.of(context).secondary,
        onPressed: _copy,
        padding: EdgeInsets.zero,
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      ),
    );
  }
}
