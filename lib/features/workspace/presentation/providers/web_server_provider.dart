import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';

import '../../../../core/services/web_api.dart';
import '../../../../core/services/web_auth.dart';
import '../../../../core/services/web_event_hub.dart';
import '../../../../core/services/web_server_service.dart';
import '../../../../core/services/web_static_handler.dart';
import '../../domain/log_event.dart';
import '../../domain/web_actions.dart';
import '../../domain/web_api_dto.dart';
import 'app_settings_provider.dart';
import 'event_log_provider.dart';
import 'project_provider.dart';
import 'workspace_provider.dart';

part 'web_server_provider.g.dart';

/// Web Access server lifecycle; state = whether it's listening. Also the
/// [WebApiSource] the routes read from, so the API reports exactly what the
/// app's providers hold.
@Riverpod(keepAlive: true)
class WebServerNotifier extends _$WebServerNotifier implements WebApiSource {
  final WebServerService _service = WebServerService();
  late final WebAuth _auth = WebAuth(
    onLockout: (ip, lockout) => _log(
      LogSeverity.warning,
      'Web · $ip locked out for ${lockout.inSeconds} s after wrong PINs',
    ),
  );
  late final WebEventHub _hub = WebEventHub(
    onHeartbeat: (token) => _auth.touch(token) != null,
  );

  /// What the connected pages were last sent, to push only the changes.
  List<Json> _sentProjectors = const [];
  List<Json> _sentGroups = const [];

  @override
  bool build() {
    ref.onDispose(() {
      _hub.closeAll();
      _service.stop();
    });
    ref.listen(workspaceProvider, (_, nodes) => _pushWorkspace());
    ref.listen(
      projectStateProvider.select((s) => s.currentFilePath),
      (_, path) => _hub.broadcast((
        name: WebEvents.project,
        data: {'name': webProjectName(path)},
      )),
    );
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
    final api = WebApi(auth: _auth, hub: _hub, source: this).handler;
    final static = webStaticHandler(rootBundle, assets);
    final ok = await _service.start(
      port: port,
      handler: (Request r) =>
          r.url.path.startsWith('api/') ? api(r) : static(r),
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
    _endAllSessions();
    await _service.stop();
    state = false;
    ref.read(appSettingsProvider.notifier).setWebEnabled(false);
    if (wasActive) _log(LogSeverity.info, 'Web access off');
  }

  Future<void> restart() async {
    _endAllSessions();
    await _service.stop();
    await start();
  }

  /// Stores [pin] (hashed) as the Viewer PIN; every session ends, since
  /// changing a PIN is how an operator locks people out.
  void setViewerPin(String pin) {
    ref.read(appSettingsProvider.notifier).setWebViewerPinHash(hashPin(pin));
    signOutAll();
  }

  /// Stores [pin] (hashed) as the Operator PIN; every session ends, as for
  /// the Viewer PIN.
  void setOperatorPin(String pin) {
    ref.read(appSettingsProvider.notifier).setWebOperatorPinHash(hashPin(pin));
    signOutAll();
  }

  /// *Allow control*. Turning it off drops every operator to viewer; either
  /// way each open page learns whether *Unlock control* is available.
  void setAllowControl(bool allow) {
    ref.read(appSettingsProvider.notifier).setWebAllowControl(allow);
    if (!allow) _auth.demoteOperators();
    for (final s in _auth.sessions) {
      _hub.sendTo(s.token, (
        name: accessEvent,
        data: accessJson(s.role, controlAllowed: allow),
      ));
    }
    _log(LogSeverity.info, 'Web · control ${allow ? 'allowed' : 'off'}');
  }

  void signOutAll() {
    final hadClients = _auth.sessions.isNotEmpty;
    _endAllSessions();
    if (hadClients) _log(LogSeverity.info, 'Web · all clients signed out');
  }

  void _endAllSessions() {
    _auth.revokeAll();
    _hub.closeAll(
      last: (name: WebEvents.signedOut, data: const <String, Object?>{}),
    );
  }

  void _pushWorkspace() {
    // With no page connected there's nobody to diff for; the next page gets
    // a full snapshot on connect.
    if (_hub.clientCount == 0) return;
    final projectors = this.projectors();
    projectorEvents(_sentProjectors, projectors).forEach(_hub.broadcast);
    _sentProjectors = projectors;
    final groups = this.groups();
    if (!sameGroupsJson(_sentGroups, groups)) {
      _hub.broadcast((name: WebEvents.groups, data: groups));
      _sentGroups = groups;
    }
  }

  // ── WebApiSource ─────────────────────────────────────────────────────────

  @override
  String get projectName =>
      webProjectName(ref.read(projectStateProvider).currentFilePath);

  @override
  String get viewerPinHash => ref.read(appSettingsProvider).webViewerPinHash!;

  @override
  String? get operatorPinHash {
    final s = ref.read(appSettingsProvider);
    return s.webAllowControl ? s.webOperatorPinHash : null;
  }

  @override
  Json config(WebRole role) {
    final s = ref.read(appSettingsProvider);
    return configJson(
      projectName: projectName,
      role: role,
      layout: (
        columns: s.monitoringColumns,
        widths: s.monitoringColumnWidths,
        sortColumn: s.monitoringSortColumnId,
        sortAscending: s.monitoringSortAscending,
        density: s.monitoringDensity.name,
        fitToWidth: s.monitoringFitToWidth,
        groupBy: s.monitoringGroupBy,
      ),
    );
  }

  @override
  List<Json> projectors() => projectorsJson(ref.read(workspaceProvider));

  @override
  List<Json> groups() =>
      groupsJson(ref.read(workspaceProvider.notifier).groups);

  @override
  List<WebEvent> snapshotEvents() {
    _sentProjectors = projectors();
    _sentGroups = groups();
    return [
      (
        name: WebEvents.snapshot,
        data: snapshotJson(
          projectName: projectName,
          projectors: _sentProjectors,
          groups: _sentGroups,
        ),
      ),
    ];
  }

  @override
  void signedIn(WebSession session) => _log(
    LogSeverity.info,
    'Web · ${session.ip} · ${session.role.name} signed in',
  );

  /// Projectors with a lens step from the web still in flight.
  final Set<String> _lensBusy = {};

  @override
  Future<Json?> dispatch(Object? body, WebSession session) async {
    final request = parseWebActionRequest(body);
    if (request == null) return null;
    final nodes = ref.read(workspaceProvider);
    var ids = switch (request.targets) {
      WebTargetIds(:final ids) => ids,
      WebTargetGroup(:final groupId) => [
        for (final n in nodes)
          if (n.groupId == groupId) n.id,
      ],
      WebTargetAll() => [for (final n in nodes) n.id],
    };
    // Same rule as the control bar's _throttledSend (drop a step while the
    // last one is still going), but per projector, so a laggy phone
    // repeating a held button can't queue up a burst.
    final lens = request.action.isLensStep;
    if (lens) {
      ids = ids.where((id) => !_lensBusy.contains(id)).toList();
      _lensBusy.addAll(ids);
    }
    try {
      final result = await ref
          .read(workspaceProvider.notifier)
          .sendCommandToNodes(
            ids,
            request.action.command,
            source: 'Web · ${session.ip} · ${session.role.name}',
          );
      return dispatchResultJson(result);
    } finally {
      if (lens) _lensBusy.removeAll(ids);
    }
  }

  @override
  void roleChanged(WebSession session) => _log(
    LogSeverity.info,
    'Web · ${session.ip} · '
    '${session.role == WebRole.operator ? 'control unlocked' : 'locked'}',
  );

  void _log(LogSeverity severity, String message) => ref
      .read(eventLogProvider.notifier)
      .log(
        LogEvent(severity: severity, type: LogEventType.web, message: message),
      );
}
