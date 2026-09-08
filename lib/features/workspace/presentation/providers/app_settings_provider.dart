import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_config_dir.dart';

part 'app_settings_provider.g.dart';

/// Monitoring-table row density preset — drives row height, cell padding and
/// body font size together. See `MonitoringTable`.
enum MonitoringDensity { compact, standard, comfortable }

extension MonitoringDensityLabel on MonitoringDensity {
  String get label => switch (this) {
    MonitoringDensity.compact => 'Compact',
    MonitoringDensity.standard => 'Standard',
    MonitoringDensity.comfortable => 'Comfortable',
  };
}

class AppSettings {
  /// Bounds for the projector telemetry poll interval. The floor keeps a
  /// mistyped value (e.g. 1s) from hammering every projector on the network
  /// and taking the app down with it.
  static const int minPollingIntervalSeconds = 30;
  static const int maxPollingIntervalSeconds = 3600;
  static const int defaultPollingIntervalSeconds = 60;

  final int pollingIntervalSeconds;
  final ThemeMode themeMode;
  final bool oscActive;
  final String oscNetworkDevice;
  final int oscReceivePort;
  final String oscSendIp;
  final int oscSendPort;
  final bool showLogs;
  final bool isMonitoringView;

  /// Monitoring-table layout. `monitoringColumns` is the ordered list of
  /// *visible* column ids (see `MonitoringTable` for the id set); an empty list
  /// means "use the table's default set/order". `monitoringColumnWidths` holds
  /// per-column pixel widths the user set via header auto-fit / drag; ids not
  /// present fall back to the descriptor default. `monitoringFitToWidth`
  /// toggles proportional scale-to-viewport vs. honoring pixel widths.
  final List<String> monitoringColumns;
  final Map<String, double> monitoringColumnWidths;
  final String monitoringSortColumnId;
  final bool monitoringSortAscending;
  final bool monitoringFitToWidth;

  /// Row density preset, and whether rows are clustered under non-collapsing
  /// group headers (the standalone Group column is hidden while this is on).
  final MonitoringDensity monitoringDensity;
  final bool monitoringGroupBy;

  const AppSettings({
    this.pollingIntervalSeconds = defaultPollingIntervalSeconds,
    this.themeMode = ThemeMode.dark,
    this.oscActive = false,
    this.oscNetworkDevice = '',
    this.oscReceivePort = 8000,
    this.oscSendIp = '127.0.0.1',
    this.oscSendPort = 9000,
    this.showLogs = false,
    this.isMonitoringView = false,
    this.monitoringColumns = const [],
    this.monitoringColumnWidths = const {},
    this.monitoringSortColumnId = 'ip',
    this.monitoringSortAscending = true,
    this.monitoringFitToWidth = true,
    this.monitoringDensity = MonitoringDensity.standard,
    this.monitoringGroupBy = false,
  });

  AppSettings copyWith({
    int? pollingIntervalSeconds,
    ThemeMode? themeMode,
    bool? oscActive,
    String? oscNetworkDevice,
    int? oscReceivePort,
    String? oscSendIp,
    int? oscSendPort,
    bool? showLogs,
    bool? isMonitoringView,
    List<String>? monitoringColumns,
    Map<String, double>? monitoringColumnWidths,
    String? monitoringSortColumnId,
    bool? monitoringSortAscending,
    bool? monitoringFitToWidth,
    MonitoringDensity? monitoringDensity,
    bool? monitoringGroupBy,
  }) {
    return AppSettings(
      pollingIntervalSeconds:
          pollingIntervalSeconds ?? this.pollingIntervalSeconds,
      themeMode: themeMode ?? this.themeMode,
      oscActive: oscActive ?? this.oscActive,
      oscNetworkDevice: oscNetworkDevice ?? this.oscNetworkDevice,
      oscReceivePort: oscReceivePort ?? this.oscReceivePort,
      oscSendIp: oscSendIp ?? this.oscSendIp,
      oscSendPort: oscSendPort ?? this.oscSendPort,
      showLogs: showLogs ?? this.showLogs,
      isMonitoringView: isMonitoringView ?? this.isMonitoringView,
      monitoringColumns: monitoringColumns ?? this.monitoringColumns,
      monitoringColumnWidths:
          monitoringColumnWidths ?? this.monitoringColumnWidths,
      monitoringSortColumnId:
          monitoringSortColumnId ?? this.monitoringSortColumnId,
      monitoringSortAscending:
          monitoringSortAscending ?? this.monitoringSortAscending,
      monitoringFitToWidth: monitoringFitToWidth ?? this.monitoringFitToWidth,
      monitoringDensity: monitoringDensity ?? this.monitoringDensity,
      monitoringGroupBy: monitoringGroupBy ?? this.monitoringGroupBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'pollingIntervalSeconds': pollingIntervalSeconds,
    'themeMode': themeMode.name,
    'oscActive': oscActive,
    'oscNetworkDevice': oscNetworkDevice,
    'oscReceivePort': oscReceivePort,
    'oscSendIp': oscSendIp,
    'oscSendPort': oscSendPort,
    'showLogs': showLogs,
    'isMonitoringView': isMonitoringView,
    'monitoringColumns': monitoringColumns,
    'monitoringColumnWidths': monitoringColumnWidths,
    'monitoringSortColumnId': monitoringSortColumnId,
    'monitoringSortAscending': monitoringSortAscending,
    'monitoringFitToWidth': monitoringFitToWidth,
    'monitoringDensity': monitoringDensity.name,
    'monitoringGroupBy': monitoringGroupBy,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    pollingIntervalSeconds:
        ((json['pollingIntervalSeconds'] as int?) ??
                defaultPollingIntervalSeconds)
            .clamp(minPollingIntervalSeconds, maxPollingIntervalSeconds),
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == json['themeMode'],
      orElse: () => ThemeMode.dark,
    ),
    oscActive: (json['oscActive'] as bool?) ?? false,
    oscNetworkDevice: (json['oscNetworkDevice'] as String?) ?? '',
    oscReceivePort: (json['oscReceivePort'] as int?) ?? 8000,
    oscSendIp: (json['oscSendIp'] as String?) ?? '127.0.0.1',
    oscSendPort: (json['oscSendPort'] as int?) ?? 9000,
    showLogs: (json['showLogs'] as bool?) ?? false,
    isMonitoringView: (json['isMonitoringView'] as bool?) ?? false,
    monitoringColumns:
        (json['monitoringColumns'] as List?)?.cast<String>() ?? const [],
    monitoringColumnWidths:
        (json['monitoringColumnWidths'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ) ??
        const {},
    monitoringSortColumnId: (json['monitoringSortColumnId'] as String?) ?? 'ip',
    monitoringSortAscending: (json['monitoringSortAscending'] as bool?) ?? true,
    monitoringFitToWidth: (json['monitoringFitToWidth'] as bool?) ?? true,
    monitoringDensity: MonitoringDensity.values.firstWhere(
      (d) => d.name == json['monitoringDensity'],
      orElse: () => MonitoringDensity.standard,
    ),
    monitoringGroupBy: (json['monitoringGroupBy'] as bool?) ?? false,
  );
}

@riverpod
class AppSettingsNotifier extends _$AppSettingsNotifier {
  static String get _filePath => appConfigFilePath('app_settings.json');

  @override
  AppSettings build() => _load();

  AppSettings _load() {
    try {
      final file = File(_filePath);
      if (!file.existsSync()) return const AppSettings();
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  void _save(AppSettings settings) {
    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  void setPollingInterval(int seconds) {
    final clamped = seconds.clamp(
      AppSettings.minPollingIntervalSeconds,
      AppSettings.maxPollingIntervalSeconds,
    );
    state = state.copyWith(pollingIntervalSeconds: clamped);
    _save(state);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save(state);
  }

  void setOscActive(bool active) {
    state = state.copyWith(oscActive: active);
    _save(state);
  }

  void setOscNetworkDevice(String device) {
    state = state.copyWith(oscNetworkDevice: device);
    _save(state);
  }

  void setOscReceivePort(int port) {
    state = state.copyWith(oscReceivePort: port);
    _save(state);
  }

  void setOscSendIp(String ip) {
    state = state.copyWith(oscSendIp: ip);
    _save(state);
  }

  void setOscSendPort(int port) {
    state = state.copyWith(oscSendPort: port);
    _save(state);
  }

  void setShowLogs(bool show) {
    state = state.copyWith(showLogs: show);
    _save(state);
  }

  void setMonitoringView(bool monitoring) {
    state = state.copyWith(isMonitoringView: monitoring);
    _save(state);
  }

  void setMonitoringColumns(List<String> columns) {
    state = state.copyWith(monitoringColumns: List.unmodifiable(columns));
    _save(state);
  }

  void setMonitoringColumnWidth(String id, double width) {
    final next = Map<String, double>.of(state.monitoringColumnWidths);
    next[id] = width;
    state = state.copyWith(monitoringColumnWidths: Map.unmodifiable(next));
    _save(state);
  }

  void setMonitoringSort(String columnId, bool ascending) {
    state = state.copyWith(
      monitoringSortColumnId: columnId,
      monitoringSortAscending: ascending,
    );
    _save(state);
  }

  void setMonitoringFitToWidth(bool fit) {
    state = state.copyWith(monitoringFitToWidth: fit);
    _save(state);
  }

  void setMonitoringDensity(MonitoringDensity density) {
    state = state.copyWith(monitoringDensity: density);
    _save(state);
  }

  void setMonitoringGroupBy(bool groupBy) {
    state = state.copyWith(monitoringGroupBy: groupBy);
    _save(state);
  }
}
