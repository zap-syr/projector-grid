import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_log_file.dart';
import '../../../../core/services/atomic_file.dart';
import '../../../../core/services/native_file_dialog.dart';
import '../../../../core/services/panasonic_protocol_service.dart';
import '../../../../core/services/warp_diagnostics.dart';
import '../../../../core/services/warp_transfer.dart';
import '../../domain/log_event.dart';
import '../../domain/projector_node.dart';
import '../../domain/warp_diagnostics_report.dart';
import 'event_log_provider.dart';
import 'protocol_service_provider.dart';
import 'workspace_provider.dart';

part 'warp_diagnostics_provider.g.dart';

/// How long the survey waits for the regular poll to let go of the projector,
/// as the edit session does.
const Duration _claimTimeout = Duration(seconds: 3);
const Duration _claimStep = Duration(milliseconds: 100);

const String _busyMessage = 'Projector busy, try again';

/// Where a diagnostics export is.
sealed class WarpDiagnosticsState {
  const WarpDiagnosticsState();
}

/// Nothing has been asked for, or the save dialog was cancelled.
class WarpDiagnosticsIdle extends WarpDiagnosticsState {
  const WarpDiagnosticsIdle();
}

/// The projector is being read, the report built and the file chosen.
class WarpDiagnosticsReading extends WarpDiagnosticsState {
  const WarpDiagnosticsReading();
}

/// The file was written to [path].
class WarpDiagnosticsSaved extends WarpDiagnosticsState {
  const WarpDiagnosticsSaved(this.path);

  final String path;

  /// The last part of [path], for a message.
  String get fileName => path.split(RegExp(r'[\\/]')).last;
}

/// The export failed; [message] is the reason, without a lead-in.
class WarpDiagnosticsFailed extends WarpDiagnosticsState {
  const WarpDiagnosticsFailed(this.message);

  final String message;
}

/// The save dialog, as a provider so tests never open a real one.
@Riverpod(keepAlive: true)
NativeSaveDialog warpDiagnosticsSaveDialog(Ref ref) => showNativeSaveDialog;

/// The app version for the report header, as the app log writes it
/// (`2.0.1+13`). A provider so tests need no platform channel.
@Riverpod(keepAlive: true)
Future<String> warpDiagnosticsAppVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
}

/// A read-only survey of one projector's free grid memories, saved as a text
/// file for a model whose table format the app does not understand. Manual:
/// nothing runs until [save] is called. Not `keepAlive`: it lives while the
/// notice that starts it is on screen.
///
/// Like every transfer it claims the projector from the regular poll first
/// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
/// connections at once, and gives the claim back before the save dialog opens.
@riverpod
class WarpDiagnostics extends _$WarpDiagnostics {
  late PanasonicProtocolService _service;
  late WorkspaceNotifier _workspace;
  late EventLogNotifier _eventLog;

  @override
  WarpDiagnosticsState build(String nodeId) {
    _service = ref.read(protocolServiceProvider);
    _workspace = ref.read(workspaceProvider.notifier);
    _eventLog = ref.read(eventLogProvider.notifier);
    return const WarpDiagnosticsIdle();
  }

  ProjectorNode get _node =>
      ref.read(workspaceProvider).firstWhere((n) => n.id == nodeId);

  /// Waits up to [_claimTimeout] for the projector. False when it stays busy,
  /// and when this provider ended meanwhile (the claim is given back then).
  Future<bool> _claim() async {
    var claimed = _workspace.claimNodeForExternalPoll(nodeId);
    // Counts its own waits rather than reading the clock, so a test with a
    // fake clock can run it.
    for (var waited = Duration.zero; !claimed && waited < _claimTimeout;) {
      await Future<void>.delayed(_claimStep);
      waited += _claimStep;
      claimed = _workspace.claimNodeForExternalPoll(nodeId);
    }
    if (claimed && !ref.mounted) {
      _release();
      return false;
    }
    return claimed;
  }

  void _release() => _workspace.releaseNodeFromExternalPoll(nodeId);

  void _log(ProjectorNode node, LogSeverity severity, String message) {
    _eventLog.log(
      LogEvent(
        severity: severity,
        type: LogEventType.command,
        message: message,
        projectorIp: node.ipAddress,
        projectorName: node.name,
        nodeId: node.id,
      ),
    );
  }

  void _fail(ProjectorNode node, String reason) {
    _log(node, LogSeverity.error, 'Free grid diagnostics failed: $reason');
    if (ref.mounted) state = WarpDiagnosticsFailed(reason);
  }

  /// Reads the projector, then asks where to save the report and writes it.
  /// Ends in [WarpDiagnosticsSaved], in [WarpDiagnosticsFailed] (the reason is
  /// in the state and the event log), or back in [WarpDiagnosticsIdle] when
  /// the save dialog is cancelled: nothing is written then. Does nothing
  /// while a save is running.
  Future<void> save() async {
    if (state is WarpDiagnosticsReading) return;
    state = const WarpDiagnosticsReading();
    final node = _node;
    try {
      final version = await ref.read(warpDiagnosticsAppVersionProvider.future);
      if (!ref.mounted) return;

      if (!await _claim()) {
        if (ref.mounted) _fail(node, _busyMessage);
        return;
      }
      final WarpDiagnosticsResult result;
      try {
        result = await runWarpDiagnostics(
          ProtocolWarpLink(
            _service,
            ip: node.ipAddress,
            port: node.port,
            login: node.login,
            password: node.password,
          ),
        );
      } finally {
        _release();
      }
      if (!ref.mounted) return;

      final now = DateTime.now();
      final report = buildWarpDiagnosticsReport(
        result: result,
        projectorName: node.name,
        ip: node.ipAddress,
        port: node.port,
        serialNumber: node.serialNumber,
        appVersion: version,
        createdAt: now,
      );

      final folder = logsFolderPath;
      await Directory(folder).create(recursive: true);
      if (!ref.mounted) return;
      final chosen = await ref.read(warpDiagnosticsSaveDialogProvider)(
        title: 'Save diagnostics',
        defaultName: warpDiagnosticsFileName(
          model: node.name,
          ip: node.ipAddress,
          at: now,
        ),
        filterLabel: 'Text file',
        extension: 'txt',
        initialDirectory: folder,
      );
      if (!ref.mounted) return;
      if (chosen == null) {
        state = const WarpDiagnosticsIdle();
        return;
      }

      final path = chosen.toLowerCase().endsWith('.txt')
          ? chosen
          : '$chosen.txt';
      await writeFileAtomic(path, report);
      final saved = WarpDiagnosticsSaved(path);
      _log(
        node,
        LogSeverity.success,
        'Free grid diagnostics saved to ${saved.fileName}',
      );
      if (ref.mounted) state = saved;
    } catch (e) {
      _fail(node, '$e');
    }
  }
}
