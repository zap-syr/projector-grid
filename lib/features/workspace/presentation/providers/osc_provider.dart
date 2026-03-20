import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/osc_service.dart';
import '../../domain/projector_node.dart';
import 'app_settings_provider.dart';
import 'workspace_provider.dart';

part 'osc_provider.g.dart';

@Riverpod(keepAlive: true)
class OscNotifier extends _$OscNotifier {
  final OscService _service = OscService();

  @override
  bool build() {
    ref.onDispose(() {
      _service.stop();
    });
    return false; // not active initially
  }

  void _wireCallbacks() {
    _service.onCommand = ({
      required String ntcontrolCmd,
      String? groupId,
      bool all = false,
    }) async {
      final wsNotifier = ref.read(workspaceProvider.notifier);
      if (all) {
        await wsNotifier.sendCommandToAll(ntcontrolCmd);
      } else if (groupId != null) {
        await wsNotifier.sendCommandToGroup(groupId, ntcontrolCmd);
      }
    };

    _service.getStatus = () {
      final nodes = ref.read(workspaceProvider);
      final online = nodes.where((n) => n.connectionStatus == ConnectionStatus.connected).length;
      final offline = nodes.where((n) => n.connectionStatus == ConnectionStatus.offline).length;
      final warnings = nodes.where((n) =>
        n.errors != 'NO ERRORS' && n.errors != '-' ||
        n.connectionStatus == ConnectionStatus.unauthorized
      ).length;
      return (online: online, offline: offline, warnings: warnings);
    };

    _service.resolveGroupId = (String oscAddress) {
      final groups = ref.read(workspaceProvider.notifier).groups;
      for (final g in groups) {
        if (g.oscAddress == oscAddress) return g.id;
      }
      return null;
    };
  }

  Future<void> start() async {
    final settings = ref.read(appSettingsProvider);
    _wireCallbacks();
    await _service.start(
      networkDevice: settings.oscNetworkDevice,
      receivePort: settings.oscReceivePort,
      sendIp: settings.oscSendIp,
      sendPort: settings.oscSendPort,
    );
    state = _service.isActive;
    ref.read(appSettingsProvider.notifier).setOscActive(true);

    // Push status on every state change
    ref.read(workspaceProvider.notifier).onStateChanged = () {
      _service.sendStatusIfActive();
    };
  }

  Future<void> stop() async {
    await _service.stop();
    state = false;
    ref.read(appSettingsProvider.notifier).setOscActive(false);
    ref.read(workspaceProvider.notifier).onStateChanged = null;
  }

  Future<void> toggle() async {
    if (state) {
      await stop();
    } else {
      await start();
    }
  }

  /// Call after polling to broadcast status.
  void sendStatusIfActive() {
    _service.sendStatusIfActive();
  }
}
