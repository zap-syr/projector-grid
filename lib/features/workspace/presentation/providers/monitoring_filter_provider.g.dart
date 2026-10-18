// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitoring_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Monitoring bar's search and quick filter ([MonitoringFilter]); kept
/// for the session, not saved.

@ProviderFor(MonitoringFilterNotifier)
final monitoringFilterProvider = MonitoringFilterNotifierProvider._();

/// The Monitoring bar's search and quick filter ([MonitoringFilter]); kept
/// for the session, not saved.
final class MonitoringFilterNotifierProvider
    extends $NotifierProvider<MonitoringFilterNotifier, MonitoringFilter> {
  /// The Monitoring bar's search and quick filter ([MonitoringFilter]); kept
  /// for the session, not saved.
  MonitoringFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringFilterNotifierHash();

  @$internal
  @override
  MonitoringFilterNotifier create() => MonitoringFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitoringFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitoringFilter>(value),
    );
  }
}

String _$monitoringFilterNotifierHash() =>
    r'710dd15f4359c346c07fe050c99b498549df8f9e';

/// The Monitoring bar's search and quick filter ([MonitoringFilter]); kept
/// for the session, not saved.

abstract class _$MonitoringFilterNotifier extends $Notifier<MonitoringFilter> {
  MonitoringFilter build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MonitoringFilter, MonitoringFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitoringFilter, MonitoringFilter>,
              MonitoringFilter,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Ctrl+F's request to focus the Monitoring search field. A counter, so a
/// second request while the first is pending still notifies.

@ProviderFor(MonitoringSearchFocusNotifier)
final monitoringSearchFocusProvider = MonitoringSearchFocusNotifierProvider._();

/// Ctrl+F's request to focus the Monitoring search field. A counter, so a
/// second request while the first is pending still notifies.
final class MonitoringSearchFocusNotifierProvider
    extends $NotifierProvider<MonitoringSearchFocusNotifier, int> {
  /// Ctrl+F's request to focus the Monitoring search field. A counter, so a
  /// second request while the first is pending still notifies.
  MonitoringSearchFocusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringSearchFocusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringSearchFocusNotifierHash();

  @$internal
  @override
  MonitoringSearchFocusNotifier create() => MonitoringSearchFocusNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$monitoringSearchFocusNotifierHash() =>
    r'c2bcefabe45f8db20bbf8a6a30db3454e79eba0b';

/// Ctrl+F's request to focus the Monitoring search field. A counter, so a
/// second request while the first is pending still notifies.

abstract class _$MonitoringSearchFocusNotifier extends $Notifier<int> {
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
