import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/status_thresholds.dart';
import '../../../domain/alert_rule.dart';
import '../../../domain/monitoring_format.dart';
import '../../../domain/monitoring_status.dart';
import '../../../domain/projector_group.dart';
import '../../../domain/projector_node.dart';
import '../../../domain/test_patterns.dart';
import '../common/dialog_parts.dart';
import '../common/status_pill.dart';
import '../common/test_pattern_thumb.dart';
import '../custom_tooltip.dart';
import '../projector_status_style.dart';

/// The pieces the Monitoring table, cards and projector panel share, so a
/// value reads the same in all three.

/// The connection dot before a projector's IP: green online, amber for a
/// failed login, grey offline.
class MonitoringStatusDot extends StatelessWidget {
  const MonitoringStatusDot({super.key, required this.status, this.size = 8});

  final ConnectionStatus status;
  final double size;

  static Color colorOf(BuildContext context, ConnectionStatus status) =>
      switch (status) {
        ConnectionStatus.connected ||
        ConnectionStatus.unprotected => AppStatusColors.of(context).success,
        ConnectionStatus.unauthorized => AppStatusColors.of(context).warning,
        ConnectionStatus.offline => Theme.of(context).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colorOf(context, status),
      shape: BoxShape.circle,
    ),
  );
}

/// The accent colour of a problem level: amber, red, grey; null for none.
Color? problemColor(BuildContext context, ProblemLevel level) =>
    switch (level) {
      ProblemLevel.none => null,
      ProblemLevel.warning => AppStatusColors.of(context).warning,
      ProblemLevel.error => Theme.of(context).colorScheme.error,
      ProblemLevel.offline => Theme.of(context).colorScheme.outline,
    };

/// Power as icon + word, in the canvas card's colours: green on, amber
/// while warming up or cooling, red in standby.
class PowerState extends StatelessWidget {
  const PowerState({super.key, required this.power});

  final PowerStatus power;

  @override
  Widget build(BuildContext context) => _IconWord(
    icon: Icons.power_settings_new,
    color: ProjectorStatusStyle.of(context).powerColor(power),
    label: powerLabel(power),
  );
}

/// Shutter as icon + word, in the canvas card's colours: green open, red
/// closed, grey in standby, where it shows nothing either way.
class ShutterState extends StatelessWidget {
  const ShutterState({super.key, required this.node});

  final ProjectorNode node;

  @override
  Widget build(BuildContext context) {
    final open = node.shutterStatus == ShutterStatus.open;
    return _IconWord(
      icon: open ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: ProjectorStatusStyle.of(context).shutterColor(node),
      label: shutterLabel(node.shutterStatus),
    );
  }
}

class _IconWord extends StatelessWidget {
  const _IconWord({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.of(context).body.copyWith(color: color),
        ),
      ),
    ],
  );
}

/// The worst problem as a pill (`Exhaust hot`, `Error F305`, `Offline`),
/// with `+2` after it when there are more; `None` when there are none.
class ProblemBadge extends StatelessWidget {
  const ProblemBadge({super.key, required this.problems});

  final List<MonitoringProblem> problems;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    if (problems.isEmpty) {
      return Text('None', style: t.body.copyWith(color: t.tertiary));
    }
    final first = problems.first;
    final more = problems.length - 1;
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FitPill(child: ProblemPill(problem: first)),
        ),
        if (more > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$more',
            style: t.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
    if (more == 0) return badge;
    return CustomTooltip(
      message: first.badge,
      detail: [for (final p in problems.skip(1)) p.badge].join(', '),
      child: badge,
    );
  }
}

class ProblemPill extends StatelessWidget {
  const ProblemPill({super.key, required this.problem});

  final MonitoringProblem problem;

  @override
  Widget build(BuildContext context) {
    final color = problemColor(context, problem.level)!;
    return StatusPill(
      label: problem.badge,
      color: color,
      icon: switch (problem.level) {
        ProblemLevel.error => Icons.error_outline,
        ProblemLevel.warning => Icons.warning_amber_rounded,
        ProblemLevel.offline || ProblemLevel.none => null,
      },
      dot: problem.level == ProblemLevel.offline,
    );
  }
}

/// A group's colour square (rounded, like the group rows) or a hollow one
/// for Ungrouped.
class GroupSwatch extends StatelessWidget {
  const GroupSwatch({super.key, required this.group, this.size = 10});

  final ProjectorGroup? group;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: g == null ? null : Color(g.color),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: g == null ? Border.all(color: outline, width: 1.5) : null,
      ),
    );
  }
}

/// A thin bar for a temperature: grey, amber or red with its alert.
/// [mark] draws the warning threshold as a tick across it.
class TemperatureBar extends StatelessWidget {
  const TemperatureBar({
    super.key,
    required this.fraction,
    required this.severity,
    this.width,
    this.height = 4,
    this.mark,
  });

  final double? fraction;
  final AlertSeverity? severity;
  final double? width;
  final double height;
  final double? mark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = switch (severity) {
      AlertSeverity.critical => cs.error,
      AlertSeverity.warning => AppStatusColors.of(context).warning,
      null => cs.outline,
    };
    final markColor = AppStatusColors.of(context).warning;
    return SizedBox(
      width: width,
      height: mark == null ? height : height + 6,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final top = mark == null ? 0.0 : 3.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: top,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DialogSurfaces.of(context).soft,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              if (fraction case final f?)
                Positioned(
                  left: 0,
                  top: top,
                  height: height,
                  width: w * f,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              if (mark case final m?)
                Positioned(
                  left: (w * m - 1).clamp(0.0, w - 2),
                  top: 0,
                  width: 2,
                  height: height + 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: markColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One line of the table's Temperature cell: `In  25 °C  ▬▬▬`.
class TemperatureLine extends StatelessWidget {
  const TemperatureLine({
    super.key,
    required this.label,
    required this.display,
    required this.threshold,
    required this.severity,
  });

  final String label;
  final String display;
  final TempThreshold threshold;
  final AlertSeverity? severity;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final color = temperatureColor(context, severity);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: t.caption,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            withUnit(display),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: t.description.copyWith(
              color: color ?? t.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 6),
        TemperatureBar(
          width: 40,
          fraction: temperatureFraction(display, threshold),
          severity: severity,
        ),
      ],
    );
  }
}

/// Amber or red text for a temperature with an alert, null otherwise.
Color? temperatureColor(BuildContext context, AlertSeverity? severity) =>
    switch (severity) {
      AlertSeverity.critical => Theme.of(context).colorScheme.error,
      AlertSeverity.warning => AppStatusColors.of(context).warning,
      null => null,
    };

/// Text that shows its full contents in a tooltip only when it is cut off.
class TruncatedText extends StatelessWidget {
  const TruncatedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? AppText.of(context).body;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final cut = painter.didExceedMaxLines;
        painter.dispose();
        final label = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        return cut ? CustomTooltip(message: text, child: label) : label;
      },
    );
  }
}

/// A pill that shrinks rather than overflows when its cell or card is too
/// narrow for it (a long resolution in a narrow column).
class FitPill extends StatelessWidget {
  const FitPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: child,
  );
}

/// The test pattern by name, after its thumbnail while one is showing; Off
/// and not polled yet (`-`) are the text alone. The table's cell and the
/// panel's row.
class TestPatternName extends StatelessWidget {
  const TestPatternName({super.key, required this.node, this.style});

  final ProjectorNode node;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final code = node.testPattern;
    final label = TruncatedText(
      code == null ? '-' : testPatternLabel(code),
      style: style,
    );
    if (!isTestPatternActive(code)) return label;
    return Row(
      key: const ValueKey('test-pattern-name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TestPatternThumb(code: code!),
        const SizedBox(width: 6),
        Flexible(child: label),
      ],
    );
  }
}

/// A neutral rounded chip with a coloured icon: the cards' Power and
/// Shutter.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: DialogSurfaces.of(context).soft,
      borderRadius: BorderRadius.circular(13),
    ),
    child: child,
  );
}
