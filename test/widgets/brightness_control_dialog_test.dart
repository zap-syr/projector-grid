import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/brightness_control_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/skeleton.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/step_buttons.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  late FakeProtocolService fake;

  setUp(() => fake = FakeProtocolService());

  // Past the ~400 ms debounce of the − / + buttons.
  const pastDebounce = Duration(milliseconds: 600);

  /// LOPI values: 80 = 8%, 1000 = 100%, so 10 per percent above 8%.
  Future<void> pumpDialog(
    WidgetTester tester, {
    String mode = '+00000',
    int lopi2 = 500,
    int lopi3 = 1000,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fake.rawResponses.addAll({
      'QVX:OPEI1': 'OPEI1=$mode',
      'QVX:LOPI2': 'LOPI2=+${lopi2.toString().padLeft(5, '0')}',
      'QVX:LOPI3': 'LOPI3=+${lopi3.toString().padLeft(5, '0')}',
    });
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
                    builder: (_) => const BrightnessControlDialog(
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
    // The skeleton pulses forever, so pumpAndSettle would time out while
    // loading; the fake answers within a few frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> writes() => [
    for (final (_, cmd) in fake.sentRaw)
      if (cmd.startsWith('VXX:')) cmd,
  ];

  // The big value is a rich text: digits, then a smaller `%`.
  Finder value(String text) => find.text(text, findRichText: true);

  // Order in the dialog: Light output −, +, then Max light output −, +.
  Finder stepButton(int i) => find.byType(StepButton).at(i);

  IconButton iconButtonOf(WidgetTester tester, int i) => tester.widget(
    find.descendant(of: stepButton(i), matching: find.byType(IconButton)),
  );

  testWidgets('loads mode and values, no writes on open', (tester) async {
    await pumpDialog(tester, lopi2: 850);
    expect(find.byType(Skeleton), findsNothing);
    expect(value('85%'), findsOneWidget);
    expect(find.text('Changes are sent to the projector right away'), findsOne);
    expect(find.text('Done'), findsNothing);
    expect(writes(), isEmpty);
  });

  testWidgets('Max card is locked outside User modes', (tester) async {
    await pumpDialog(tester, mode: '+00001');
    expect(find.text('Only in User 1, 2 or 3 mode'), findsOneWidget);
    expect(find.text('User modes'), findsOneWidget);
    expect(iconButtonOf(tester, 2).onPressed, isNull);
    expect(iconButtonOf(tester, 3).onPressed, isNull);
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders[1].onChanged, isNull);

    // A User mode unlocks it; the tap sends the mode at once.
    await tester.tap(find.text('User 2'));
    await tester.pump();
    expect(writes(), ['VXX:OPEI1=+00102']);
    expect(find.text('User modes'), findsNothing);
    expect(find.text('Ceiling for Light output in this User mode'), findsOne);
    expect(iconButtonOf(tester, 2).onPressed, isNotNull);
  });

  testWidgets('Light output is capped at Max in a User mode', (tester) async {
    // Light 90%, Max 80%: shown at the cap, + disabled, a drag stops there.
    await pumpDialog(tester, mode: '+00102', lopi2: 900, lopi3: 800);
    expect(find.text('Limited to 80% by Max light output'), findsOneWidget);
    expect(find.text('Max 80%'), findsOneWidget);
    expect(value('80%'), findsNWidgets(2));
    expect(iconButtonOf(tester, 1).onPressed, isNull);

    final lightSlider = find.byType(Slider).first;
    await tester.drag(lightSlider, const Offset(400, 0));
    await tester.pump();
    expect(writes(), ['VXX:LOPI2=+00800']);
  });

  testWidgets('a burst of + presses sends one LOPI2 write', (tester) async {
    await pumpDialog(tester, lopi2: 500);
    for (var i = 0; i < 5; i++) {
      await tester.tap(stepButton(1));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(value('55%'), findsOneWidget);
    expect(writes(), isEmpty, reason: 'still inside the debounce');

    await tester.pump(pastDebounce);
    expect(writes(), ['VXX:LOPI2=+00550']);
  });

  testWidgets('lowering Max drops a pending Light output press above it', (
    tester,
  ) async {
    await pumpDialog(tester, mode: '+00101', lopi2: 700, lopi3: 800);
    await tester.tap(stepButton(1)); // Light 71%, waiting in the debounce
    await tester.pump();
    await tester.drag(find.byType(Slider).at(1), const Offset(-600, 0));
    await tester.pump();
    await tester.pump(pastDebounce);
    expect(writes(), ['VXX:LOPI3=+00080']);
  });

  testWidgets('a pending press is still sent when the dialog closes', (
    tester,
  ) async {
    await pumpDialog(tester, mode: '+00101', lopi2: 500, lopi3: 800);
    await tester.tap(stepButton(2));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(writes(), ['VXX:LOPI3=+00790']);
  });

  testWidgets('loading shows the skeleton layout and the reading footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The fake replies asynchronously, so the first frame is still loading.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: BrightnessControlDialog(
              node: ProjectorNode(
                id: '1',
                name: 'P',
                ipAddress: '10.0.0.1',
                x: 0,
                y: 0,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Skeleton), findsWidgets);
    expect(
      find.text('Reading current values from the projector…'),
      findsOneWidget,
    );
    expect(find.text('Light output'), findsOneWidget);
    expect(find.text('Max light output'), findsOneWidget);
  });

  for (final mode in ['+00000', '+00102']) {
    testWidgets('lays out without overflow at 800x600 ($mode)', (tester) async {
      await pumpDialog(
        tester,
        mode: mode,
        lopi3: 800,
        size: const Size(800, 600),
      );
      expect(tester.takeException(), isNull);
      // The Dialog's own Material: the Dialog widget spans its insets.
      final dialog = tester.getSize(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.width, lessThanOrEqualTo(560));
      expect(dialog.height, lessThanOrEqualTo(600));
    });
  }
}
