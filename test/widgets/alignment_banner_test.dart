import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/alignment_banner.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

class _FakeAlignment extends AlignmentNotifier {
  void show({required Set<String> scope, required String focusedId}) =>
      state = state.copyWith(active: true, scope: scope, focusedId: focusedId);
}

void main() {
  useTempConfigDir();

  Future<void> pumpBanner(
    WidgetTester tester, {
    required int count,
    required int focused,
  }) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(FakeProtocolService()),
          alignmentProvider.overrideWith(_FakeAlignment.new),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: Column(children: [AlignmentBanner()])),
        ),
      ),
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(AlignmentBanner)),
    );
    c.read(workspaceProvider.notifier).setNodes([
      for (var i = 1; i <= count; i++) node('$i', x: i * 150.0, y: 40),
    ]);
    (c.read(alignmentProvider.notifier) as _FakeAlignment).show(
      scope: {for (var i = 1; i <= count; i++) '$i'},
      focusedId: '$focused',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a short counter keeps its 40 px width', (tester) async {
    await pumpBanner(tester, count: 4, focused: 1);
    expect(tester.getSize(find.text('1/4')).width, 40);
    expect(tester.getSize(find.byType(AlignmentBanner)).height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long counter grows to its content without overflow', (
    tester,
  ) async {
    await pumpBanner(tester, count: 120, focused: 100);
    expect(find.text('100/120'), findsOneWidget);
    expect(tester.getSize(find.text('100/120')).width, greaterThan(40));
    expect(tester.getSize(find.byType(AlignmentBanner)).height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the counter takes the description role in the on-accent colour',
    (tester) async {
      await pumpBanner(tester, count: 4, focused: 1);
      final style = tester
          .widget<Text>(find.text('1/4'))
          .style!
          .merge(DefaultTextStyle.of(tester.element(find.text('1/4'))).style);
      expect(style.fontSize, 12.5);
      expect(style.color, AppTheme.onAlignmentAccent);
    },
  );
}
