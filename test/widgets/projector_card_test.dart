import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/alert_rule.dart';
import 'package:projector_grid/features/workspace/domain/alerts.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alerts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_card.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_status_style.dart';

import '../helpers/test_config_dir.dart';

/// Alerts the test sets directly instead of evaluating the workspace.
class _FakeAlerts extends AlertsNotifier {
  @override
  Map<AlertKey, ActiveAlert> build() => {};

  void setAll(List<ActiveAlert> alerts) =>
      state = {for (final a in alerts) a.key: a};
}

const _group = ProjectorGroup(id: 'g', name: 'Main screen', color: 0xFF5B8DEF);

ProjectorNode _node({
  PowerStatus power = PowerStatus.on,
  ShutterStatus shutter = ShutterStatus.open,
  ConnectionStatus connection = ConnectionStatus.connected,
}) => ProjectorNode(
  id: '1',
  name: 'PT-RZ120',
  ipAddress: '10.0.1.52',
  x: 40,
  y: 40,
  powerStatus: power,
  shutterStatus: shutter,
  connectionStatus: connection,
);

void main() {
  useTempConfigDir();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    ProjectorNode node, {
    ProjectorGroup? group,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [alertsProvider.overrideWith(_FakeAlerts.new)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                ProjectorCard(
                  node: node,
                  group: group,
                  dragOverrides: ValueNotifier(const {}),
                  zoom: 1,
                  onTap: () {},
                  onPanDown: (_) {},
                  onPanUpdate: (_) {},
                  onPanEnd: (_) {},
                  onEdit: () {},
                  onQuickStatus: () {},
                  onDelete: () {},
                  onColorCorrection: () {},
                  onBrightnessControl: () {},
                  onGeometryCorrection: () {},
                  onEdgeBlending: () {},
                  onRemotePreview: () {},
                  onSelectGroup: null,
                  buildGroupMenuItems: () => [],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(ProjectorCard)),
    );
  }

  BuildContext cardContext(WidgetTester tester) =>
      tester.element(find.byType(ProjectorCard));

  Color headerColor(WidgetTester tester) {
    final header = tester.widget<Container>(
      find.byKey(const ValueKey('card-header')),
    );
    return (header.decoration! as BoxDecoration).color!;
  }

  Color iconColor(WidgetTester tester, String key) =>
      tester.widget<Icon>(find.byKey(ValueKey(key))).color!;

  IconData iconData(WidgetTester tester, String key) =>
      tester.widget<Icon>(find.byKey(ValueKey(key))).icon!;

  Border cardBorder(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('card-border')),
    );
    return (box.decoration as BoxDecoration).border! as Border;
  }

  group('header tint and icons per state', () {
    final cases = <String, (ProjectorNode, CardHeaderTone)>{
      'on, shutter open': (_node(), CardHeaderTone.on),
      'on, shutter closed': (
        _node(shutter: ShutterStatus.closed),
        CardHeaderTone.on,
      ),
      'warming up': (
        _node(power: PowerStatus.turningOn, shutter: ShutterStatus.closed),
        CardHeaderTone.transition,
      ),
      'standby': (
        _node(power: PowerStatus.standby, shutter: ShutterStatus.closed),
        CardHeaderTone.standby,
      ),
    };
    for (final MapEntry(key: name, value: (node, tone)) in cases.entries) {
      testWidgets(name, (tester) async {
        await pump(tester, node);
        final context = cardContext(tester);
        final style = ProjectorStatusStyle.of(context);
        final cs = Theme.of(context).colorScheme;
        final base = projectorCardFill(cs).top;
        expect(cardHeaderTone(node), tone);
        expect(
          headerColor(tester),
          Color.alphaBlend(style.toneColor(tone).withValues(alpha: 0.16), base),
        );
        expect(
          iconColor(tester, 'card-power'),
          style.powerColor(node.powerStatus),
        );
        expect(iconColor(tester, 'card-shutter'), style.shutterColor(node));
      });
    }

    testWidgets('colours follow the projector LED', (tester) async {
      await pump(tester, _node());
      final context = cardContext(tester);
      final style = ProjectorStatusStyle.of(context);
      final sc = AppStatusColors.of(context);
      final cs = Theme.of(context).colorScheme;
      final t = AppText.of(context);

      expect(style.powerColor(PowerStatus.on), sc.success);
      expect(style.powerColor(PowerStatus.cooling), sc.warning);
      expect(style.powerColor(PowerStatus.standby), cs.error);
      expect(style.shutterColor(_node()), sc.success);
      expect(
        style.shutterColor(_node(shutter: ShutterStatus.closed)),
        cs.error,
      );
      expect(
        style.shutterColor(
          _node(power: PowerStatus.cooling, shutter: ShutterStatus.closed),
        ),
        cs.error,
      );
      // Standby: the shutter says nothing, grey.
      expect(
        style.shutterColor(
          _node(power: PowerStatus.standby, shutter: ShutterStatus.closed),
        ),
        t.tertiary,
      );
      expect(iconData(tester, 'card-shutter'), Icons.visibility);
    });

    testWidgets('a closed shutter shows the eye crossed out', (tester) async {
      await pump(tester, _node(shutter: ShutterStatus.closed));
      expect(iconData(tester, 'card-shutter'), Icons.visibility_off);
    });
  });

  testWidgets('offline: Offline in the header and the only red outline', (
    tester,
  ) async {
    await pump(tester, _node(connection: ConnectionStatus.offline));
    final cs = Theme.of(cardContext(tester)).colorScheme;
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-power')), findsNothing);
    expect(find.byKey(const ValueKey('card-shutter')), findsNothing);
    expect(cardBorder(tester).top.color, cs.error);
    expect(cardBorder(tester).top.width, 1.5);
  });

  for (final node in [
    _node(power: PowerStatus.standby, shutter: ShutterStatus.closed),
    _node(connection: ConnectionStatus.unauthorized),
    _node(),
  ]) {
    testWidgets('no red outline for ${node.connectionStatus.name} '
        '${node.powerStatus.name}', (tester) async {
      await pump(tester, node);
      final cs = Theme.of(cardContext(tester)).colorScheme;
      expect(cardBorder(tester).top.color, cs.outlineVariant);
      expect(cardBorder(tester).top.width, 1);
    });
  }

  testWidgets('a failed login says so in an amber header', (tester) async {
    final node = _node(connection: ConnectionStatus.unauthorized);
    await pump(tester, node);
    final context = cardContext(tester);
    expect(find.text('Login failed'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-power')), findsNothing);
    expect(
      headerColor(tester),
      Color.alphaBlend(
        AppStatusColors.of(context).warning.withValues(alpha: 0.16),
        projectorCardFill(Theme.of(context).colorScheme).top,
      ),
    );
  });

  testWidgets('a projector without a password shows the open lock', (
    tester,
  ) async {
    await pump(tester, _node(connection: ConnectionStatus.unprotected));
    expect(find.byKey(const ValueKey('card-unprotected')), findsOneWidget);
  });

  group('group band', () {
    testWidgets('a grouped card has the band with the group name', (
      tester,
    ) async {
      await pump(tester, _node(), group: _group);
      final band = find.byKey(const ValueKey('card-group-band'));
      expect(band, findsOneWidget);
      expect(
        find.descendant(of: band, matching: find.text('Main screen')),
        findsOneWidget,
      );
      // Inside the card: the card keeps its 100 px.
      expect(
        tester.getBottomLeft(band).dy,
        tester.getBottomLeft(find.byKey(const ValueKey('card-border'))).dy,
      );
    });

    testWidgets('an ungrouped card has none', (tester) async {
      await pump(tester, _node());
      expect(find.byKey(const ValueKey('card-group-band')), findsNothing);
    });

    testWidgets('the band is the 55% mix and its text follows the mix', (
      tester,
    ) async {
      await pump(tester, _node(), group: _group);
      final cs = Theme.of(cardContext(tester)).colorScheme;
      final expected = Color.lerp(
        projectorCardFill(cs).bottom,
        const Color(0xFF5B8DEF),
        0.55,
      )!;
      final band = tester.widget<Container>(
        find.byKey(const ValueKey('card-group-band')),
      );
      expect(band.color, expected);
      final text = tester.widget<Text>(find.text('Main screen'));
      expect(text.style!.color, groupBandTextColor(expected));
    });

    testWidgets('no group border: the outline stays neutral', (tester) async {
      await pump(tester, _node(), group: _group);
      final cs = Theme.of(cardContext(tester)).colorScheme;
      expect(cardBorder(tester).top.color, cs.outlineVariant);
    });

    test('band text is light on a dark mix and dark on a light one', () {
      const dark = Color(0xFF1D2024);
      const light = Color(0xFFF1F0F2);
      // A light group colour on the dark card still mixes dark: light text.
      final darkBand = groupBandColor(dark, const Color(0xFF4CC38A));
      expect(groupBandTextColor(darkBand), const Color(0xFFF4F5F8));
      final lightBand = groupBandColor(light, const Color(0xFFF2C94C));
      expect(groupBandTextColor(lightBand), const Color(0xFF15171B));
    });
  });

  testWidgets('the selection ring shows only while selected', (tester) async {
    final c = await pump(tester, _node());
    expect(find.byKey(const ValueKey('selection-ring')), findsNothing);
    c.read(selectionProvider.notifier).selectOnly('1');
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-ring')), findsOneWidget);
    // Outside the card, so it never mixes with the card's own colours.
    final ring = tester.getRect(find.byKey(const ValueKey('selection-ring')));
    final card = tester.getRect(find.byKey(const ValueKey('card-border')));
    expect(ring.left, card.left - 5.5);
    expect(ring.bottom, card.bottom + 5.5);
  });

  testWidgets('an alert appearing does not move the power icon', (
    tester,
  ) async {
    final c = await pump(tester, _node());
    final power = tester.getTopLeft(find.byKey(const ValueKey('card-power')));
    final shutter = tester.getTopLeft(
      find.byKey(const ValueKey('card-shutter')),
    );
    (c.read(alertsProvider.notifier) as _FakeAlerts).setAll([
      ActiveAlert(
        nodeId: '1',
        rule: AlertRule.exhaustTemp,
        severity: AlertSeverity.warning,
        value: '58 °C',
        since: DateTime.now(),
      ),
      ActiveAlert(
        nodeId: '1',
        rule: AlertRule.intakeTemp,
        severity: AlertSeverity.warning,
        value: '41 °C',
        since: DateTime.now(),
      ),
    ]);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('card-power'))), power);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('card-shutter'))),
      shutter,
    );
  });

  testWidgets('the context menu header shows model and IP', (tester) async {
    await pump(tester, _node());
    await tester.tap(find.text('10.0.1.52'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('card-menu-header'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('PT-RZ120')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('10.0.1.52')),
      findsOneWidget,
    );
    expect(find.text('Quick status'), findsOneWidget);
  });
}
