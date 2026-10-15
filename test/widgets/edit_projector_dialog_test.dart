import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edit_projector_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

typedef _Saved = (String ip, int port, String login, String password);

ProjectorNode _projector({
  ConnectionStatus status = ConnectionStatus.connected,
}) => node(
  '1',
  ip: '192.168.0.41',
  status: status,
).copyWith(name: 'RZ34K', login: 'admin1', password: 'panasonic');

Future<List<_Saved>> _open(
  WidgetTester tester,
  ProjectorNode projector, {
  Size window = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final saved = <_Saved>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(FakeProtocolService()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EditProjectorDialog(
                  node: projector,
                  existingIps: const {'192.168.0.42'},
                  onSave: (ip, port, login, password) =>
                      saved.add((ip, port, login, password)),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  ProviderScope.containerOf(tester.element(find.text('open')))
      .read(workspaceProvider.notifier)
      .setNodes([projector]);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return saved;
}

bool _saveEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
        .onPressed !=
    null;

void main() {
  useTempConfigDir();

  testWidgets('shows the projector card and a masked password', (tester) async {
    await _open(tester, _projector());
    expect(find.text('RZ34K'), findsOneWidget);
    expect(find.text('192.168.0.41 : 1024'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    final password = tester.widget<TextField>(
      find.byKey(const ValueKey('projector-password')),
    );
    expect(password.obscureText, isTrue);
  });

  testWidgets('IP check states', (tester) async {
    await _open(tester, _projector());
    final ip = find.byKey(const ValueKey('edit-ip'));
    expect(find.text('Current address'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(ip, '192.168.0.43');
    await tester.pump();
    expect(
      find.text('Changed from 192.168.0.41, not used by another projector'),
      findsOneWidget,
    );
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(ip, '192.168.0.42');
    await tester.pump();
    expect(find.text('Already used by another projector'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(ip, '192.168.0');
    await tester.pump();
    expect(find.text('Not a valid IP address'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('the port is saved', (tester) async {
    final saved = await _open(tester, _projector());
    await tester.enterText(find.byKey(const ValueKey('port')), '2048');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(saved.single, ('192.168.0.41', 2048, 'admin1', 'panasonic'));
  });

  testWidgets('an unauthorized node opens in the Wrong login state', (
    tester,
  ) async {
    await _open(tester, _projector(status: ConnectionStatus.unauthorized));
    expect(find.text('Wrong login'), findsOneWidget);
    expect(
      find.text(
        'The projector rejected this login. Check the login and password.',
      ),
      findsOneWidget,
    );
    final login = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('projector-login')),
        matching: find.byType(EditableText),
      ),
    );
    expect(login.focusNode.hasFocus, isTrue);
  });

  testWidgets('lays out without overflow in an 800x600 window', (tester) async {
    await _open(
      tester,
      _projector(status: ConnectionStatus.unauthorized),
      window: const Size(800, 600),
    );
    expect(tester.takeException(), isNull);
  });
}
