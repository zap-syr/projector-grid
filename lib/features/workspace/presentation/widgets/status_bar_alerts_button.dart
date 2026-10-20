import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/active_alerts_request_provider.dart';
import '../providers/alert_counts_provider.dart';
import 'active_alerts_panel.dart';
import 'anchored_panel_layout.dart';
import 'common/severity_pill.dart';
import 'status_bar_item.dart';

/// The status bar's Alerts item (plan §7l.3): a [SeverityPill] per
/// severity, filled with the unacknowledged count or, once all are
/// acknowledged, outlined with the active total; a green pill for the
/// alerts that are over but unacknowledged; *None* with an outlined green
/// check when nothing is active. Clicking opens Active alerts, and the item
/// stays pressed while it is open.
class StatusBarAlertsButton extends ConsumerStatefulWidget {
  const StatusBarAlertsButton({super.key, this.narrow = false});

  /// Pills only, without the word *Alerts*.
  final bool narrow;

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
    final t = AppText.of(context);
    final counts = ref.watch(alertCountsProvider);

    // Unacknowledged ones filled with their count; once all are
    // acknowledged, outlined with the active total.
    Widget? pill(SeverityPillKind kind, int open, int total) {
      if (total == 0) return null;
      final fresh = open > 0;
      return SeverityPill(
        kind: kind,
        count: fresh ? open : total,
        filled: fresh,
      );
    }

    final none =
        counts.criticalTotal + counts.warningTotal + counts.recovered == 0;
    final narrow = widget.narrow;

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
        child: StatusBarItem(
          key: const ValueKey('status-alerts'),
          narrow: narrow,
          onTap: _toggle,
          pressed: _portal.isShowing,
          tooltip: narrow ? (none ? 'No active alerts' : 'Alerts') : null,
          semanticLabel: 'Alerts',
          children: [
            if (!narrow) const Text('Alerts'),
            if (none)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: SeverityPill.colorOf(
                      context,
                      SeverityPillKind.recovered,
                    ),
                  ),
                  if (!narrow)
                    Text(
                      'None',
                      style: t.description.copyWith(
                        color: t.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              )
            else
              // Null rather than an empty box: Row.spacing also pads
              // zero-width children, which would shift the pills.
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  ?pill(
                    SeverityPillKind.critical,
                    counts.critical,
                    counts.criticalTotal,
                  ),
                  ?pill(
                    SeverityPillKind.warning,
                    counts.warning,
                    counts.warningTotal,
                  ),
                  // Over, waiting to be acknowledged.
                  if (counts.recovered > 0)
                    SeverityPill(
                      kind: SeverityPillKind.recovered,
                      count: counts.recovered,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
