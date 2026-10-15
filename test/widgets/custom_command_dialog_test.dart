import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/custom_command.dart';
import 'package:projector_grid/features/workspace/presentation/providers/custom_commands_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_command_dialog.dart';

import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  /// Pumps the dialog in the app's minimum window (800×600) with [existing]
  /// commands saved, and returns the container holding them.
  Future<ProviderContainer> pumpDialog(
    WidgetTester tester, {
    List<(String, String)> existing = const [],
    CustomCommand? Function(ProviderContainer)? editing,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The control bar keeps this alive in the app.
    container.listen(customCommandsProvider, (_, _) {});
    for (final (name, command) in existing) {
      container.read(customCommandsProvider.notifier).add(name, command);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CustomCommandDialog(existing: editing?.call(container)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder field(int i) => find.byType(TextField).at(i);

  testWidgets('both OSC addresses follow the name', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Type a name to get the address'), findsNWidgets(2));

    await tester.enterText(field(0), 'Dynamic Contrast!');
    await tester.pump();

    expect(find.text('/pgrid/all/custom/dynamic-contrast'), findsOneWidget);
    expect(
      find.text('/pgrid/group/{group-name}/custom/dynamic-contrast'),
      findsOneWidget,
    );
    expect(find.text('Follow the name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a taken address names the command and disables Add', (
    tester,
  ) async {
    final container = await pumpDialog(
      tester,
      existing: [('Shutter Close', 'OSH:1')],
    );
    await tester.enterText(field(0), 'shutter close!');
    await tester.enterText(field(1), 'OSH:1');
    await tester.pump();

    expect(
      find.text('Another command already has this OSC address'),
      findsOneWidget,
    );
    expect(find.text('Taken by "Shutter Close"'), findsOneWidget);
    final add = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Add command'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(add.onPressed, isNull);

    await tester.enterText(field(0), 'Shutter Open');
    await tester.pump();
    await tester.tap(find.text('Add command'));
    await tester.pumpAndSettle();
    expect(container.read(customCommandsProvider).map((c) => c.name), [
      'Shutter Close',
      'Shutter Open',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit shows Save and the rename note', (tester) async {
    await pumpDialog(
      tester,
      existing: [('Freeze On', 'OFZ:1')],
      editing: (c) => c.read(customCommandsProvider).single,
    );
    expect(find.text('Edit Command'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Renaming changes the OSC address'), findsOneWidget);
    // Its own address isn't "taken" by itself.
    expect(find.text('/pgrid/all/custom/freeze-on'), findsOneWidget);
    expect(find.text('Follow the name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
