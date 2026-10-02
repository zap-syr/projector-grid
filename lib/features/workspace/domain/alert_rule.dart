import '../../../core/theme/status_thresholds.dart';

enum AlertSeverity { warning, critical }

/// [slug] names the rule in OSC addresses (`/pgrid/alert/<slug>`) and in the
/// saved settings.
enum AlertRule {
  offline('offline', 'Offline'),
  error('error', 'Projector error'),
  signalLost('signal-lost', 'Signal lost'),
  intakeTemp('intake-temp', 'Intake temperature'),
  exhaustTemp('exhaust-temp', 'Exhaust temperature');

  const AlertRule(this.slug, this.label);

  final String slug;
  final String label;

  static AlertRule? fromSlug(String slug) =>
      values.where((r) => r.slug == slug).firstOrNull;
}

/// Which alerts a notification channel (desktop notification, sound) fires
/// for.
enum AlertNotifyScope { critical, all }

/// How the Active alerts panel groups its rows; remembered between sessions.
enum AlertGrouping { projector, alert }

/// The alert preferences. A machine preference, not per-project, so it lives
/// in app settings.
class AlertSettings {
  /// Rules added later (§4b) are absent from a saved [enabled] set and so
  /// start off, which is what they need: each adds a poll query.
  static const Set<AlertRule> defaultEnabled = {
    AlertRule.offline,
    AlertRule.error,
    AlertRule.signalLost,
    AlertRule.intakeTemp,
    AlertRule.exhaustTemp,
  };

  final Set<AlertRule> enabled;
  final TempThreshold intake;
  final TempThreshold exhaust;
  final bool desktopNotification;
  final AlertNotifyScope desktopNotifyFor;
  final bool sound;
  final AlertNotifyScope soundFor;
  final bool osc;
  final AlertGrouping grouping;

  const AlertSettings({
    this.enabled = defaultEnabled,
    this.intake = kDefaultIntakeTempThreshold,
    this.exhaust = kDefaultExhaustTempThreshold,
    this.desktopNotification = true,
    this.desktopNotifyFor = AlertNotifyScope.critical,
    this.sound = false,
    this.soundFor = AlertNotifyScope.critical,
    this.osc = true,
    this.grouping = AlertGrouping.projector,
  });

  bool isEnabled(AlertRule rule) => enabled.contains(rule);

  AlertSettings copyWith({
    Set<AlertRule>? enabled,
    TempThreshold? intake,
    TempThreshold? exhaust,
    bool? desktopNotification,
    AlertNotifyScope? desktopNotifyFor,
    bool? sound,
    AlertNotifyScope? soundFor,
    bool? osc,
    AlertGrouping? grouping,
  }) => AlertSettings(
    enabled: enabled ?? this.enabled,
    intake: intake ?? this.intake,
    exhaust: exhaust ?? this.exhaust,
    desktopNotification: desktopNotification ?? this.desktopNotification,
    desktopNotifyFor: desktopNotifyFor ?? this.desktopNotifyFor,
    sound: sound ?? this.sound,
    soundFor: soundFor ?? this.soundFor,
    osc: osc ?? this.osc,
    grouping: grouping ?? this.grouping,
  );

  Map<String, dynamic> toJson() => {
    'enabled': [for (final r in enabled) r.slug],
    'intake': _thresholdToJson(intake),
    'exhaust': _thresholdToJson(exhaust),
    'desktopNotification': desktopNotification,
    'desktopNotifyFor': desktopNotifyFor.name,
    'sound': sound,
    'soundFor': soundFor.name,
    'osc': osc,
    'grouping': grouping.name,
  };

  factory AlertSettings.fromJson(Map<String, dynamic> json) => AlertSettings(
    enabled: (json['enabled'] as List?) == null
        ? defaultEnabled
        : {
            for (final slug in (json['enabled'] as List).cast<String>())
              ?AlertRule.fromSlug(slug),
          },
    intake: _thresholdFromJson(json['intake'], kDefaultIntakeTempThreshold),
    exhaust: _thresholdFromJson(json['exhaust'], kDefaultExhaustTempThreshold),
    desktopNotification: (json['desktopNotification'] as bool?) ?? true,
    desktopNotifyFor: _scope(json['desktopNotifyFor']),
    sound: (json['sound'] as bool?) ?? false,
    soundFor: _scope(json['soundFor']),
    osc: (json['osc'] as bool?) ?? true,
    grouping: AlertGrouping.values.firstWhere(
      (g) => g.name == json['grouping'],
      orElse: () => AlertGrouping.projector,
    ),
  );

  static AlertNotifyScope _scope(Object? name) =>
      AlertNotifyScope.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AlertNotifyScope.critical,
      );

  static Map<String, double> _thresholdToJson(TempThreshold t) => {
    'warm': t.warm,
    'hot': t.hot,
  };

  static TempThreshold _thresholdFromJson(
    Object? json,
    TempThreshold fallback,
  ) {
    if (json is! Map) return fallback;
    return (
      warm: (json['warm'] as num?)?.toDouble() ?? fallback.warm,
      hot: (json['hot'] as num?)?.toDouble() ?? fallback.hot,
    );
  }
}
