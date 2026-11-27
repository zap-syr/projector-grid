// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warp_backup_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the backups of the free grid memories live. A provider so tests can
/// point it at a temp folder.

@ProviderFor(warpBackupStore)
final warpBackupStoreProvider = WarpBackupStoreProvider._();

/// Where the backups of the free grid memories live. A provider so tests can
/// point it at a temp folder.

final class WarpBackupStoreProvider
    extends
        $FunctionalProvider<WarpBackupStore, WarpBackupStore, WarpBackupStore>
    with $Provider<WarpBackupStore> {
  /// Where the backups of the free grid memories live. A provider so tests can
  /// point it at a temp folder.
  WarpBackupStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'warpBackupStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$warpBackupStoreHash();

  @$internal
  @override
  $ProviderElement<WarpBackupStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WarpBackupStore create(Ref ref) {
    return warpBackupStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WarpBackupStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WarpBackupStore>(value),
    );
  }
}

String _$warpBackupStoreHash() => r'c95a8196a3252ddaa31a3f09e77da9cc71ab8c03';
