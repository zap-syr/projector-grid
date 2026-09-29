import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/geometry_correction_dialog.dart';

import '../helpers/fake_protocol_service.dart';

void main() {
  late FakeProtocolService fake;

  setUp(() => fake = FakeProtocolService());

  Future<void> pumpDialog(
    WidgetTester tester, {
    String mode = '+00000',
    String model = 'PT-RQ25K',
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fake.rawResponses.addAll({'QVX:GMMI0': 'GMMI0=$mode', 'QID': model});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: Scaffold(
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
    await tester.pumpAndSettle();
  }

  // The mode enum is private, so match the button by predicate and compare
  // the selected value's name.
  String selectedMode(WidgetTester tester) => (tester.widget(
    find.byWidgetPredicate((w) => w is SegmentedButton).first,
  ) as SegmentedButton).selected.single.toString();

  List<String> writes() => [
    for (final (_, cmd) in fake.sentRaw)
      if (cmd.startsWith('VXX:')) cmd,
  ];

  testWidgets('loads the current mode and its parameters', (tester) async {
    await pumpDialog(tester, mode: '+00010');
    expect(selectedMode(tester), endsWith('corner'));
    final queried = fake.sentRaw.map((s) => s.$2);
    expect(
      queried,
      containsAll(['QVX:GMMI0', 'QID', 'QVX:GMFI1', 'QVX:GMFIF']),
    );
    expect(writes(), isEmpty, reason: 'opening must not write anything');
  });

  testWidgets('unknown mode reply falls back to Off', (tester) async {
    await pumpDialog(tester, mode: '+00099');
    expect(selectedMode(tester), endsWith('off'));
  });

  testWidgets('switching mode sends VXX:GMMI0 and loads that mode', (
    tester,
  ) async {
    await pumpDialog(tester, model: 'PT-RZ120');
    await tester.tap(find.text('Keystone'));
    await tester.pumpAndSettle();
    expect(writes(), ['VXX:GMMI0=+00001']);
    expect(fake.sentRaw.map((s) => s.$2), contains('QVX:GMKS0'));
    expect(selectedMode(tester), endsWith('keystone'));
  });

  testWidgets('Quad Pixel Drive models enable QPD before leaving Off', (
    tester,
  ) async {
    await pumpDialog(tester, model: 'PT-RQ32K');
    await tester.tap(find.text('Corner Correction'));
    await tester.pumpAndSettle();
    expect(writes(), ['VXX:QPDI1=+00001', 'VXX:GMMI0=+00010']);

    // Only from Off — mode to mode doesn't re-send it.
    await tester.tap(find.text('Keystone'));
    await tester.pumpAndSettle();
    expect(writes().last, 'VXX:GMMI0=+00001');
    expect(writes().where((w) => w.startsWith('VXX:QPDI1')), hasLength(1));
  });

  testWidgets('a failed write shows the failure notice', (tester) async {
    await pumpDialog(tester, model: 'PT-RZ120');
    fake.rawResponses['VXX:GMMI0=+00002'] = null;
    await tester.tap(find.text('Curved Correction'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to send: VXX:GMMI0=+00002'), findsOneWidget);
  });
}
