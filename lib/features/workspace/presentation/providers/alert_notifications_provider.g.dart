// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Turns raised alerts into desktop notifications and the alert sound, per
/// Preferences → Alerts → Notify. Alerts raised within [kAlertBatchWindow]
/// of the first one make one notification and one sound.

@ProviderFor(AlertNotificationsNotifier)
final alertNotificationsProvider = AlertNotificationsNotifierProvider._();

/// Turns raised alerts into desktop notifications and the alert sound, per
/// Preferences → Alerts → Notify. Alerts raised within [kAlertBatchWindow]
/// of the first one make one notification and one sound.
final class AlertNotificationsNotifierProvider
    extends $NotifierProvider<AlertNotificationsNotifier, void> {
  /// Turns raised alerts into desktop notifications and the alert sound, per
  /// Preferences → Alerts → Notify. Alerts raised within [kAlertBatchWindow]
  /// of the first one make one notification and one sound.
  AlertNotificationsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alertNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alertNotificationsNotifierHash();

  @$internal
  @override
  AlertNotificationsNotifier create() => AlertNotificationsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$alertNotificationsNotifierHash() =>
    r'a1a9aacdfb443d6c68149bdc8996cb957fd66c22';

/// Turns raised alerts into desktop notifications and the alert sound, per
/// Preferences → Alerts → Notify. Alerts raised within [kAlertBatchWindow]
/// of the first one make one notification and one sound.

abstract class _$AlertNotificationsNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
