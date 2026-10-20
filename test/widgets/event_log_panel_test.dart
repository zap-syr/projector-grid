import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/presentation/providers/active_alerts_request_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/canvas_reveal_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_request_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/event_log/event_log_batch_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/event_log/event_log_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/event_log_panel.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

final _today = DateTime.now();

LogEvent _e(
  LogEventType type,
  LogSeverity severity,
  String message, {
  String? ip,
  String? model,
}) => LogEvent(
  type: type,
  severity: severity,
  message: message,
  projectorIp: ip,
  projectorName: model,
  timestamp: DateTime(_today.year, _today.month, _today.day, 9, 30),
);

/// Newest first, as the provider keeps them.
final _events = [
  _e(
    LogEventType.alert,
    LogSeverity.error,
    'Error F305: exhaust fan stopped',
    ip: '10.0.1.33',
    model: 'PT-RZ120',
  ),
  _e(
    LogEventType.command,
    LogSeverity.success,
    'Shutter Close',
    ip: '10.0.1.33',
    model: 'PT-RZ120',
  ),
  _e(
    LogEventType.alert,
    LogSeverity.info,
    'Signal lost acknowledged',
    ip: '10.0.1.31',
    model: 'PT-RZ120',
  ),
  _e(
    LogEventType.connectivity,
    LogSeverity.warning,
    'Wrong login',
    ip: '10.0.1.51',
  ),
  _e(LogEventType.osc, LogSeverity.info, '/pgrid/all/shutter/close'),
];

void main() {
  useTempConfigDir();

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    Size size = const Size(1600, 900),
    List<LogEvent>? events,
    double? maxHeight,
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (container == null) {
      container = ProviderContainer();
      addTearDown(container.dispose);
    }
    for (final e in (events ?? _events).reversed) {
      container.read(eventLogProvider.notifier).log(e);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                EventLogPanel(maxHeight: maxHeight ?? size.height - 150),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder chip(String name) => find.byKey(ValueKey('event-log-filter-$name'));
  int rowCount() => find.byType(EventLogRow).evaluate().length;

  testWidgets('each chip filters, Alerts takes errors, warnings and alerts', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(rowCount(), 5);

    await tester.tap(chip('alerts'));
    await tester.pumpAndSettle();
    expect(rowCount(), 3);
    expect(find.text('Error F305: exhaust fan stopped'), findsOneWidget);
    expect(find.text('Signal lost acknowledged'), findsOneWidget);
    expect(find.text('Wrong login'), findsOneWidget);

    await tester.tap(chip('commands'));
    await tester.pumpAndSettle();
    expect(rowCount(), 1);
    expect(find.text('Shutter Close'), findsOneWidget);

    await tester.tap(chip('connection'));
    await tester.pumpAndSettle();
    expect(rowCount(), 1);

    await tester.tap(chip('osc'));
    await tester.pumpAndSettle();
    expect(rowCount(), 1);
  });

  testWidgets('an empty chip stays in place, dimmed and not clickable', (
    tester,
  ) async {
    await pumpPanel(tester);
    final web = chip('web');
    expect(web, findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.descendant(of: web, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(1));
    await tester.tap(web, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(rowCount(), 5, reason: 'All stays selected');
  });

  testWidgets('a selected chip that empties stays selected', (tester) async {
    final container = await pumpPanel(tester);
    await tester.tap(chip('osc'));
    await tester.pumpAndSettle();
    // Only the OSC event is gone: the chip keeps its place and selection,
    // and the view says nothing matches.
    container.read(eventLogProvider.notifier).clear();
    for (final e in _events.where((e) => e.type != LogEventType.osc)) {
      container.read(eventLogProvider.notifier).log(e);
    }
    await tester.pumpAndSettle();
    expect(find.text('No events match'), findsOneWidget);
    // The line under it names the filter, as the chip does.
    expect(find.text('OSC'), findsNWidgets(2));
    final material = tester.widget<Material>(
      find.descendant(of: chip('osc'), matching: find.byType(Material)).first,
    );
    expect(
      material.color,
      Theme.of(tester.element(chip('osc'))).colorScheme.primaryContainer,
    );
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(rowCount(), 4);
  });

  testWidgets('search filters and highlights the match', (tester) async {
    await pumpPanel(tester);
    await tester.enterText(
      find.byKey(const ValueKey('event-log-search')),
      '.33',
    );
    await tester.pumpAndSettle();
    expect(rowCount(), 2);
    final highlighted = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(EventLogRow),
            matching: find.byType(RichText),
          ),
        )
        .where((r) {
          var marked = false;
          r.text.visitChildren((span) {
            if (span is TextSpan &&
                span.text == '.33' &&
                span.style?.backgroundColor != null) {
              marked = true;
            }
            return true;
          });
          return marked;
        });
    expect(highlighted, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('event-log-search-clear')));
    await tester.pumpAndSettle();
    expect(rowCount(), 5);
  });

  testWidgets('Clear asks first', (tester) async {
    final container = await pumpPanel(tester);
    await tester.tap(find.byKey(const ValueKey('event-log-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear the event log?'), findsOneWidget);
    expect(
      find.text('All 5 events are removed. Copy them first if you need them.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(eventLogProvider), hasLength(5));

    await tester.tap(find.byKey(const ValueKey('event-log-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(container.read(eventLogProvider), isEmpty);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('Copy copies the rows shown and shows a check', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPanel(tester);
    await tester.tap(chip('alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-log-copy')));
    await tester.pump();
    expect(copied!.split('\n'), [
      '09:30:00  error  10.0.1.33 PT-RZ120  Alert  '
          'Error F305: exhaust fan stopped',
      '09:30:00  info  10.0.1.31 PT-RZ120  Alert  Signal lost acknowledged',
      '09:30:00  warning  10.0.1.51  Connection  Wrong login',
    ]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('event-log-copy')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('a row with no projector reads App', (tester) async {
    await pumpPanel(tester);
    expect(find.text('App'), findsOneWidget);
  });

  testWidgets('the panel grows past 240 px and its height is restored', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    final panel = find.byType(EventLogPanel);
    expect(tester.getSize(panel).height, 240);

    await tester.drag(
      find.byKey(const ValueKey('event-log-grip')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final grown = tester.getSize(panel).height;
    expect(grown, greaterThan(400));
    expect(container.read(appSettingsProvider).eventLogHeight, grown);

    // A fresh start reads it back from the settings file.
    await tester.pumpWidget(const SizedBox());
    await pumpPanel(tester);
    expect(tester.getSize(panel).height, grown);

    // A small window shows the panel at its maximum and keeps the saved
    // height.
    await tester.pumpWidget(const SizedBox());
    final small = await pumpPanel(tester, maxHeight: 300);
    expect(tester.getSize(panel).height, 300);
    expect(small.read(appSettingsProvider).eventLogHeight, grown);
  });

  testWidgets('an alerts request selects Alerts and fills the search', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    container
        .read(eventLogRequestProvider.notifier)
        .show(query: '10.0.1.33', alertsOnly: true);
    await tester.pumpAndSettle();
    expect(rowCount(), 1);
    expect(find.text('Error F305: exhaust fan stopped'), findsOneWidget);
  });

  group('batch rows', () {
    const batch = CommandBatch(
      id: 'b1',
      command: 'OSH:0',
      source: CommandSource.controlBar,
      target: 'Stage, 3 projectors',
      nodeIds: ['31', '33', '35'],
    );
    LogEvent line(String id, CommandOutcome o, String message) => LogEvent(
      severity: switch (o) {
        CommandOutcome.sent => LogSeverity.success,
        CommandOutcome.failed => LogSeverity.error,
        CommandOutcome.skipped => LogSeverity.info,
      },
      type: LogEventType.command,
      message: message,
      projectorIp: '10.0.1.$id',
      projectorName: 'PT-RZ120',
      batch: batch,
      outcome: o,
      nodeId: id,
      timestamp: DateTime(_today.year, _today.month, _today.day, 9, 30),
    );
    final batchEvents = [
      LogEvent(
        severity: LogSeverity.warning,
        type: LogEventType.command,
        message: 'Shutter Open',
        source: CommandSource.controlBar,
        batch: batch,
        timestamp: DateTime(_today.year, _today.month, _today.day, 9, 30),
      ),
      line('35', CommandOutcome.skipped, 'Skipped: offline'),
      line('33', CommandOutcome.failed, 'Failed: no answer or refused'),
      line('31', CommandOutcome.sent, 'Sent'),
    ];
    Finder lines() => find.byType(EventLogBatchLine);
    // The batch second, so it is on screen with a row above it.
    final mixed = [_events.first, ...batchEvents, ..._events.skip(1)];

    testWidgets('one closed row with pills, opened to its projector lines', (
      tester,
    ) async {
      await pumpPanel(tester, events: mixed);
      expect(find.byType(EventLogBatchRow), findsOneWidget);
      expect(lines(), findsNothing, reason: 'rows start closed');
      expect(find.text('Stage, 3 projectors'), findsOneWidget);
      expect(find.text('from the control bar'), findsOneWidget);
      expect(find.text('1 sent'), findsOneWidget);
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('1 skipped'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      final above = tester.getTopLeft(find.byType(EventLogRow).first);
      await tester.tap(find.text('Stage, 3 projectors'));
      await tester.pumpAndSettle();
      expect(lines(), findsNWidgets(3));
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(EventLogRow).first),
        above,
        reason: 'opening a row moves nothing above it',
      );
      // Workspace order: the sent ones, then the skipped one.
      final ips = [
        for (final l in tester.widgetList<EventLogBatchLine>(lines()))
          l.event.projectorIp,
      ];
      expect(ips, ['10.0.1.31', '10.0.1.33', '10.0.1.35']);
      expect(find.text('Failed: no answer or refused'), findsOneWidget);
      expect(find.text('Skipped: offline'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-log-batch-chevron')));
      await tester.pumpAndSettle();
      expect(lines(), findsNothing);
    });

    testWidgets('the batch row keeps the row height and columns', (
      tester,
    ) async {
      await pumpPanel(tester, events: mixed);
      expect(
        tester.getSize(find.byType(EventLogBatchRow)).height,
        EventLogColumns.rowHeight,
      );
      final rowTarget = tester.getTopLeft(find.text('Stage, 3 projectors'));
      final singleIp = tester.getTopLeft(find.text('10.0.1.33').first);
      // Same Projector column, after the chevron.
      expect(rowTarget.dx, greaterThan(singleIp.dx));
      expect(rowTarget.dx - singleIp.dx, lessThan(30));
    });

    testWidgets('a search for an IP opens its batch', (tester) async {
      await pumpPanel(tester, events: [..._events, ...batchEvents]);
      await tester.enterText(
        find.byKey(const ValueKey('event-log-search')),
        '10.0.1.35',
      );
      await tester.pumpAndSettle();
      expect(find.byType(EventLogBatchRow), findsOneWidget);
      expect(lines(), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('event-log-search-clear')));
      await tester.pumpAndSettle();
      expect(lines(), findsNothing, reason: 'the search opened it');
    });

    testWidgets('Copy writes the summary and its projector lines', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpPanel(tester, events: batchEvents);
      await tester.tap(find.byKey(const ValueKey('event-log-copy')));
      await tester.pump();
      expect(copied!.split('\n'), [
        '09:30:00  warning  Stage, 3 projectors  Command  '
            'Shutter Open from the control bar, 1 sent, 1 failed, 1 skipped',
        '  09:30:00  success  10.0.1.31 PT-RZ120  Command  Sent',
        '  09:30:00  error  10.0.1.33 PT-RZ120  Command  '
            'Failed: no answer or refused',
        '  09:30:00  info  10.0.1.35 PT-RZ120  Command  Skipped: offline',
      ]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Web counts the commands sent from the Web page', (
      tester,
    ) async {
      final web = LogEvent(
        severity: LogSeverity.info,
        type: LogEventType.command,
        message: 'Power On',
        projectorIp: '10.0.1.40',
        source: const CommandSource.web(ip: '10.0.0.5', role: 'operator'),
        timestamp: DateTime(_today.year, _today.month, _today.day, 9, 30),
      );
      await pumpPanel(tester, events: [web, ..._events]);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: chip('web'), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1, reason: 'Web is no longer empty');
      await tester.tap(chip('web'));
      await tester.pumpAndSettle();
      expect(rowCount(), 1);
      expect(find.text('from Web, 10.0.0.5 (operator)'), findsOneWidget);
    });

    testWidgets('Retry failed sends to the failed projectors only', (
      tester,
    ) async {
      final fake = FakeProtocolService();
      final c = makeContainer(fake);
      final ws = c.read(workspaceProvider.notifier);
      ws.setNodes([node('1'), node('2'), node('3')]);
      fake.commandSucceeds['10.0.0.2'] = false;
      fake.commandSucceeds['10.0.0.3'] = false;
      await ws.sendCommandToAll('OSH:1', source: CommandSource.controlBar);
      // '3' is removed before the retry.
      ws.setNodes([node('1'), node('2')]);
      fake.sentCommands.clear();

      await pumpPanel(tester, events: const [], container: c);
      final row = find.byType(EventLogBatchRow);
      expect(find.text('2 failed'), findsOneWidget);
      expect(find.text('Retry failed'), findsNothing, reason: 'hover only');
      final rowSize = tester.getSize(row);
      final pillAt = tester.getTopLeft(find.text('2 failed'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(row));
      await tester.pump();
      expect(find.text('Retry failed'), findsOneWidget);
      // The hover action sits over the row; nothing in it moves.
      expect(tester.getSize(row), rowSize);
      expect(tester.getTopLeft(find.text('2 failed')), pillAt);
      await tester.tap(find.text('Retry failed'));
      await tester.pumpAndSettle();

      expect(fake.sentCommands, [('10.0.0.2', 'OSH:1')]);
      final retry = c.read(eventLogProvider).first;
      expect(retry.source, CommandSource.retry);
      expect(retry.nodeId, '2');
      expect(find.text('from retry'), findsOneWidget);
      c.dispose();
    });
  });

  group('hover actions', () {
    Future<void> hover(WidgetTester tester, Finder row) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(row));
      await tester.pump();
    }

    Finder rowWith(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(EventLogRow));

    testWidgets('Locate selects and reveals the projector by its IP', (
      tester,
    ) async {
      final c = makeContainer(FakeProtocolService());
      c.read(workspaceProvider.notifier).setNodes([node('1'), node('2')]);
      c.read(appSettingsProvider.notifier).setMonitoringView(true);
      await pumpPanel(
        tester,
        container: c,
        events: [
          _e(
            LogEventType.connectivity,
            LogSeverity.info,
            'Came online',
            ip: '10.0.0.2',
          ),
          _e(
            LogEventType.connectivity,
            LogSeverity.info,
            'Went offline',
            ip: '10.0.9.9',
          ),
        ],
      );
      final row = rowWith('Came online');
      final rowSize = tester.getSize(row);
      final textAt = tester.getTopLeft(find.text('Came online'));
      await hover(tester, row);
      expect(find.byKey(const ValueKey('event-log-locate')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-log-open-alerts')), findsNothing);
      expect(tester.getSize(row), rowSize, reason: 'actions sit over the row');
      expect(tester.getTopLeft(find.text('Came online')), textAt);

      await tester.tap(find.byKey(const ValueKey('event-log-locate')));
      await tester.pump();
      expect(c.read(selectionProvider), {'2'});
      expect(c.read(canvasRevealProvider)?.nodeId, '2');
      expect(c.read(appSettingsProvider).isMonitoringView, isFalse);
      // Locate watches the workspace, whose polling timer only the
      // container's disposal stops.
      c.dispose();
    });

    testWidgets('Locate is hidden once the projector is gone', (tester) async {
      final c = makeContainer(FakeProtocolService());
      c.read(workspaceProvider.notifier).setNodes([node('1')]);
      await pumpPanel(
        tester,
        container: c,
        events: [
          _e(
            LogEventType.connectivity,
            LogSeverity.info,
            'Went offline',
            ip: '10.0.9.9',
          ),
        ],
      );
      await hover(tester, rowWith('Went offline'));
      expect(find.byKey(const ValueKey('event-log-copy-row')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-log-locate')), findsNothing);
      c.dispose();
    });

    testWidgets('Open alerts on an alert row opens Active alerts', (
      tester,
    ) async {
      final c = makeContainer(FakeProtocolService());
      await pumpPanel(tester, container: c);
      await hover(tester, rowWith('Error F305: exhaust fan stopped'));
      final before = c.read(activeAlertsRequestProvider);
      await tester.tap(find.byKey(const ValueKey('event-log-open-alerts')));
      await tester.pump();
      expect(c.read(activeAlertsRequestProvider), before + 1);
      c.dispose();
    });

    testWidgets('Copy row copies that row', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = makeContainer(FakeProtocolService());
      await pumpPanel(tester, container: c);
      await hover(tester, rowWith('Wrong login'));
      await tester.tap(find.byKey(const ValueKey('event-log-copy-row')));
      await tester.pump();
      expect(copied, '09:30:00  warning  10.0.1.51  Connection  Wrong login');
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
    });
  });

  testWidgets('a group across projectors is one row and opens to them', (
    tester,
  ) async {
    LogEvent online(String id) => LogEvent(
      severity: LogSeverity.success,
      type: LogEventType.connectivity,
      message: 'Came online',
      projectorIp: '10.0.1.$id',
      projectorName: 'PT-RZ120',
      nodeId: id,
      groupKind: LogGroupKind.online,
      projectorGroup: 'Stage',
      timestamp: DateTime(_today.year, _today.month, _today.day, 9, 31),
    );
    await pumpPanel(tester, events: [online('3'), online('2'), online('1')]);
    expect(find.byType(EventLogGroupRow), findsOneWidget);
    expect(find.text('Stage, 3 projectors'), findsOneWidget);
    expect(find.byType(EventLogGroupLine), findsNothing);
    await tester.tap(find.text('Stage, 3 projectors'));
    await tester.pumpAndSettle();
    final ips = [
      for (final l in tester.widgetList<EventLogGroupLine>(
        find.byType(EventLogGroupLine),
      ))
        l.event.projectorIp,
    ];
    expect(ips, ['10.0.1.1', '10.0.1.2', '10.0.1.3']);
  });

  testWidgets('repeats show one row with the count', (tester) async {
    LogEvent lost(int s) => LogEvent(
      severity: LogSeverity.warning,
      type: LogEventType.connectivity,
      message: 'Connection lost',
      projectorIp: '10.0.1.7',
      timestamp: DateTime(_today.year, _today.month, _today.day, 21, 2, s),
    );
    await pumpPanel(tester, events: [lost(41), lost(30), lost(10)]);
    expect(find.text('Connection lost'), findsOneWidget);
    expect(find.text('3 times, last 21:02:41'), findsOneWidget);
  });

  group('Follow', () {
    List<LogEvent> many(int n, {int from = 0}) => [
      for (var i = from + n - 1; i >= from; i--)
        _e(
          LogEventType.connectivity,
          LogSeverity.info,
          'event $i',
          ip: '10.0.2.$i',
        ),
    ];
    bool following(WidgetTester tester) => tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(const ValueKey('event-log-follow')),
            matching: find.byType(IconButton),
          ),
        )
        .isSelected!;

    testWidgets('scrolling down turns it off; the pill brings it back', (
      tester,
    ) async {
      final c = await pumpPanel(tester, events: many(40));
      expect(following(tester), isTrue);
      expect(find.text('event 39'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('event-log-list')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(following(tester), isFalse);
      final firstShown = tester.getTopLeft(find.text('event 30'));

      for (final e in many(2, from: 40).reversed) {
        c.read(eventLogProvider.notifier).log(e);
      }
      await tester.pumpAndSettle();
      expect(find.text('2 new events'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('event 30')),
        firstShown,
        reason: 'the list does not move under the reader',
      );

      await tester.tap(find.text('2 new events'));
      await tester.pumpAndSettle();
      expect(following(tester), isTrue);
      expect(find.text('2 new events'), findsNothing);
      expect(find.text('event 41'), findsOneWidget);
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('event-log-list')))
            .controller!
            .offset,
        0,
      );
    });

    testWidgets('the Follow button goes back to the newest too', (
      tester,
    ) async {
      final c = await pumpPanel(tester, events: many(40));
      await tester.drag(
        find.byKey(const ValueKey('event-log-list')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      c.read(eventLogProvider.notifier).log(many(1, from: 40).single);
      await tester.pumpAndSettle();
      expect(find.text('1 new event'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('event-log-follow')));
      await tester.pumpAndSettle();
      expect(following(tester), isTrue);
      expect(find.text('event 40'), findsOneWidget);
    });
  });

  testWidgets('the 800 px window: narrow header, no Source column', (
    tester,
  ) async {
    await pumpPanel(tester, size: const Size(800, 600));
    expect(find.text('Event log'), findsNothing);
    expect(find.text('Source'), findsNothing);
    expect(find.text('Time'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await pumpPanel(tester, size: const Size(1600, 900));
    expect(find.text('Event log'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });
}
