import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blending_dialog.dart';

import '../helpers/fake_protocol_service.dart';

const _a = ProjectorNode(
  id: 'a',
  name: 'PRJ-01',
  ipAddress: '10.0.0.1',
  x: 0,
  y: 0,
);
const _b = ProjectorNode(
  id: 'b',
  name: 'PRJ-02',
  ipAddress: '10.0.0.2',
  x: 200,
  y: 0,
);

void main() {
  late FakeProtocolService fake;

  setUp(() {
    fake = FakeProtocolService();
    fake.rawResponses.addAll({
      'QVX:EDBI0': 'EDBI0=+00001',
      'QID': 'PT-RQ35K',
      'QGL': '1',
      'QGR': '1',
      'QVX:ELWI0': 'ELWI0=+00192',
      'QVX:ERWI0': 'ERWI0=+00192',
      'QJI': '000,000,000,000',
    });
  });

  Future<void> pumpPair(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [protocolServiceProvider.overrideWithValue(fake)],
        // Not const: the dialog's assert reads the list's length.
        child: MaterialApp(
          // The test font's square glyphs overflow the fixed-width labels.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(0.5)),
            child: child!,
          ),
          home: Scaffold(body: EdgeBlendingDialog(nodes: [_a, _b])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The Link toggle shows `link` when on, `link_off` when off.
  testWidgets('pair: the facing card has Link on', (tester) async {
    await pumpPair(tester);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsNothing);
  });

  testWidgets('pair: the linked overlapped row shows the link icon', (
    tester,
  ) async {
    await pumpPair(tester);
    await tester.tap(find.text('Black Level'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('Link turned on before Black Level loads copies the level '
      'once it has', (tester) async {
    fake.rawResponsesByIp[_a.ipAddress] = {
      'QVX:EBBS3': 'EBBS3=010,010,010,010',
    };
    await pumpPair(tester);
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();
    fake.sentRaw.clear();
    await tester.tap(find.text('Black Level'));
    await tester.pumpAndSettle();
    expect(fake.sentRaw, contains((_b.ipAddress, 'VXX:EBBS2=010,010,010,010')));
  });

  testWidgets('pair: the link icon follows the active projector', (
    tester,
  ) async {
    await pumpPair(tester);
    await tester.tap(find.text('Black Level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRJ-02').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.link), findsOneWidget);
  });
}
