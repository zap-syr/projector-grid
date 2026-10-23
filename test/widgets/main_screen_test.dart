import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/providers/alignment_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/project_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/top_menu_bar.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

void main() {
  useTempConfigDir();

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('IndexedStack focus quirk', () {
    testWidgets('Ctrl+A still selects all after Controls ↔ Monitoring', (
      tester,
    ) async {
      await pumpApp(tester, FakeProtocolService());
      final c = appContainer(tester);
      c.read(workspaceProvider.notifier).setNodes([node('1'), node('2')]);
      await tester.pumpAndSettle();

      await ctrl(tester, LogicalKeyboardKey.keyA);
      expect(c.read(selectionProvider), {'1', '2'}, reason: 'before switch');

      c.read(workspaceProvider.notifier).deselectAll();
      await ctrl(tester, LogicalKeyboardKey.digit2); // → Monitoring
      await ctrl(tester, LogicalKeyboardKey.digit1); // → Controls
      await ctrl(tester, LogicalKeyboardKey.keyA);
      expect(c.read(selectionProvider), {'1', '2'}, reason: 'after switch');
    });
  });

  group('window close', () {
    testWidgets('clean project closes without asking', (tester) async {
      final calls = await pumpApp(tester, FakeProtocolService());
      await sendWindowEvent(tester, 'close');
      expect(find.text('Unsaved changes'), findsNothing);
      expect(calls, contains('destroy'));
    });

    testWidgets('unsaved changes ask first; Cancel keeps the window', (
      tester,
    ) async {
      final calls = await pumpApp(tester, FakeProtocolService());
      final c = appContainer(tester);
      c.read(workspaceProvider.notifier).setNodes([node('1')]);
      drag(c, '1', const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(c.read(projectStateProvider).isDirty, isTrue);

      await sendWindowEvent(tester, 'close');
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('destroy')));
    });

    testWidgets('File, Exit leaves Alignment mode first, as Ctrl+Q does', (
      tester,
    ) async {
      final fake = FakeProtocolService()
        ..rawResponses.addAll({
          'QSH': '0',
          'QTS': '00',
          'QVX:SEFS1': 'SEFS1=0.0',
          'QVX:SEFS2': 'SEFS2=0.0',
        });
      final calls = await pumpApp(tester, fake);
      final c = appContainer(tester);
      c.read(workspaceProvider.notifier).setNodes([node('1'), node('2')]);
      await tester.pumpAndSettle();
      await c.read(alignmentProvider.notifier).enter();
      await tester.pumpAndSettle();
      expect(c.read(alignmentProvider).active, isTrue);

      // What File, Exit does, from the menu bar's context. (Opening the menu
      // here overflows its labels in the test font.)
      Actions.invoke(
        tester.element(find.byType(TopMenuBar)),
        const ExitIntent(),
      );
      await tester.pumpAndSettle();
      // The unsaved project asks first.
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(c.read(alignmentProvider).active, isFalse);
      expect(calls, contains('destroy'));
    });

    testWidgets('Discard closes the window', (tester) async {
      final calls = await pumpApp(tester, FakeProtocolService());
      final c = appContainer(tester);
      c.read(workspaceProvider.notifier).setNodes([node('1')]);
      drag(c, '1', const Offset(20, 0));
      await tester.pumpAndSettle();

      await sendWindowEvent(tester, 'close');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(calls, contains('destroy'));
    });
  });
}
