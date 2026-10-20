// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
/// structural equality, so this only triggers a `StatusBar` rebuild when one
/// of the counts actually changes — not on every single-node telemetry tick
/// that leaves them all the same. Alert counts are `alertCountsProvider`'s.
/// [wrongLogin] is only for the health meter's amber part.

@ProviderFor(statusSummary)
final statusSummaryProvider = StatusSummaryProvider._();

/// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
/// structural equality, so this only triggers a `StatusBar` rebuild when one
/// of the counts actually changes — not on every single-node telemetry tick
/// that leaves them all the same. Alert counts are `alertCountsProvider`'s.
/// [wrongLogin] is only for the health meter's amber part.

final class StatusSummaryProvider
    extends
        $FunctionalProvider<
          ({int offline, int online, int total, int wrongLogin}),
          ({int offline, int online, int total, int wrongLogin}),
          ({int offline, int online, int total, int wrongLogin})
        >
    with $Provider<({int offline, int online, int total, int wrongLogin})> {
  /// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
  /// structural equality, so this only triggers a `StatusBar` rebuild when one
  /// of the counts actually changes — not on every single-node telemetry tick
  /// that leaves them all the same. Alert counts are `alertCountsProvider`'s.
  /// [wrongLogin] is only for the health meter's amber part.
  StatusSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statusSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statusSummaryHash();

  @$internal
  @override
  $ProviderElement<({int offline, int online, int total, int wrongLogin})>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ({int offline, int online, int total, int wrongLogin}) create(Ref ref) {
    return statusSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({int offline, int online, int total, int wrongLogin}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({int offline, int online, int total, int wrongLogin})
          >(value),
    );
  }
}

String _$statusSummaryHash() => r'd09d84b1c53aa5632fc3dee0f45bcb0a5f968f98';
