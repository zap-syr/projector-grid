import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/mode_tile.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_correction_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// A projector in one of the free-form memories PC-1 to PC-3 whose model has
/// no Free grid (no MIDS1 reply here) opens the dialog exactly like a
/// projector with the correction off: there is no tile to select. The Free
/// grid itself is in `geometry_dialog_free_grid_test.dart`.
void main() {
  useTempConfigDir();

  Future<FakeProtocolService> openDialog(
    WidgetTester tester,
    String mode,
  ) async {
    final fake = FakeProtocolService()
      ..rawResponses.addAll({'QVX:GMMI0': 'GMMI0=$mode', 'QID': 'PT-RQ25K'});
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: GeometryCorrectionDialog(
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    return fake;
  }

  List<String> tileLabels(WidgetTester tester) => [
    for (final t in tester.widgetList<ModeTile>(find.byType(ModeTile))) t.label,
  ];

  String selectedLabel(WidgetTester tester) => tester
      .widgetList<ModeTile>(find.byType(ModeTile))
      .singleWhere((t) => t.selected)
      .label;

  testWidgets('PC-2 shows the same tiles and the Off state as Off', (
    tester,
  ) async {
    final fake = await openDialog(tester, '+00000');
    final offTiles = tileLabels(tester);
    final offSelected = selectedLabel(tester);
    final offStateShown = find.text('Geometry correction is off');
    expect(offStateShown, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final pcFake = await openDialog(tester, '+00004');

    expect(tileLabels(tester), offTiles);
    expect(offTiles, [
      'Off',
      'Keystone',
      'Curved Correction',
      'Corner Correction',
    ]);
    expect(selectedLabel(tester), offSelected);
    expect(selectedLabel(tester), 'Off');
    expect(offStateShown, findsOneWidget);
    expect(
      [for (final (_, c) in pcFake.sentRaw) c]..sort(),
      [for (final (_, c) in fake.sentRaw) c]..sort(),
      reason: 'the same queries, nothing written',
    );
  });

  for (final mode in ['+00003', '+00005']) {
    testWidgets('$mode opens as Off too', (tester) async {
      await openDialog(tester, mode);
      expect(selectedLabel(tester), 'Off');
      expect(find.text('Geometry correction is off'), findsOneWidget);
      expect(tileLabels(tester), hasLength(4));
    });
  }
}
