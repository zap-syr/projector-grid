import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_diagnostics_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry/warp_diagnostics_notice.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _notice = 'Free grid is not available for this model yet.';

final _states = <String, WarpDiagnosticsState>{
  'idle': const WarpDiagnosticsIdle(),
  'reading': const WarpDiagnosticsReading(),
  'saved': const WarpDiagnosticsSaved(r'C:\logs\warp-diagnostics-PT-RZ34K.txt'),
  'failed': const WarpDiagnosticsFailed('Projector busy, try again'),
};

Widget _host(
  WarpDiagnosticsState state, {
  required ThemeData theme,
  double width = 640,
  VoidCallback? onSave,
}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: WarpDiagnosticsStrip(state: state, onSave: onSave ?? () {}),
      ),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  WarpDiagnosticsState state, {
  required ThemeData theme,
  double width = 640,
  VoidCallback? onSave,
}) async {
  await tester.pumpWidget(
    _host(state, theme: theme, width: width, onSave: onSave),
  );
  // A spinner never settles.
  await tester.pump();
}

Finder get _button => find.byType(TextButton);

/// The label the operator sees: the button also holds its longest label
/// invisibly (and out of hit testing) to keep its width.
Finder _visibleText(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text).hitTestable();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final themes = {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme};

  for (final MapEntry(key: themeName, value: theme) in themes.entries) {
    group('in the $themeName theme', () {
      testWidgets('idle: the notice, an info icon and Save diagnostics...', (
        tester,
      ) async {
        await _pump(tester, _states['idle']!, theme: theme);

        expect(find.text(_notice), findsOneWidget);
        expect(_visibleText('Save diagnostics...'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsNothing);
        expect(tester.widget<TextButton>(_button).onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final cs = theme.colorScheme;
        expect(
          tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
          cs.onSurfaceVariant,
        );
        expect(tester.widget<Icon>(find.byIcon(Icons.info_outline)).size, 16);
        expect(
          tester.widget<Text>(find.text(_notice)).style!.color,
          cs.onSurfaceVariant,
        );
      });

      testWidgets('reading: a spinner and a disabled Reading button', (
        tester,
      ) async {
        await _pump(tester, _states['reading']!, theme: theme);

        expect(find.text('Reading'), findsOneWidget);
        expect(_visibleText('Save diagnostics...'), findsNothing);
        expect(find.text(_notice), findsOneWidget);
        expect(tester.widget<TextButton>(_button).onPressed, isNull);
        final spinner = find.byType(CircularProgressIndicator);
        expect(spinner, findsOneWidget);
        expect(
          tester.getSize(
            find.ancestor(of: spinner, matching: find.byType(SizedBox)).first,
          ),
          const Size(16, 16),
        );
      });

      testWidgets('saved: names the file, secondary colour', (tester) async {
        await _pump(tester, _states['saved']!, theme: theme);

        final text = find.text(
          'Diagnostics saved to warp-diagnostics-PT-RZ34K.txt',
        );
        expect(text, findsOneWidget);
        expect(
          tester.widget<Text>(text).style!.color,
          theme.colorScheme.onSurfaceVariant,
        );
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(_visibleText('Save diagnostics...'), findsOneWidget);
        expect(tester.widget<TextButton>(_button).onPressed, isNotNull);
      });

      testWidgets('failed: the reason in the error colour with an error icon', (
        tester,
      ) async {
        await _pump(tester, _states['failed']!, theme: theme);

        final text = find.text(
          'Could not save diagnostics: Projector busy, try again',
        );
        expect(text, findsOneWidget);
        expect(tester.widget<Text>(text).style!.color, theme.colorScheme.error);
        final icon = find.byIcon(Icons.error_outline);
        expect(icon, findsOneWidget);
        expect(tester.widget<Icon>(icon).color, theme.colorScheme.error);
        expect(find.byIcon(Icons.info_outline), findsNothing);
        expect(_visibleText('Save diagnostics...'), findsOneWidget);
        expect(tester.widget<TextButton>(_button).onPressed, isNotNull);
      });

      testWidgets('the strip is 36 high and the button keeps its size in '
          'every state', (tester) async {
        final heights = <String, double>{};
        final buttons = <String, Size>{};
        final buttonLefts = <String, double>{};
        final texts = <String, Offset>{};
        for (final MapEntry(key: name, value: state) in _states.entries) {
          await _pump(tester, state, theme: theme);
          heights[name] = tester
              .getSize(find.byType(WarpDiagnosticsStrip))
              .height;
          buttons[name] = tester.getSize(_button);
          buttonLefts[name] = tester.getTopLeft(_button).dx;
          final message = find.descendant(
            of: find.byType(WarpDiagnosticsStrip),
            matching: find.byType(Text),
          );
          texts[name] = tester.getTopLeft(message.first);
        }

        expect(heights.values.toSet(), {36.0});
        expect(buttons.values.toSet(), hasLength(1), reason: '$buttons');
        expect(
          buttonLefts.values.toSet(),
          hasLength(1),
          reason: '$buttonLefts',
        );
        expect(texts.values.toSet(), hasLength(1), reason: '$texts');
        expect(buttons['idle']!.height, lessThanOrEqualTo(36));
      });

      testWidgets('a long message stays on one line and the strip on 36', (
        tester,
      ) async {
        await _pump(
          tester,
          WarpDiagnosticsFailed('x' * 400),
          theme: theme,
          width: 480,
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(WarpDiagnosticsStrip)).height, 36);
        final text = tester.widget<Text>(
          find.textContaining('Could not save diagnostics'),
        );
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        // The button stays inside the strip.
        expect(
          tester.getTopRight(_button).dx,
          lessThanOrEqualTo(
            tester.getTopRight(find.byType(WarpDiagnosticsStrip)).dx,
          ),
        );
      });

      testWidgets('fills the width it is given', (tester) async {
        await _pump(tester, _states['idle']!, theme: theme, width: 500);
        expect(tester.getSize(find.byType(WarpDiagnosticsStrip)).width, 500);
        expect(
          tester.getTopRight(_button).dx,
          closeTo(500, 0.5),
          reason: 'the button sits at the right edge',
        );
      });

      testWidgets('no SnackBar and no ink splash', (tester) async {
        await _pump(tester, _states['failed']!, theme: theme);

        expect(find.byType(SnackBar), findsNothing);
        final button = tester.widget<TextButton>(_button);
        final style = button.style!;
        expect(style.splashFactory, NoSplash.splashFactory);
      });

      testWidgets('tapping the button calls onSave once', (tester) async {
        var taps = 0;
        await _pump(
          tester,
          _states['idle']!,
          theme: theme,
          onSave: () => taps++,
        );

        await tester.tap(_button);
        await tester.pump();

        expect(taps, 1);
      });

      testWidgets('the Reading button cannot be tapped', (tester) async {
        var taps = 0;
        await _pump(
          tester,
          _states['reading']!,
          theme: theme,
          onSave: () => taps++,
        );

        await tester.tap(_button, warnIfMissed: false);
        await tester.pump();

        expect(taps, 0);
      });
    });
  }

  group('WarpDiagnosticsNotice', () {
    final configDir = useTempConfigDir();

    late FakeProtocolService fake;
    late List<String> dialogNames;
    late Completer<void> hold;

    setUp(() {
      fake = FakeProtocolService()
        ..rawResponses['QVX:MIDS1'] = 'MIDS1=0024:00:30';
      fake.warpFor('10.0.0.1');
      hold = Completer<void>();
      dialogNames = [];
    });

    Future<ProviderContainer> pumpNotice(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            protocolServiceProvider.overrideWithValue(fake),
            warpDiagnosticsAppVersionProvider.overrideWith(
              (ref) async => '2.0.1+13',
            ),
            warpDiagnosticsSaveDialogProvider.overrideWithValue(({
              required title,
              required defaultName,
              required filterLabel,
              required extension,
              initialDirectory,
            }) async {
              dialogNames.add(defaultName);
              return '${configDir().path}/saved.txt';
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: WarpDiagnosticsNotice(nodeId: '1')),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WarpDiagnosticsNotice)),
      );
      container.read(workspaceProvider.notifier).setNodes([node('1')]);
      await tester.pump();
      return container;
    }

    testWidgets('shows the notice and nothing is sent until the button is '
        'pressed', (tester) async {
      await tester.runAsync(() async {
        await pumpNotice(tester);
        await tester.pump();
        expect(find.text(_notice), findsOneWidget);
        expect(fake.sentRaw, isEmpty);
        expect(fake.sentBinary, isEmpty);
      });
    });

    testWidgets('pressing the button reads, then says where it saved', (
      tester,
    ) async {
      fake.holdBinary['10.0.0.1'] = hold;
      await tester.runAsync(() async {
        await pumpNotice(tester);

        await tester.tap(find.byType(TextButton));
        await tester.pump();
        // Real time for the fake network and the async chain.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.text('Reading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        hold.complete();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.text('Diagnostics saved to saved.txt'), findsOneWidget);
        expect(_visibleText('Save diagnostics...'), findsOneWidget);
        expect(dialogNames, hasLength(1));
        expect(dialogNames.single, startsWith('warp-diagnostics-Proj-1-'));
      });
    });
  });
}
