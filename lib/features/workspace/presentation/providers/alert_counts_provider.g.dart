// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_counts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Alert counts for the status bar (and the OSC status counts). A record, so
/// Riverpod dedupes it and acknowledging one of many doesn't rebuild what
/// only shows totals that stayed the same.

@ProviderFor(alertCounts)
final alertCountsProvider = AlertCountsProvider._();

/// Alert counts for the status bar (and the OSC status counts). A record, so
/// Riverpod dedupes it and acknowledging one of many doesn't rebuild what
/// only shows totals that stayed the same.

final class AlertCountsProvider
    extends $FunctionalProvider<AlertCounts, AlertCounts, AlertCounts>
    with $Provider<AlertCounts> {
  /// Alert counts for the status bar (and the OSC status counts). A record, so
  /// Riverpod dedupes it and acknowledging one of many doesn't rebuild what
  /// only shows totals that stayed the same.
  AlertCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alertCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alertCountsHash();

  @$internal
  @override
  $ProviderElement<AlertCounts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AlertCounts create(Ref ref) {
    return alertCounts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlertCounts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlertCounts>(value),
    );
  }
}

String _$alertCountsHash() => r'2d276dc06ae49db1cd382703b841d20d11ba349a';
