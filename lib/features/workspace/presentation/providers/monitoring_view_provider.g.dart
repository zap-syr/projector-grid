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
    r'950d6edfa6d4fbcdee8fefd629f73dfefbf0eb29';

/// The Monitoring view's layout ([MonitoringViewSettings]), saved to
/// `monitoring_view.json` on every change.

abstract class _$MonitoringViewNotifier
    extends $Notifier<MonitoringViewSettings> {
  MonitoringViewSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}
