import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/add_projector_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// Opens the dialog from a button, as the toolbar does, so its pop on add
/// lands back on the page. Returns what it added and the scope's container.
Future<(List<List<Map<String, dynamic>>>, ProviderContainer)> _open(
  WidgetTester tester, {
  FakeProtocolService? fake,
  List<String> existingIps = const [],
  Size window = const Size(1600, 1000),
  void Function(ProviderContainer)? seed,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final added = <List<Map<String, dynamic>>>[];
  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(fake ?? FakeProtocolService()),
    ],
  );
  addTearDown(container.dispose);
  seed?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AddProjectorDialog(
                  existingIps: existingIps,
                  onAddProjectors: added.add,
                  loadInterfaces: () async => [
                    (name: 'Ethernet', address: '192.168.0.5'),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (added, container);
}

Finder _addButton(String label) =>
    find.widgetWithText(FilledButton, label).hitTestable();

void main() {
  useTempConfigDir();

  testWidgets('prefills the last used login and saves it after an add', (
    tester,
  ) async {
    final (added, container) = await _open(
      tester,
      seed: (c) => c
          .read(appSettingsProvider.notifier)
          .setLastProjectorLogin('admin1', 'panasonic'),
    );
    expect(find.text('Last used'), findsOneWidget);
    final login = tester.widget<TextField>(
      find.byKey(const ValueKey('projector-login')).hitTestable(),
    );
    expect(login.controller!.text, 'admin1');

    await tester.enterText(
      find.byKey(const ValueKey('projector-login')).hitTestable(),
      'operator',
    );
    await tester.pump();
    expect(find.text('Last used'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('add-ip')),
      '192.168.0.41',
    );
    await tester.pump();
    expect(find.text('Not in project yet'), findsOneWidget);
    await tester.tap(_addButton('Add projector'));
    await tester.pumpAndSettle();

    expect(added.single.single['ip'], '192.168.0.41');
    expect(added.single.single['port'], 1024);
    expect(added.single.single['login'], 'operator');
    final settings = container.read(appSettingsProvider);
    expect(settings.lastProjectorLogin, 'operator');
    expect(settings.lastProjectorPassword, 'panasonic');
  });

  testWidgets('Address: an address in the project disables Add', (
    tester,
  ) async {
    await _open(tester, existingIps: ['192.168.0.41']);
    await tester.enterText(
      find.byKey(const ValueKey('add-ip')),
      '192.168.0.41',
    );
    await tester.pump();
    expect(find.text('Already in project'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_addButton('Add projector')).onPressed,
      isNull,
    );
  });

  testWidgets('IP range counts only new addresses', (tester) async {
    final (added, _) = await _open(
      tester,
      existingIps: ['192.168.0.13', '192.168.0.18'],
    );
    await tester.tap(find.text('IP range'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('range-from')),
      '192.168.0.10',
    );
    await tester.enterText(find.byKey(const ValueKey('range-to')), '21');
    await tester.pump();

    expect(find.text('12 addresses'), findsOneWidget);
    expect(find.text('10 new'), findsOneWidget);
    expect(find.text('2 in project'), findsOneWidget);
    expect(find.text('Skipped, already in project:'), findsOneWidget);
    expect(find.text('.13'), findsNWidgets(2)); // cell and skip chip

    await tester.tap(_addButton('Add 10 projectors'));
    await tester.pumpAndSettle();
    final ips = added.single.map((p) => p['ip']).toList();
    expect(ips, hasLength(10));
    expect(ips, isNot(contains('192.168.0.13')));
    expect(ips, isNot(contains('192.168.0.18')));
  });

  testWidgets('a long range shows a dense strip and collapsed skip chips', (
    tester,
  ) async {
    await _open(
      tester,
      existingIps: [
        '192.168.0.31',
        '192.168.0.32',
        '192.168.0.33',
        '192.168.0.47',
      ],
    );
    await tester.tap(find.text('IP range'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('range-from')),
      '192.168.0.10',
    );
    await tester.enterText(find.byKey(const ValueKey('range-to')), '59');
    await tester.pump();

    expect(find.text('50 addresses'), findsOneWidget);
    expect(find.text('.31 to .33'), findsOneWidget);
    expect(find.text('.59'), findsOneWidget); // axis end
    expect(_addButton('Add 46 projectors'), findsOneWidget);
  });

  testWidgets('Discover shows a badge per scan status', (tester) async {
    final fake = FakeProtocolService()
      ..scanResults.addAll([
        {'ip': '192.168.0.10', 'name': 'RZ34K', 'status': 'online'},
        {'ip': '192.168.0.11', 'name': 'RZ34K', 'status': 'online'},
        {'ip': '192.168.0.14', 'name': 'RQ25K', 'status': 'unprotected'},
        {'ip': '192.168.0.15', 'name': '192.168.0.15', 'status': 'auth_error'},
      ]);
    final (added, _) = await _open(
      tester,
      fake: fake,
      existingIps: ['192.168.0.10'],
    );
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(fake.scans.single.$1, '192.168.0');
    expect(find.text('4 projectors found'), findsOneWidget);
    expect(find.text('on 192.168.0.0/24'), findsOneWidget);
    expect(find.text('Scan complete'), findsOneWidget);
    expect(find.text('In project'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('No login'), findsOneWidget);
    expect(find.text('Wrong login'), findsOneWidget);
    expect(
      find.textContaining('3 of 3 new selected', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(_addButton('Add 3 projectors'));
    await tester.pumpAndSettle();
    expect(added.single.map((p) => (p['ip'], p['status'])), [
      ('192.168.0.11', 'online'),
      ('192.168.0.14', 'unprotected'),
      ('192.168.0.15', 'auth_error'),
    ]);
  });

  group('800x600 window', () {
    for (final tab in ['Address', 'IP range', 'Discover']) {
      testWidgets('$tab lays out without overflow', (tester) async {
        final fake = FakeProtocolService()
          ..scanResults.addAll([
            for (var i = 10; i < 30; i++)
              {'ip': '192.168.0.$i', 'name': 'RZ34K', 'status': 'online'},
          ]);
        await _open(tester, fake: fake, window: const Size(800, 600));
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        if (tab == 'IP range') {
          await tester.enterText(
            find.byKey(const ValueKey('range-from')),
            '192.168.0.10',
          );
          await tester.enterText(find.byKey(const ValueKey('range-to')), '59');
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
