// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_lens_lock_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lens lock of the selection, for the Lens shift card's lock button and the
/// state of its lens buttons. Record equality dedupes the telemetry ticks
/// and drags that leave it unchanged, so the card doesn't rebuild on them.

@ProviderFor(selectedLensLock)
final selectedLensLockProvider = SelectedLensLockProvider._();

/// Lens lock of the selection, for the Lens shift card's lock button and the
/// state of its lens buttons. Record equality dedupes the telemetry ticks
/// and drags that leave it unchanged, so the card doesn't rebuild on them.

final class SelectedLensLockProvider
    extends
        $FunctionalProvider<
          ({int locked, LensLockState state, int total}),
          ({int locked, LensLockState state, int total}),
          ({int locked, LensLockState state, int total})
        >
    with $Provider<({int locked, LensLockState state, int total})> {
  /// Lens lock of the selection, for the Lens shift card's lock button and the
  /// state of its lens buttons. Record equality dedupes the telemetry ticks
  /// and drags that leave it unchanged, so the card doesn't rebuild on them.
  SelectedLensLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedLensLockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedLensLockHash();

  @$internal
  @override
  $ProviderElement<({int locked, LensLockState state, int total})>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ({int locked, LensLockState state, int total}) create(Ref ref) {
    return selectedLensLock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({int locked, LensLockState state, int total}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({int locked, LensLockState state, int total})>(
            value,
          ),
    );
  }
}

String _$selectedLensLockHash() => r'19b29205ce3ee0c4712dc639fa563989c20c988c';
