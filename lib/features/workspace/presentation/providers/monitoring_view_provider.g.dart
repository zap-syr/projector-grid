// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitoring_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Monitoring view's layout ([MonitoringViewSettings]), saved to
/// `monitoring_view.json` on every change.

@ProviderFor(MonitoringViewNotifier)
final monitoringViewProvider = MonitoringViewNotifierProvider._();

/// The Monitoring view's layout ([MonitoringViewSettings]), saved to
/// `monitoring_view.json` on every change.
final class MonitoringViewNotifierProvider
    extends $NotifierProvider<MonitoringViewNotifier, MonitoringViewSettings> {
  /// The Monitoring view's layout ([MonitoringViewSettings]), saved to
  /// `monitoring_view.json` on every change.
  MonitoringViewNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringViewNotifierHash();

  @$internal
  @override
  MonitoringViewNotifier create() => MonitoringViewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitoringViewSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitoringViewSettings>(value),
    );
  }
}

String _$monitoringViewNotifierHash() =>
    r'ff747cf64a88f20b6fd1f61f644420cbae8bcaf5';

/// The Monitoring view's layout ([MonitoringViewSettings]), saved to
/// `monitoring_view.json` on every change.

abstract class _$MonitoringViewNotifier
    extends $Notifier<MonitoringViewSettings> {
  MonitoringViewSettings build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<MonitoringViewSettings, MonitoringViewSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitoringViewSettings, MonitoringViewSettings>,
              MonitoringViewSettings,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
