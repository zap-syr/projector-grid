import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/color_correction_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/skeleton.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/step_buttons.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// Answers every write (anything but a `Q…` query) with an echo, and can
/// hold the queries to keep the dialog loading.
class _Fake extends FakeProtocolService {
  Completer<void>? hold;

  @override
  Future<String?> sendRawCommand(
    String ip,
    int port,
    String login,
    String password,
    String cmd,
  ) async {
    if (cmd.startsWith('Q')) await hold?.future;
    final reply = await super.sendRawCommand(ip, port, login, password, cmd);
    return reply ?? (cmd.startsWith('Q') ? null : cmd);
  }
}

void main() {
  useTempConfigDir();

  late _Fake fake;

  setUp(() => fake = _Fake());

  // Past the ~400 ms debounce of − / +, presets and value fields.
  const pastDebounce = Duration(milliseconds: 600);

  void script({
    int method = 0,
    String? qte = '10',
    String red3 = '2048,0000,0000',
  }) {
    fake.rawResponses.addAll({
      'QVX:CMAI0': 'CMAI0=+0000$method',
      'QTE': qte,
      'QMR': red3,
      'QMG': '0000,2048,0000',
      'QMB': '0000,0000,2048',
      for (var i = 0; i < 7; i++)
        'QVX:C7CS$i': 'C7CS$i=${i == 4 ? '2048,0000,2000' : _default7[i]}',
      'QHR': '138',
      'QHG': '128',
      'QHB': '117',
      'QOR': '113',
      'QOG': '128',
      'QOB': '148',
    });
  }

  Future<void> pumpDialog(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ColorCorrectionDialog(
                      node: ProjectorNode(
                        id: '1',
                        name: 'P',
                        ipAddress: '10.0.0.1',
                        x: 0,
                        y: 0,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Skeletons pulse forever, so no pumpAndSettle while loading.
    await tester.pump();
    if (settle) await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> queries() => [
    for (final (_, cmd) in fake.sentRaw)
      if (cmd.startsWith('Q')) cmd,
  ];

  List<String> writes() => [
    for (final (_, cmd) in fake.sentRaw)
      if (!cmd.startsWith('Q')) cmd,
  ];

  Future<void> openTemperature(WidgetTester tester) async {
    await tester.tap(find.text('Color Temperature'));
    await tester.pump();
  }

  Finder tile(String name) => find.byKey(ValueKey('color-tile-$name'));

  Finder changedDot(String name) => find.descendant(
    of: tile(name),
    matching: find.byKey(const ValueKey('color-tile-changed')),
  );

  /// The editor's Reset, enabled only for a changed colour.
  bool resetEnabled(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(find.byKey(const ValueKey('color-reset')))
      .enabled;

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  testWidgets('Off and Default read only the method and the mode', (
    tester,
  ) async {
    script();
    await pumpDialog(tester);
    expect(queries(), unorderedEquals(['QVX:CMAI0', 'QTE']));
    expect(writes(), isEmpty);
    expect(find.text('Color matching is off'), findsOneWidget);
    expect(find.text('Changes are sent to the projector right away'), findsOne);
    expect(find.byType(FilledButton), findsNothing);

    await openTemperature(tester);
    expect(find.text('Default'), findsWidgets);
    expect(find.text('White balance'), findsNothing);
    expect(find.text('Color temperature'), findsNothing);
  });

  testWidgets('3 colors reads its values and white balance', (tester) async {
    script(method: 1, qte: 'ER401', red3: '2048,0096,0000');
    await pumpDialog(tester);
    expect(
      queries(),
      unorderedEquals([
        'QVX:CMAI0',
        'QTE',
        'QMR',
        'QMG',
        'QMB',
        'QHR',
        'QHG',
        'QHB',
        'QOR',
        'QOG',
        'QOB',
      ]),
    );
    // Both states show without switching tabs.
    expect(find.text('3 colors'), findsWidgets);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('2048, 96, 0'), findsOneWidget);
    expect(changedDot('red'), findsOneWidget);
    expect(changedDot('green'), findsNothing);
    // The dot says it; the editor has no "Changed" note.
    expect(find.text('Changed'), findsNothing);
    expect(resetEnabled(tester), isTrue);
  });

  testWidgets('Reset writes the colour\'s default in one write', (
    tester,
  ) async {
    script(method: 1, qte: 'ER401', red3: '2048,0096,0000');
    await pumpDialog(tester);
    final firstRow = find.byKey(const ValueKey('color-channel-0'));
    final rowBefore = tester.getTopLeft(firstRow);
    await tester.tap(find.byKey(const ValueKey('color-reset')));
    await tester.pump();
    expect(writes(), ['VMR:2048,0000,0000']);
    expect(changedDot('red'), findsNothing);
    expect(tester.getTopLeft(firstRow), rowBefore);
    expect(resetEnabled(tester), isFalse);
  });

  testWidgets('7 colors shows a changed dot only on the changed colour', (
    tester,
  ) async {
    script(method: 2, qte: 'ER401');
    await pumpDialog(tester);
    expect(queries(), contains('QVX:C7CS6'));
    expect(queries(), isNot(contains('QMR')));
    expect(changedDot('magenta'), findsOneWidget);
    expect(changedDot('red'), findsNothing);
    expect(resetEnabled(tester), isFalse, reason: 'Red is selected');

    await tester.tap(tile('magenta'));
    await tester.pump();
    expect(resetEnabled(tester), isTrue);
  });

  testWidgets('switching method writes CMAI0, then reads that method', (
    tester,
  ) async {
    script();
    await pumpDialog(tester);
    fake.sentRaw.clear();
    await tester.tap(find.text('7 colors'));
    await tester.pump();
    final sent = fake.sentRaw.map((s) => s.$2).toList();
    expect(sent.first, 'VXX:CMAI0=+00002');
    expect(
      sent.skip(1),
      unorderedEquals([
        for (var i = 0; i < 7; i++) 'QVX:C7CS$i',
        'QHR',
        'QHG',
        'QHB',
        'QOR',
        'QOG',
        'QOB',
      ]),
    );

    // Back to Off: QTE again, since it read ER401 while matching was on.
    fake.sentRaw.clear();
    await tester.tap(find.text('Off').first);
    await tester.pump();
    expect(fake.sentRaw.map((s) => s.$2), ['VXX:CMAI0=+00000', 'QTE']);
  });

  testWidgets('typing a value commits on Enter with one write', (tester) async {
    script(method: 1, qte: 'ER401');
    await pumpDialog(tester);
    await tester.tap(tile('green'));
    await tester.pump();
    await tester.enterText(field('color-channel-2'), '1000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Focus loss after Enter commits the same value again: still one write.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(pastDebounce);
    expect(writes(), ['VMG:0000,2048,1000']);
    expect(changedDot('green'), findsOneWidget);
  });

  testWidgets('a typed Low value is sent as is, not snapped', (tester) async {
    script(qte: '4');
    await pumpDialog(tester);
    await openTemperature(tester);
    expect(find.text('White balance'), findsOneWidget);
    await tester.enterText(field('wb-low-0'), '2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(pastDebounce);
    expect(writes(), ['VOR:130']);
  });

  testWidgets('a User mode switch writes OTE, then reads white balance', (
    tester,
  ) async {
    script(qte: '4');
    await pumpDialog(tester);
    await openTemperature(tester);
    fake.sentRaw.clear();
    await tester.tap(find.text('User 2'));
    await tester.pump();
    final sent = fake.sentRaw.map((s) => s.$2).toList();
    expect(sent.first, 'OTE:09');
    expect(
      sent.skip(1),
      unorderedEquals(['QHR', 'QHG', 'QHB', 'QOR', 'QOG', 'QOB']),
    );
  });

  testWidgets('Custom: presets and − / + bursts send one OTE', (tester) async {
    script(qte: '6500');
    await pumpDialog(tester);
    await openTemperature(tester);
    expect(find.text('6500 K'), findsWidgets, reason: 'tab pill and chip');
    expect(find.text('6500 K', findRichText: true), findsWidgets);

    await tester.tap(find.text('9300 K'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('3200 K').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(writes(), isEmpty);
    await tester.pump(pastDebounce);
    expect(writes(), ['OTE:3200']);

    // − is disabled at 3200 K; + three times is one write.
    final minus = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(StepButton).first,
        matching: find.byType(IconButton),
      ),
    );
    expect(minus.onPressed, isNull);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(StepButton).last);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(pastDebounce);
    expect(writes(), ['OTE:3200', 'OTE:3500']);
  });

  testWidgets('Color Matching fixes the mode, white balance stays', (
    tester,
  ) async {
    script(method: 1, qte: 'ER401');
    await pumpDialog(tester);
    await openTemperature(tester);
    expect(find.text('Color Matching: 3 colors'), findsOneWidget);
    expect(find.text('Fixed while Color Matching is on'), findsOneWidget);
    expect(
      find.text('Still adjustable while Color Matching is on'),
      findsOneWidget,
    );
    final tiles = tester.widgetList<ModeTile>(find.byType(ModeTile));
    expect(tiles.every((t) => t.onTap == null && !t.selected), isTrue);
  });

  testWidgets('a pending press is still sent when the dialog closes', (
    tester,
  ) async {
    script(qte: '6500');
    await pumpDialog(tester);
    await openTemperature(tester);
    await tester.tap(find.byType(StepButton).last);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(writes(), ['OTE:6600']);
  });

  group('layout stays put', () {
    Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

    Rect dialogRect(WidgetTester tester) => rectOf(
      tester,
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );

    /// Tab strip, footer, dialog, and the first card's top-left: the same
    /// in every state of both tabs.
    List<Object> frame(WidgetTester tester) => [
      rectOf(tester, find.byKey(ColorCorrectionDialog.tabsKey)),
      rectOf(tester, find.byType(DialogFooter)),
      dialogRect(tester),
      tester.getTopLeft(find.byKey(ColorCorrectionDialog.firstCardKey)),
    ];

    Size firstCard(WidgetTester tester) =>
        tester.getSize(find.byKey(ColorCorrectionDialog.firstCardKey));

    testWidgets('across loading, methods, modes and tabs', (tester) async {
      final frames = <String, List<Object>>{};
      final methodCards = <String, Size>{};
      final modeCards = <String, Size>{};

      // Loading, both tabs.
      script(method: 1, qte: 'ER401');
      fake.hold = Completer();
      await pumpDialog(tester, settle: false);
      expect(find.byType(Skeleton), findsWidgets);
      frames['loading matching'] = frame(tester);
      methodCards['loading'] = firstCard(tester);
      await openTemperature(tester);
      frames['loading temperature'] = frame(tester);
      modeCards['loading'] = firstCard(tester);
      fake.hold!.complete();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Skeleton), findsNothing);
      frames['fixed'] = frame(tester);
      modeCards['fixed'] = firstCard(tester);

      // Matching tab: 3 colors, 7 colors, Off. The channel rows don't move
      // between the methods or between a changed and an unchanged colour.
      await tester.tap(find.text('Color Matching'));
      await tester.pump();
      frames['3 colors'] = frame(tester);
      methodCards['3 colors'] = firstCard(tester);
      final rowRed3 = tester.getRect(
        find.byKey(const ValueKey('color-channel-0')),
      );
      await tester.tap(find.text('7 colors'));
      await tester.pump();
      frames['7 colors'] = frame(tester);
      methodCards['7 colors'] = firstCard(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('color-channel-0'))),
        rowRed3,
      );
      await tester.tap(tile('magenta'));
      await tester.pump();
      expect(resetEnabled(tester), isTrue);
      expect(
        tester.getRect(find.byKey(const ValueKey('color-channel-0'))),
        rowRed3,
      );
      expect(
        tester.getSize(tile('magenta')).height,
        tester.getSize(tile('red')).height,
      );

      fake.rawResponses['QTE'] = '10';
      await tester.tap(find.text('Off').first);
      await tester.pump();
      frames['off'] = frame(tester);
      methodCards['off'] = firstCard(tester);

      // Temperature tab: Default, User 1, Custom.
      await openTemperature(tester);
      frames['default'] = frame(tester);
      modeCards['default'] = firstCard(tester);
      await tester.tap(find.text('User 1'));
      await tester.pump();
      frames['user'] = frame(tester);
      modeCards['user'] = firstCard(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();
      frames['custom'] = frame(tester);
      modeCards['custom'] = firstCard(tester);

      final reference = frames['loading matching']!;
      for (final MapEntry(:key, :value) in frames.entries) {
        expect(value, reference, reason: key);
      }
      for (final MapEntry(:key, :value) in methodCards.entries) {
        expect(value, methodCards['loading'], reason: 'Method card, $key');
      }
      for (final MapEntry(:key, :value) in modeCards.entries) {
        expect(value, modeCards['loading'], reason: 'Mode card, $key');
      }
    });

    for (final (method, qte, tab) in [
      (0, '10', 0),
      (1, 'ER401', 0),
      (2, 'ER401', 0),
      (1, 'ER401', 1),
      (0, '4', 1),
      (0, '6500', 1),
    ]) {
      testWidgets('no overflow at 800x600 (method $method, QTE $qte, '
          'tab $tab)', (tester) async {
        script(method: method, qte: qte);
        await pumpDialog(tester, size: const Size(800, 600));
        if (tab == 1) await openTemperature(tester);
        expect(tester.takeException(), isNull);
        final dialog = dialogRect(tester);
        expect(dialog.width, lessThanOrEqualTo(640));
        expect(dialog.height, lessThanOrEqualTo(580));
      });
    }
  });
}

const _default7 = [
  '2048,0000,0000',
  '0000,2048,0000',
  '0000,0000,2048',
  '0000,2048,2048',
  '2048,0000,2048',
  '2048,2048,0000',
  '2048,2048,2048',
];
