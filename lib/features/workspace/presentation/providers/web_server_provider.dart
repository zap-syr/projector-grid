import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/web_server_service.dart';
import '../../../../core/services/web_static_handler.dart';
import '../../domain/log_event.dart';
import 'app_settings_provider.dart';
import 'event_log_provider.dart';

part 'web_server_provider.g.dart';

/// Web Access server lifecycle; state = whether it's listening.
@Riverpod(keepAlive: true)
class WebServerNotifier extends _$WebServerNotifier {
  final WebServerService _service = WebServerService();

  @override
  bool build() {
    ref.onDispose(_service.stop);
    // Fire-and-forget like OscNotifier.build(): every state write in start()
    // happens after an await, so none lands inside this build.
    if (ref.read(appSettingsProvider).webEnabled) start();
    return false;
  }

  Future<void> start() async {
    final port = ref.read(appSettingsProvider).webPort;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((k) => k.startsWith('$webAssetRoot/'))
        .toSet();
    final ok = await _service.start(
      port: port,
      handler: webStaticHandler(rootBundle, assets),
    );
    state = ok;
    // Persist the outcome, not the request — same reasoning as OSC: a failed
    // bind must not leave the switch on and retry the same port every launch.
    ref.read(appSettingsProvider.notifier).setWebEnabled(ok);
    _log(
      ok ? LogSeverity.info : LogSeverity.error,
      ok
          ? 'Web access on — port $port'
          : 'Web access failed to start — could not bind port $port',
    );
  }

  Future<void> stop() async {
    final wasActive = _service.isActive;
    await _service.stop();
    state = false;
    ref.read(appSettingsProvider.notifier).setWebEnabled(false);
    if (wasActive) _log(LogSeverity.info, 'Web access off');
  }

  Future<void> restart() async {
    await _service.stop();
    await start();
  }

  void _log(LogSeverity severity, String message) => ref
      .read(eventLogProvider.notifier)
      .log(
        LogEvent(severity: severity, type: LogEventType.web, message: message),
      );
}
