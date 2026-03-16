import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_provider.g.dart';

class AppSettings {
  final int pollingIntervalSeconds;
  final ThemeMode themeMode;

  const AppSettings({
    this.pollingIntervalSeconds = 60,
    this.themeMode = ThemeMode.dark,
  });

  AppSettings copyWith({int? pollingIntervalSeconds, ThemeMode? themeMode}) {
    return AppSettings(
      pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
      themeMode: themeMode ?? this.themeMode,
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
}
