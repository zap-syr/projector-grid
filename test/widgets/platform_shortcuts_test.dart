import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/selection_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _ctrl = LogicalKeyboardKey.controlLeft;
const _meta = LogicalKeyboardKey.metaLeft;

void main() {
  useTempConfigDir();

  /// Runs [body] on [platform] with the app pumped and two projectors loaded.
  /// The override is reset in a finally: the binding asserts it is unset
  /// right after the test body, before any tearDown runs.
  void platformTest(
    String name,
    TargetPlatform platform,
    Future<void> Function(WidgetTester tester, ProviderContainer c) body,
  ) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        // The native menu bar the app builds on macOS talks to this channel.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/menu'),
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('flutter/menu'),
            null,
          ),
        );
        await pumpApp(tester, FakeProtocolService());
        final c = appContainer(tester);
        c.read(workspaceProvider.notifier).setNodes([node('1'), node('2')]);
        await tester.pumpAndSettle();
        await body(tester, c);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  double x1(ProviderContainer c) =>
      c.read(workspaceProvider).firstWhere((n) => n.id == '1').x;
  bool monitoring(ProviderContainer c) =>
      c.read(appSettingsProvider).isMonitoringView;

  group('Windows', () {
    platformTest(
      'Ctrl+A selects all, Meta+A does nothing',
      TargetPlatform.windows,
      (tester, c) async {
        await chord(tester, _meta, LogicalKeyboardKey.keyA);
        expect(c.read(selectionProvider), isEmpty);
        await chord(tester, _ctrl, LogicalKeyboardKey.keyA);
        expect(c.read(selectionProvider), {'1', '2'});
      },
    );

    platformTest(
      'Ctrl+Z undoes and Ctrl+Y redoes; Meta+Z does nothing',
      TargetPlatform.windows,
      (tester, c) async {
        drag(c, '1', const Offset(20, 0));
        await tester.pumpAndSettle();
        expect(x1(c), 60);

        await chord(tester, _meta, LogicalKeyboardKey.keyZ);
        expect(x1(c), 60);
        await chord(tester, _ctrl, LogicalKeyboardKey.keyZ);
        expect(x1(c), 40);
        await chord(tester, _ctrl, LogicalKeyboardKey.keyY);
        expect(x1(c), 60);
      },
    );

    platformTest(
      'Ctrl+1 / Ctrl+2 switch views; Meta+1 does nothing',
      TargetPlatform.windows,
      (tester, c) async {
        await chord(tester, _meta, LogicalKeyboardKey.digit2);
        expect(monitoring(c), isFalse);
        await chord(tester, _ctrl, LogicalKeyboardKey.digit2);
        expect(monitoring(c), isTrue);
        await chord(tester, _meta, LogicalKeyboardKey.digit1);
        expect(monitoring(c), isTrue);
        await chord(tester, _ctrl, LogicalKeyboardKey.digit1);
        expect(monitoring(c), isFalse);
      },
    );
  });

  group('macOS', () {
    platformTest(
      'Cmd+A selects all, Ctrl+A does nothing',
      TargetPlatform.macOS,
      (tester, c) async {
        await chord(tester, _ctrl, LogicalKeyboardKey.keyA);
        expect(c.read(selectionProvider), isEmpty);
        await chord(tester, _meta, LogicalKeyboardKey.keyA);
        expect(c.read(selectionProvider), {'1', '2'});
      },
    );

    platformTest(
      'Cmd+Z undoes; Ctrl+Z and Ctrl+Y do nothing',
      TargetPlatform.macOS,
      (tester, c) async {
        drag(c, '1', const Offset(20, 0));
        await tester.pumpAndSettle();
        expect(x1(c), 60);

        await chord(tester, _ctrl, LogicalKeyboardKey.keyZ);
        expect(x1(c), 60);
        await chord(tester, _meta, LogicalKeyboardKey.keyZ);
        expect(x1(c), 40);
        await chord(tester, _ctrl, LogicalKeyboardKey.keyY);
        expect(x1(c), 40);
      },
    );

    platformTest(
      'Cmd+1 / Cmd+2 switch views; Ctrl+1 does nothing',
      TargetPlatform.macOS,
      (tester, c) async {
        await chord(tester, _ctrl, LogicalKeyboardKey.digit2);
        expect(monitoring(c), isFalse);
        await chord(tester, _meta, LogicalKeyboardKey.digit2);
        expect(monitoring(c), isTrue);
        await chord(tester, _ctrl, LogicalKeyboardKey.digit1);
        expect(monitoring(c), isTrue);
        await chord(tester, _meta, LogicalKeyboardKey.digit1);
        expect(monitoring(c), isFalse);
      },
    );
  });
}
