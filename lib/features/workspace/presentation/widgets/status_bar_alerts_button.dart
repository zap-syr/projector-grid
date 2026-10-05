import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/alert_rule.dart';
import '../providers/active_alerts_request_provider.dart';
import '../providers/alert_counts_provider.dart';
import 'active_alerts_panel.dart';
import 'alert_row.dart';
import 'anchored_panel_layout.dart';

/// The status bar's Alerts counter: per severity, the unacknowledged count
/// with a filled icon, or once all are acknowledged the active total with
/// an outlined one; a filled green check with the alerts that are over but
/// unacknowledged; an outlined green check when nothing is active. Clicking
/// opens Active alerts.
class StatusBarAlertsButton extends ConsumerStatefulWidget {
  const StatusBarAlertsButton({super.key});

  @override
  ConsumerState<StatusBarAlertsButton> createState() =>
      _StatusBarAlertsButtonState();
}

class _StatusBarAlertsButtonState extends ConsumerState<StatusBarAlertsButton> {
  final _portal = OverlayPortalController();
  final _panelFocus = FocusNode();
  final _tapGroup = Object();

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  void _toggle() => _portal.isShowing ? _hide() : _show();

  void _show() {
    if (!_portal.isShowing) setState(_portal.show);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_portal.isShowing) _panelFocus.requestFocus();
    });
  }

  void _hide() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    // A clicked desktop notification opens the panel.
    ref.listen(activeAlertsRequestProvider, (_, _) => _show());
    final theme = Theme.of(context);
    final counts = ref.watch(alertCountsProvider);
    final style = theme.textTheme.bodySmall;

    Widget count(AlertSeverity s, int open, int total) {
      if (total == 0) return const SizedBox.shrink();
      final fresh = open > 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(
            AlertPalette.iconData(s, filled: fresh),
            size: 14,
            color: AlertPalette.icon(s),
          ),
          Text(
            '${fresh ? open : total}',
            style: style?.copyWith(
              fontWeight: fresh ? FontWeight.w600 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }

    final none =
        counts.criticalTotal + counts.warningTotal + counts.recovered == 0;

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (_, info) => CustomSingleChildLayout(
        delegate: AnchoredPanelLayout(
          anchor: MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
          width: ActiveAlertsPanel.width,
          flip: false,
        ),
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _hide(),
          child: Focus(
            focusNode: _panelFocus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _hide();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const ActiveAlertsPanel(),
          ),
        ),
      ),
      child: TapRegion(
        groupId: _tapGroup,
        child: Semantics(
          button: true,
          label: 'Alerts',
          // Its own Material: the status bar's coloured container would
          // otherwise hide the hover, which the InkWell paints on the
          // nearest Material below it.
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(6),
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _portal.isShowing
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Text('Alerts', style: style),
                    if (none)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Colors.green,
                          ),
                          Text(
                            '0',
                            style: style?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      count(
                        AlertSeverity.critical,
                        counts.critical,
                        counts.criticalTotal,
                      ),
                      count(
                        AlertSeverity.warning,
                        counts.warning,
                        counts.warningTotal,
                      ),
                      // Over, waiting to be acknowledged.
                      if (counts.recovered > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AlertPalette.recoveredIcon,
                            ),
                            Text(
                              '${counts.recovered}',
                              style: style?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
