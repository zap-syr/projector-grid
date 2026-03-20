import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_provider.g.dart';

class AppSettings {
  final int pollingIntervalSeconds;
  final ThemeMode themeMode;
  final bool oscActive;
  final String oscNetworkDevice;
  final int oscReceivePort;
  final String oscSendIp;
  final int oscSendPort;

  const AppSettings({
    this.pollingIntervalSeconds = 60,
    this.themeMode = ThemeMode.dark,
    this.oscActive = false,
    this.oscNetworkDevice = '',
    this.oscReceivePort = 8000,
    this.oscSendIp = '127.0.0.1',
    this.oscSendPort = 9000,
  });

  AppSettings copyWith({
    int? pollingIntervalSeconds,
    ThemeMode? themeMode,
    bool? oscActive,
    String? oscNetworkDevice,
    int? oscReceivePort,
    String? oscSendIp,
    int? oscSendPort,
  }) {
    return AppSettings(
      pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
      themeMode: themeMode ?? this.themeMode,
      oscActive: oscActive ?? this.oscActive,
      oscNetworkDevice: oscNetworkDevice ?? this.oscNetworkDevice,
      oscReceivePort: oscReceivePort ?? this.oscReceivePort,
      oscSendIp: oscSendIp ?? this.oscSendIp,
      oscSendPort: oscSendPort ?? this.oscSendPort,
    );
  }
}

@riverpod
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  AppSettings build() => const AppSettings();

  void setPollingInterval(int seconds) {
    state = state.copyWith(pollingIntervalSeconds: seconds);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setOscActive(bool active) {
    state = state.copyWith(oscActive: active);
  }

  void setOscNetworkDevice(String device) {
    state = state.copyWith(oscNetworkDevice: device);
  }

  void setOscReceivePort(int port) {
    state = state.copyWith(oscReceivePort: port);
  }

  void setOscSendIp(String ip) {
    state = state.copyWith(oscSendIp: ip);
  }

  void setOscSendPort(int port) {
    state = state.copyWith(oscSendPort: port);
  }
}
