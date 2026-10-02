// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_alerts_request_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Asks the status bar to open Active alerts (a click on a desktop
/// notification). Counts up, so every request is a change the button sees.

@ProviderFor(ActiveAlertsRequestNotifier)
final activeAlertsRequestProvider = ActiveAlertsRequestNotifierProvider._();

/// Asks the status bar to open Active alerts (a click on a desktop
/// notification). Counts up, so every request is a change the button sees.
final class ActiveAlertsRequestNotifierProvider
    extends $NotifierProvider<ActiveAlertsRequestNotifier, int> {
  /// Asks the status bar to open Active alerts (a click on a desktop
  /// notification). Counts up, so every request is a change the button sees.
  ActiveAlertsRequestNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAlertsRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAlertsRequestNotifierHash();

  @$internal
  @override
  ActiveAlertsRequestNotifier create() => ActiveAlertsRequestNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$activeAlertsRequestNotifierHash() =>
    r'a924c3837814cbbc262c282de3888c4ba96a015c';

/// Asks the status bar to open Active alerts (a click on a desktop
/// notification). Counts up, so every request is a change the button sees.

abstract class _$ActiveAlertsRequestNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
