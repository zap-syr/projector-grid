import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/app_config_dir.dart';

part 'app_settings_provider.g.dart';

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
}
