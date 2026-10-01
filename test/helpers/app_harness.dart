import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/app/app.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/screens/main_workspace_screen.dart';

import 'fake_protocol_service.dart';

const windowManagerChannel = MethodChannel('window_manager');

/// Pumps the whole app at 1920x1080 with a fake protocol service and a mocked
/// `window_manager` channel. Returns the method names the app invoked on it.
Future<List<String>> pumpApp(
  WidgetTester tester,
  FakeProtocolService fake, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final windowCalls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowManagerChannel,
    (call) async {
      windowCalls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowManagerChannel,
      null,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        ...overrides,
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return windowCalls;
}

ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MainWorkspaceScreen)));

/// Delivers a native window event (e.g. `close`) the way the plugin does.
Future<void> sendWindowEvent(WidgetTester tester, String eventName) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    windowManagerChannel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onEvent', {'eventName': eventName}),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}
