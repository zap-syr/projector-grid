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
/// that leaves them all the same.

@ProviderFor(statusSummary)
final statusSummaryProvider = StatusSummaryProvider._();

/// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
/// structural equality, so this only triggers a `StatusBar` rebuild when one
/// of the counts actually changes — not on every single-node telemetry tick
/// that leaves them all the same.

final class StatusSummaryProvider
    extends
        $FunctionalProvider<
          ({int offline, int online, int total, int warnings}),
          ({int offline, int online, int total, int warnings}),
          ({int offline, int online, int total, int warnings})
        >
    with $Provider<({int offline, int online, int total, int warnings})> {
  /// Aggregate node counts for [StatusBar]. Riverpod dedupes record results by
  /// structural equality, so this only triggers a `StatusBar` rebuild when one
  /// of the counts actually changes — not on every single-node telemetry tick
  /// that leaves them all the same.
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
  $ProviderElement<({int offline, int online, int total, int warnings})>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ({int offline, int online, int total, int warnings}) create(Ref ref) {
    return statusSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({int offline, int online, int total, int warnings}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({int offline, int online, int total, int warnings})
          >(value),
    );
  }
}

String _$statusSummaryHash() => r'5977da14e306f0218e3147c8def08486040ee130';
