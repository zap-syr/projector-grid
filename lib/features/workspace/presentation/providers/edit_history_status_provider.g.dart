// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_history_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Undo/redo availability for `TopMenuBar`'s Edit menu.
///
/// `canUndo`/`canRedo` live on `WorkspaceNotifier`'s private undo/redo stacks,
/// not in its public `state` list, so this can't be a `.select()` on
/// `workspaceProvider`. Every path that mutates those stacks also reassigns
/// `state` in the same turn (the group/node edit methods right after
/// `_saveSnapshot`, `undo`/`redo` via `_restoreSnapshot`, and `saveBeforeMove`
/// which forces `state = [...state]` for exactly this reason), so watching the
/// list here is enough to recompute at the right times — record equality then
/// dedupes away the many state changes (e.g. telemetry polling, card drags)
/// that leave undo/redo availability unchanged, so widgets watching this
/// provider don't rebuild for those.

@ProviderFor(editHistoryStatus)
final editHistoryStatusProvider = EditHistoryStatusProvider._();

/// Undo/redo availability for `TopMenuBar`'s Edit menu.
///
/// `canUndo`/`canRedo` live on `WorkspaceNotifier`'s private undo/redo stacks,
/// not in its public `state` list, so this can't be a `.select()` on
/// `workspaceProvider`. Every path that mutates those stacks also reassigns
/// `state` in the same turn (the group/node edit methods right after
/// `_saveSnapshot`, `undo`/`redo` via `_restoreSnapshot`, and `saveBeforeMove`
/// which forces `state = [...state]` for exactly this reason), so watching the
/// list here is enough to recompute at the right times — record equality then
/// dedupes away the many state changes (e.g. telemetry polling, card drags)
/// that leave undo/redo availability unchanged, so widgets watching this
/// provider don't rebuild for those.

final class EditHistoryStatusProvider
    extends
        $FunctionalProvider<
          ({bool canRedo, bool canUndo}),
          ({bool canRedo, bool canUndo}),
          ({bool canRedo, bool canUndo})
        >
    with $Provider<({bool canRedo, bool canUndo})> {
  /// Undo/redo availability for `TopMenuBar`'s Edit menu.
  ///
  /// `canUndo`/`canRedo` live on `WorkspaceNotifier`'s private undo/redo stacks,
  /// not in its public `state` list, so this can't be a `.select()` on
  /// `workspaceProvider`. Every path that mutates those stacks also reassigns
  /// `state` in the same turn (the group/node edit methods right after
  /// `_saveSnapshot`, `undo`/`redo` via `_restoreSnapshot`, and `saveBeforeMove`
  /// which forces `state = [...state]` for exactly this reason), so watching the
  /// list here is enough to recompute at the right times — record equality then
  /// dedupes away the many state changes (e.g. telemetry polling, card drags)
  /// that leave undo/redo availability unchanged, so widgets watching this
  /// provider don't rebuild for those.
  EditHistoryStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editHistoryStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editHistoryStatusHash();

  @$internal
  @override
  $ProviderElement<({bool canRedo, bool canUndo})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({bool canRedo, bool canUndo}) create(Ref ref) {
    return editHistoryStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({bool canRedo, bool canUndo}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({bool canRedo, bool canUndo})>(
        value,
      ),
    );
  }
}

String _$editHistoryStatusHash() => r'8e01321c9b954405725afcb0d047912a4df38ab9';
