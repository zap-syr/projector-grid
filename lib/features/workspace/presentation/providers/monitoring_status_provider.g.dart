// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitoring_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every projector's [MonitoringStatus] by node id. Rows, cards and group
/// rows `select` their own entry or summary out of it, and the statuses
/// compare by value, so a poll that changes nothing they show rebuilds
/// none of them.

@ProviderFor(monitoringStatus)
final monitoringStatusProvider = MonitoringStatusProvider._();

/// Every projector's [MonitoringStatus] by node id. Rows, cards and group
/// rows `select` their own entry or summary out of it, and the statuses
/// compare by value, so a poll that changes nothing they show rebuilds
/// none of them.

final class MonitoringStatusProvider
    extends
        $FunctionalProvider<
          Map<String, MonitoringStatus>,
          Map<String, MonitoringStatus>,
          Map<String, MonitoringStatus>
        >
    with $Provider<Map<String, MonitoringStatus>> {
  /// Every projector's [MonitoringStatus] by node id. Rows, cards and group
  /// rows `select` their own entry or summary out of it, and the statuses
  /// compare by value, so a poll that changes nothing they show rebuilds
  /// none of them.
  MonitoringStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringStatusHash();

  @$internal
  @override
  $ProviderElement<Map<String, MonitoringStatus>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, MonitoringStatus> create(Ref ref) {
    return monitoringStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, MonitoringStatus> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, MonitoringStatus>>(
        value,
      ),
    );
  }
}

String _$monitoringStatusHash() => r'84ba0ce75a32501e63c16ecb178be1ae5cecd52d';
