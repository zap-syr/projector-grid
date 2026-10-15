import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/add_projector/add_tab_shared.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/add_projector/discover_results.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/add_projector/range_preview.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/add_projector_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';

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

// `.first`: the button holds its label twice (the real one and the widest,
// invisible, that fixes its width), so the finder matches it twice.
Finder _addButton(String label) =>
    find.widgetWithText(FilledButton, label).hitTestable().first;

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

    await tester.tap(_addButton('Add projectors'));
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
    expect(find.text('46 new'), findsOneWidget);
  });

  testWidgets('the field row and Port stay put across the tabs', (
    tester,
  ) async {
    await _open(tester);
    Rect port() =>
        tester.getRect(find.byKey(const ValueKey('port')).hitTestable());
    final addressPort = port();
    final ipTop = tester.getTopLeft(find.byKey(const ValueKey('add-ip'))).dy;

    await tester.tap(find.text('IP range'));
    await tester.pumpAndSettle();
    expect(port(), addressPort);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('range-from'))).dy,
      ipTop,
    );

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(port(), addressPort);
    expect(
      tester.getSize(find.byType(DropdownMenu<String>)).height,
      addressPort.height,
      reason: 'the interface dropdown is as tall as Port',
    );
  });

  testWidgets('the Projector login card keeps its place across the tabs', (
    tester,
  ) async {
    await _open(tester);
    double cardTop() => tester
        .getTopLeft(
          find
              .ancestor(
                of: find.byKey(const ValueKey('projector-login')).hitTestable(),
                matching: find.byType(DialogCard),
              )
              .first,
        )
        .dy;
    final address = cardTop();
    await tester.tap(find.text('IP range'));
    await tester.pumpAndSettle();
    expect(cardTop(), address);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(cardTop(), address);
  });

  // The test font (Ahem) is much wider than Segoe and wraps the login card's
  // subtitle, so whether IP range fits the full-size dialog can't be judged
  // here; DialogScrollBody's fill behaviour is tested on its own instead.
  group('DialogScrollBody fill', () {
    Future<double> pumpBody(WidgetTester tester, double height) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: height,
                child: const DialogScrollBody(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
                  fillGap: 16,
                  fill: SizedBox(key: ValueKey('fill'), height: 100),
                  child: SizedBox(height: 200),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getBottomLeft(find.byKey(const ValueKey('fill'))).dy;
    }

    testWidgets('stretches to the bottom padding when there is room', (
      tester,
    ) async {
      expect(await pumpBody(tester, 500), 500 - 20);
      expect(
        tester.getSize(find.byKey(const ValueKey('fill'))).height,
        500 - 20 - 200 - 16 - 20,
      );
    });

    testWidgets('keeps its own height and scrolls when there is not', (
      tester,
    ) async {
      await pumpBody(tester, 300);
      expect(tester.getSize(find.byKey(const ValueKey('fill'))).height, 100);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 20 + 200 + 16 + 100 + 20 - 300);
    });
  });

  testWidgets('the range preview keeps its height while a range is typed', (
    tester,
  ) async {
    await _open(tester, existingIps: ['192.168.0.12']);
    await tester.tap(find.text('IP range'));
    await tester.pumpAndSettle();
    // The preview is the last card: its bottom edge moving is a jump.
    double previewBottom() => tester
        .getBottomLeft(
          find.byWidgetPredicate(
            (w) => w is RangePreview || w is RangePreviewPlaceholder,
          ),
        )
        .dy;
    final before = previewBottom();

    await tester.enterText(
      find.byKey(const ValueKey('range-from')),
      '192.168.0.10',
    );
    await tester.enterText(find.byKey(const ValueKey('range-to')), '15');
    await tester.pump();
    expect(previewBottom(), before, reason: 'labelled strip, one skipped');

    await tester.enterText(find.byKey(const ValueKey('range-to')), '200');
    await tester.pump();
    expect(previewBottom(), before, reason: 'dense strip with axis');

    await tester.enterText(find.byKey(const ValueKey('range-to')), '5');
    await tester.pump();
    expect(find.textContaining('Not lower than'), findsOneWidget);
    expect(
      previewBottom(),
      before,
      reason: 'an error line takes no extra room',
    );
  });

  testWidgets('the ✕ in each field empties it without moving the field', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (c) => c
          .read(appSettingsProvider.notifier)
          .setLastProjectorLogin('admin1', 'panasonic'),
    );
    Finder field(String key) => find.byKey(ValueKey(key)).hitTestable();
    final loginRect = tester.getRect(field('projector-login'));
    final passwordRect = tester.getRect(field('projector-password'));

    await tester.tap(field('clear-login'));
    await tester.pump();
    expect(
      tester.widget<TextField>(field('projector-login')).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(field('projector-password')).controller!.text,
      'panasonic',
      reason: 'each ✕ clears only its own field',
    );
    expect(find.text('Last used'), findsNothing);

    await tester.tap(field('clear-password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(field('projector-password')).controller!.text,
      isEmpty,
    );
    expect(tester.getRect(field('projector-login')), loginRect);
    expect(tester.getRect(field('projector-password')), passwordRect);
  });

  testWidgets('Discover hints name the fields until they take focus', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    InputDecoration deco(String key) => tester
        .widget<TextField>(find.byKey(ValueKey(key)).hitTestable())
        .decoration!;
    expect(deco('projector-login').hintText, 'Login');
    expect(deco('projector-password').hintText, 'Password');

    await tester.tap(
      find.byKey(const ValueKey('projector-login')).hitTestable(),
    );
    await tester.pump();
    expect(deco('projector-login').hintText, isNull);
    expect(deco('projector-password').hintText, 'Password');
  });

  testWidgets('Add button and Cancel keep their place across the tabs', (
    tester,
  ) async {
    await _open(tester);
    Rect action() => tester.getRect(
      find.byKey(const ValueKey('dialog-footer-action')).hitTestable(),
    );
    Rect cancel() =>
        tester.getRect(find.widgetWithText(TextButton, 'Cancel').hitTestable());
    expect(find.text('Add projector').hitTestable(), findsOneWidget);
    final a = action();
    final c = cancel();
    for (final tab in ['IP range', 'Discover', 'Address']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(action(), a, reason: tab);
      expect(cancel(), c, reason: tab);
    }
  });

  testWidgets('the login card heading matches on Discover; the list keeps '
      'its height', (tester) async {
    await _open(tester);
    // Top-left only: the one-row card gives the title less width.
    Offset heading() =>
        tester.getTopLeft(find.text('Projector login').hitTestable());
    Rect tile() =>
        tester.getRect(find.byIcon(Icons.lock_outline).hitTestable());
    final addressHeading = heading();
    final addressTile = tile();
    double passwordRight() => tester
        .getTopRight(
          find.byKey(const ValueKey('projector-password')).hitTestable(),
        )
        .dx;
    final addressPasswordRight = passwordRight();
    final addressCardFinder = find
        .ancestor(
          of: find.text('Projector login').hitTestable(),
          matching: find.byType(DialogCard),
        )
        .first;
    final addressCard = tester.getRect(addressCardFinder);
    // Where the full card's heading band ends: its divider.
    final addressHeadingBottom = tester
        .getBottomLeft(
          find.descendant(
            of: addressCardFinder,
            matching: find.byType(Divider),
          ),
        )
        .dy;

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(heading(), addressHeading);
    expect(tile(), addressTile);
    expect(
      passwordRight(),
      addressPasswordRight,
      reason: 'Password ends at the card padding, as on the other tabs',
    );
    final discoverCard = tester.getRect(
      find
          .ancestor(
            of: find.text('Projector login').hitTestable(),
            matching: find.byType(DialogCard),
          )
          .first,
    );
    // The one-row card is exactly the full card's heading band, down to
    // the divider (which stands where the one-row card's border is).
    expect(discoverCard.top, addressCard.top);
    expect(discoverCard.bottom, addressHeadingBottom);
    expect(discoverCard.height, 66, reason: 'was 58, the gap above lost 8');
    // Login card to list: the usual gap.
    expect(
      tester.getTopLeft(find.byType(DiscoverResults)).dy - discoverCard.bottom,
      addTabSectionGap,
    );
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
    expect(fake.scans, isEmpty, reason: 'scans only on Scan');
    expect(find.text('Press Scan to look on 192.168.0.0/24'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Scan'));
    await tester.pumpAndSettle();
    expect(fake.scans.single.$1, '192.168.0');
    expect(find.widgetWithText(FilledButton, 'Scan again'), findsOneWidget);
    expect(find.text('4 projectors found'), findsOneWidget);
    expect(find.text('on 192.168.0.0/24, scan complete'), findsOneWidget);
    expect(find.text('In project'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('No login'), findsOneWidget);
    expect(find.text('Wrong login'), findsOneWidget);
    expect(
      find.textContaining('3 of 3 new selected', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(_addButton('Add projectors'));
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
