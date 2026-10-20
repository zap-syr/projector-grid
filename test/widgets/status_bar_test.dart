import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/monitoring_filter.dart';
import 'package:projector_grid/features/workspace/domain/osc_status.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/domain/web_clients.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alert_counts_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_filter_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/monitoring_view_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/osc_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/poll_status_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/web_clients_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/web_server_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/severity_pill.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_tooltip.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/preferences_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/settings_rows.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/status_bar.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

class _FakeOsc extends OscNotifier {
  _FakeOsc(this.initial);

  final OscStatus initial;

  @override
  OscStatus build() => initial;

  void set(OscStatus s) => state = s;
}

class _FakeWeb extends WebServerNotifier {
  @override
  bool build() => true;
}

ProjectorNode _node(
  int i, {
  ConnectionStatus status = ConnectionStatus.connected,
  String? group,
}) => ProjectorNode(
  id: 'n$i',
  name: 'PT-RZ$i',
  ipAddress: '10.0.1.$i',
  x: 0,
  y: 0,
  connectionStatus: status,
  groupId: group,
  polled: true,
);

const _keys = [
  ValueKey('status-online'),
  ValueKey('status-offline'),
  ValueKey('status-alerts'),
  ValueKey('status-updated'),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double width = 1600,
  ThemeData? theme,
  List<Override> overrides = const [],
  List<ProjectorNode> nodes = const [],
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(FakeProtocolService()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              StatusBar(),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  final c = ProviderScope.containerOf(tester.element(find.byType(StatusBar)));
  c.read(workspaceProvider.notifier).setNodes(nodes);
  await tester.pump();
  return c;
}

/// Moves the mouse onto [target]; pass the returned gesture to hover again
/// in the same test.
Future<TestGesture> _hover(
  WidgetTester tester,
  Finder target, [
  TestGesture? mouse,
]) async {
  if (mouse == null) {
    mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
  }
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
  return mouse;
}

/// The app's fonts instead of the test font (every glyph a square), so the
/// 800 px test lays the bar out at its real width.
Future<void> _loadAppFonts() async {
  Future<void> load(String family, String dir, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', 'inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await load('IBM Plex Mono', 'ibm_plex_mono', [
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
    'IBMPlexMono-SemiBold.ttf',
  ]);
}

double _opacityOf(WidgetTester tester, Key key) {
  final o = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Opacity),
  );
  return o.evaluate().isEmpty ? 1 : tester.widget<Opacity>(o.first).opacity;
}

int? _meterFlex(WidgetTester tester, String part) {
  final f = find.byKey(ValueKey('meter-$part'));
  return f.evaluate().isEmpty ? null : tester.widget<Expanded>(f).flex;
}

void main() {
  useTempConfigDir();
  setUpAll(_loadAppFonts);

  group('StatusBar', () {
    testWidgets('36 px high, full words above the narrow threshold', (
      tester,
    ) async {
      await _pump(tester, nodes: [_node(1)]);
      expect(tester.getSize(find.byType(StatusBar)).height, 36);
      for (final label in ['Projectors', 'Online', 'Offline', 'Alerts']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('None'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('status-online'))).height,
        28,
      );
    });

    testWidgets('the meter follows online, wrong login and offline', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        nodes: [
          for (var i = 1; i <= 15; i++) _node(i),
          _node(16, status: ConnectionStatus.unauthorized),
          _node(17, status: ConnectionStatus.offline),
          _node(18, status: ConnectionStatus.offline),
        ],
      );
      expect(_meterFlex(tester, 'online'), 15);
      expect(_meterFlex(tester, 'wrong-login'), 1);
      expect(_meterFlex(tester, 'offline'), 2);
      expect(find.text('18'), findsOneWidget);
      // The parts fill the track's height; at 0 px only the grey showed.
      for (final part in ['online', 'wrong-login', 'offline']) {
        expect(
          tester.getSize(find.byKey(ValueKey('meter-$part'))).height,
          HealthMeter.size.height,
          reason: part,
        );
      }

      // Without a failed login there is no amber part.
      c.read(workspaceProvider.notifier).setNodes([
        for (var i = 1; i <= 16; i++) _node(i),
        _node(17, status: ConnectionStatus.offline),
      ]);
      await tester.pump();
      expect(_meterFlex(tester, 'online'), 16);
      expect(_meterFlex(tester, 'wrong-login'), isNull);
      expect(_meterFlex(tester, 'offline'), 1);
    });

    testWidgets('no projectors: an empty meter, both counts dimmed', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(HealthMeter), findsOneWidget);
      for (final part in ['online', 'wrong-login', 'offline']) {
        expect(_meterFlex(tester, part), isNull);
      }
      expect(_opacityOf(tester, const ValueKey('status-online')), 0.45);
      expect(_opacityOf(tester, const ValueKey('status-offline')), 0.45);
    });

    testWidgets('the meter tooltip only with a wrong login', (tester) async {
      final c = await _pump(tester, nodes: [_node(1), _node(2)]);
      final mouse = await _hover(tester, find.byType(HealthMeter));
      expect(find.byType(TooltipBubble), findsNothing);

      c.read(workspaceProvider.notifier).setNodes([
        _node(1),
        _node(2, status: ConnectionStatus.unauthorized),
      ]);
      await tester.pump();
      await mouse.moveTo(const Offset(400, 400));
      await tester.pump();
      await _hover(tester, find.byType(HealthMeter), mouse);
      expect(find.text('1 wrong login'), findsOneWidget);
      expect(find.text('Check the login in Edit Projector'), findsOneWidget);
    });

    testWidgets('a count at 0 stays in place, dimmed and not clickable', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        nodes: [
          _node(1),
          _node(2, status: ConnectionStatus.offline),
        ],
      );
      const offline = ValueKey('status-offline');
      final before = tester.getRect(find.byKey(offline));
      expect(_opacityOf(tester, offline), 1);

      c.read(workspaceProvider.notifier).setNodes([_node(1), _node(2)]);
      await tester.pump();
      expect(tester.getRect(find.byKey(offline)), before);
      expect(_opacityOf(tester, offline), 0.45);

      await tester.tap(find.byKey(offline));
      await tester.pump();
      expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
    });

    testWidgets('Offline opens Monitoring on the Offline filter, the search '
        'cleared and its group expanded', (tester) async {
      final c = await _pump(
        tester,
        nodes: [
          _node(1, group: 'g1'),
          _node(2, status: ConnectionStatus.offline, group: 'g1'),
          _node(3, group: 'g2'),
        ],
      );
      c.read(workspaceProvider.notifier).setGroups(const [
        ProjectorGroup(id: 'g1', name: 'Main', color: 0xFF4C8DF6),
        ProjectorGroup(id: 'g2', name: 'Stage', color: 0xFF4C8DF6),
      ]);
      c.read(monitoringFilterProvider.notifier).setQuery('rz3');
      final view = c.read(monitoringViewProvider.notifier)
        ..toggleCollapsed('g1')
        ..toggleCollapsed('g2');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('status-offline')));
      await tester.pump();
      expect(
        c.read(monitoringFilterProvider),
        const MonitoringFilter(quick: MonitoringQuickFilter.offline),
      );
      expect(c.read(appSettingsProvider).isMonitoringView, isTrue);
      // Only the group holding an offline projector opens.
      expect(c.read(monitoringViewProvider).collapsed, {'g2'});
      expect(view, isNotNull);
    });

    testWidgets('Online opens Monitoring on the Online filter', (tester) async {
      final c = await _pump(tester, nodes: [_node(1)]);
      await tester.tap(find.byKey(const ValueKey('status-online')));
      await tester.pump();
      expect(
        c.read(monitoringFilterProvider).quick,
        MonitoringQuickFilter.online,
      );
      expect(c.read(appSettingsProvider).isMonitoringView, isTrue);
    });

    testWidgets('the Online tooltip: the count and the click line', (
      tester,
    ) async {
      await _pump(tester, nodes: [_node(1), _node(2)]);
      await _hover(tester, find.byKey(const ValueKey('status-online')));
      expect(find.text('2 online'), findsOneWidget);
      expect(find.text('Click to show them in Monitoring'), findsOneWidget);
      expect(find.byType(TooltipRow), findsNothing);
    });

    testWidgets('the Offline tooltip: 5 rows and "and N more"', (tester) async {
      await _pump(
        tester,
        nodes: [
          _node(1),
          for (var i = 11; i <= 17; i++)
            _node(i, status: ConnectionStatus.offline),
        ],
      );
      await _hover(tester, find.byKey(const ValueKey('status-offline')));
      expect(find.text('7 offline'), findsOneWidget);
      expect(find.byType(TooltipRow), findsNWidgets(5));
      expect(find.text('10.0.1.11'), findsOneWidget);
      expect(find.text('PT-RZ11'), findsOneWidget);
      expect(find.text('and 2 more'), findsOneWidget);
      expect(find.text('Click to show them in Monitoring'), findsOneWidget);
    });

    testWidgets('the Offline tooltip when every projector is offline', (
      tester,
    ) async {
      await _pump(
        tester,
        nodes: [
          for (var i = 1; i <= 3; i++)
            _node(i, status: ConnectionStatus.offline),
        ],
      );
      await _hover(tester, find.byKey(const ValueKey('status-offline')));
      expect(find.text('All 3 offline'), findsOneWidget);
      expect(find.text('Check the network connection'), findsOneWidget);
      expect(find.byType(TooltipRow), findsNothing);
    });

    testWidgets('OSC and Web are hidden while off', (tester) async {
      await _pump(tester, nodes: [_node(1)]);
      expect(find.byKey(const ValueKey('status-osc')), findsNothing);
      expect(find.byKey(const ValueKey('status-web')), findsNothing);
    });

    testWidgets('OSC listening, Web with its pages', (tester) async {
      final c = await _pump(
        tester,
        nodes: [_node(1)],
        overrides: [
          oscProvider.overrideWith(() => _FakeOsc(const OscListening(9000))),
          webServerProvider.overrideWith(_FakeWeb.new),
        ],
      );
      expect(find.text('OSC  9000', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('port busy', findRichText: true),
        findsNothing,
      );
      expect(find.text('Web'), findsOneWidget);
      expect(find.text('0'), findsWidgets);

      c.read(webClientsProvider.notifier).set([
        for (var i = 0; i < 3; i++)
          WebClient(
            id: '$i',
            ip: '10.0.0.3$i',
            role: i == 0 ? WebRole.operator : WebRole.viewer,
            pages: 1,
            lastSeen: DateTime(2026),
          ),
      ]);
      await tester.pump();
      expect(find.text('(1 operator)'), findsOneWidget);
      await _hover(tester, find.byKey(const ValueKey('status-web')));
      expect(find.text('Web access, 3 pages open'), findsOneWidget);
      expect(find.byType(TooltipRow), findsNWidgets(3));
      expect(find.text('Operator'), findsOneWidget);
    });

    testWidgets('port busy only on a bind failure, shown with the setting '
        'off, gone after a successful start', (tester) async {
      final c = await _pump(
        tester,
        nodes: [_node(1)],
        overrides: [oscProvider.overrideWith(() => _FakeOsc(const OscOff()))],
      );
      // On in the settings but not running yet (launch, restart): nothing.
      c.read(appSettingsProvider.notifier).setOscActive(true);
      await tester.pump();
      expect(find.byKey(const ValueKey('status-osc')), findsNothing);

      // The failed bind writes the setting off and keeps the failure.
      final osc = c.read(oscProvider.notifier) as _FakeOsc;
      c.read(appSettingsProvider.notifier).setOscActive(false);
      osc.set(const OscBindFailed(9000));
      await tester.pump();
      expect(
        find.text('OSC  9000  port busy', findRichText: true),
        findsOneWidget,
      );
      await _hover(tester, find.byKey(const ValueKey('status-osc')));
      expect(find.text('OSC port 9000 is in use'), findsOneWidget);
      expect(find.text('Choose another in Preferences'), findsOneWidget);

      osc.set(const OscListening(9001));
      await tester.pump();
      expect(find.text('OSC  9001', findRichText: true), findsOneWidget);
    });

    testWidgets('Updated --:--:-- before the first poll, then the time', (
      tester,
    ) async {
      final c = await _pump(tester, nodes: [_node(1)]);
      expect(
        find.text('Updated  --:--:--', findRichText: true),
        findsOneWidget,
      );
      c.read(pollStatusProvider.notifier).completed();
      await tester.pump();
      expect(
        find.textContaining(
          RegExp(r'^Updated  \d\d:\d\d:\d\d$'),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('the bar keeps its size while polling', (tester) async {
      final c = await _pump(tester, nodes: [_node(1)]);
      final poll = c.read(pollStatusProvider.notifier)..completed();
      await tester.pump();
      Map<Key, Rect> rects() => {
        for (final k in _keys) k: tester.getRect(find.byKey(k)),
      };
      final before = rects();
      final bar = tester.getSize(find.byType(StatusBar));

      poll.started();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(rects(), before);
      expect(tester.getSize(find.byType(StatusBar)), bar);
      final spinner = tester.getSize(find.byType(CircularProgressIndicator));
      expect(spinner, const Size(12, 12));

      // Indeterminate spinners never settle; end the poll to stop it.
      poll.completed();
      await tester.pump();
      expect(rects(), before);
    });

    testWidgets('Alerts: None with nothing active', (tester) async {
      await _pump(tester, nodes: [_node(1)]);
      expect(find.text('None'), findsOneWidget);
      expect(find.byType(SeverityPill), findsNothing);
    });

    for (final (name, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('800 px window, $name: narrow, every item, no overflow', (
        tester,
      ) async {
        final c = await _pump(
          tester,
          width: 800,
          theme: theme,
          nodes: [
            for (var i = 1; i <= 120; i++) _node(i),
            for (var i = 121; i <= 230; i++)
              _node(i, status: ConnectionStatus.offline),
            _node(231, status: ConnectionStatus.unauthorized),
          ],
          overrides: [
            oscProvider.overrideWith(() => _FakeOsc(const OscBindFailed(9000))),
            webServerProvider.overrideWith(_FakeWeb.new),
            alertCountsProvider.overrideWithValue((
              critical: 88,
              warning: 88,
              criticalTotal: 88,
              warningTotal: 88,
              recovered: 88,
            )),
          ],
        );
        c.read(webClientsProvider.notifier).set([
          for (var i = 0; i < 12; i++)
            WebClient(
              id: '$i',
              ip: '10.0.0.$i',
              role: i < 3 ? WebRole.operator : WebRole.viewer,
              pages: 1,
              lastSeen: DateTime(2026),
            ),
        ]);
        c.read(pollStatusProvider.notifier).completed();
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Narrow: no words, the names are in the tooltips.
        for (final word in ['Projectors', 'Online', 'Alerts', 'OSC', 'Web']) {
          expect(find.text(word), findsNothing, reason: word);
        }
        expect(find.text('Updated'), findsNothing);
        expect(find.text('231'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.text('110'), findsOneWidget);
        expect(find.byType(SeverityPill), findsNWidgets(3));
        for (final k in [
          ..._keys,
          const ValueKey('status-osc'),
          const ValueKey('status-web'),
        ]) {
          final r = tester.getRect(find.byKey(k));
          expect(r.left, greaterThanOrEqualTo(0), reason: '$k');
          expect(r.right, lessThanOrEqualTo(800), reason: '$k');
        }
        // In order, none overlapping.
        final online = tester.getRect(find.byKey(_keys[0]));
        final alerts = tester.getRect(find.byKey(_keys[2]));
        final osc = tester.getRect(find.byKey(const ValueKey('status-osc')));
        expect(online.right, lessThan(alerts.left));
        expect(alerts.right, lessThan(osc.left));
      });
    }
  });

  group('PreferencesDialog OSC', () {
    testWidgets('a bind failure: the red dot and the in-use line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            protocolServiceProvider.overrideWithValue(FakeProtocolService()),
            oscProvider.overrideWith(() => _FakeOsc(const OscBindFailed(9000))),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: PreferencesDialog(section: PreferencesSection.osc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Network interface'), findsOneWidget);
      expect(
        find.text('Port 9000 is in use. Choose another port'),
        findsOneWidget,
      );
      final navItem = find.ancestor(
        of: find.text('OSC').first,
        matching: find.byType(InkWell),
      );
      final dot = tester.widget<StatusDot>(
        find.descendant(of: navItem.first, matching: find.byType(StatusDot)),
      );
      expect(dot.color, AppTheme.darkTheme.colorScheme.error);
      expect(tester.takeException(), isNull);
    });

    testWidgets('listening: no line', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            protocolServiceProvider.overrideWithValue(FakeProtocolService()),
            oscProvider.overrideWith(() => _FakeOsc(const OscListening(9000))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PreferencesDialog(section: PreferencesSection.osc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Listening on UDP 9000'), findsOneWidget);
      expect(find.byKey(const ValueKey('service-error')), findsNothing);
    });
  });
}
