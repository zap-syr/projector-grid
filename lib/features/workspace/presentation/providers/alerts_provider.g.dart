// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alerts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active alerts, rebuilt from every workspace change. In memory only:
/// after a restart, conditions that still hold come back as new.

@ProviderFor(AlertsNotifier)
final alertsProvider = AlertsNotifierProvider._();

/// The active alerts, rebuilt from every workspace change. In memory only:
/// after a restart, conditions that still hold come back as new.
final class AlertsNotifierProvider
    extends $NotifierProvider<AlertsNotifier, Map<AlertKey, ActiveAlert>> {
  /// The active alerts, rebuilt from every workspace change. In memory only:
  /// after a restart, conditions that still hold come back as new.
  AlertsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alertsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alertsNotifierHash();

  @$internal
  @override
  AlertsNotifier create() => AlertsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<AlertKey, ActiveAlert> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<AlertKey, ActiveAlert>>(value),
    );
  }
}

String _$alertsNotifierHash() => r'2f02f8260c81d9a6218e050ff83ce5eaf7989c08';

/// The active alerts, rebuilt from every workspace change. In memory only:
/// after a restart, conditions that still hold come back as new.

abstract class _$AlertsNotifier extends $Notifier<Map<AlertKey, ActiveAlert>> {
  Map<AlertKey, ActiveAlert> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<Map<AlertKey, ActiveAlert>, Map<AlertKey, ActiveAlert>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<AlertKey, ActiveAlert>,
                Map<AlertKey, ActiveAlert>
              >,
              Map<AlertKey, ActiveAlert>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
