import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_request_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/event_log/event_log_row.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/event_log_panel.dart';

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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
