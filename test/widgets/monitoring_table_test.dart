import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/app_settings_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/remote_preview_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/remote_preview_dialog.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

/// Never opens the projector's WebSocket.
class _IdlePreview extends RemotePreview {
  @override
  RemotePreviewState build(String host) => const RemotePreviewConnecting();
}

void main() {
  useTempConfigDir();

  Future<void> showMonitoring(WidgetTester tester) async {
    await pumpApp(
      tester,
      FakeProtocolService(),
      overrides: [remotePreviewProvider.overrideWith2((_) => _IdlePreview())],
    );
    final c = appContainer(tester);
    c.read(workspaceProvider.notifier).setNodes([
      node('7', status: ConnectionStatus.offline),
    ]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Preview is shown by default, right after Serial Number', (
    tester,
  ) async {
    await showMonitoring(tester);
    final serial = tester.getTopLeft(find.text('Serial Number')).dx;
    final preview = tester.getTopLeft(find.text('Preview')).dx;
    final ip = tester.getTopLeft(find.text('IP Address')).dx;
    expect(serial < preview && preview < ip, isTrue);
  });

  testWidgets('a row\'s Preview button opens the dialog for that projector', (
    tester,
  ) async {
    await showMonitoring(tester);
    await tester.tap(find.byIcon(Icons.cast));
    await tester.pumpAndSettle();
    final dialog = tester.widget<RemotePreviewDialog>(
      find.byType(RemotePreviewDialog),
    );
    expect(dialog.nodes.map((n) => n.id), ['7']);
  });

  testWidgets('the Preview header does not sort', (tester) async {
    await showMonitoring(tester);
    final c = appContainer(tester);
    final before = c.read(appSettingsProvider).monitoringSortColumnId;
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).monitoringSortColumnId, before);
  });
}
