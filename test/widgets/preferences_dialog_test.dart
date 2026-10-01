import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/preferences_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  // The app's minimum window size — the dialog must fit it without overflow.
  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
        ],
        child: const MaterialApp(home: Scaffold(body: PreferencesDialog())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('every section lays out at the minimum window size', (
    tester,
  ) async {
    await pumpDialog(tester);
    expect(find.text('Update interval'), findsOneWidget);

    await openSection(tester, 'OSC');
    expect(find.text('Network interface'), findsOneWidget);

    await openSection(tester, 'Web Access');
    expect(find.text('Viewer PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected PIN jumps to Web Access and names the field', (
    tester,
  ) async {
    await pumpDialog(tester);
    await openSection(tester, 'Web Access');
    // The service card's switch comes first on the page.
    await tester.tap(find.byType(Switch).first);
    await openSection(tester, 'General');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Viewer PIN'), findsOneWidget);
    expect(find.text('Viewer PIN: Required'), findsOneWidget);
    expect(find.byType(PreferencesDialog), findsOneWidget);
  });
}
