// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolbar_counts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Number of groups, for the toolbar's Groups badge.
///
/// Groups live in `WorkspaceNotifier`'s private list, not in its state, so
/// this can't be a `.select()` on `workspaceProvider`. Every group edit
/// reassigns the node list in the same turn (and a project load sets the
/// nodes right before the groups), so watching the list recomputes at the
/// right times; the int result then dedupes the polling ticks away, and the
/// toolbar doesn't rebuild for them.

@ProviderFor(groupCount)
final groupCountProvider = GroupCountProvider._();

/// Number of groups, for the toolbar's Groups badge.
///
/// Groups live in `WorkspaceNotifier`'s private list, not in its state, so
/// this can't be a `.select()` on `workspaceProvider`. Every group edit
/// reassigns the node list in the same turn (and a project load sets the
/// nodes right before the groups), so watching the list recomputes at the
/// right times; the int result then dedupes the polling ticks away, and the
/// toolbar doesn't rebuild for them.

final class GroupCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Number of groups, for the toolbar's Groups badge.
  ///
  /// Groups live in `WorkspaceNotifier`'s private list, not in its state, so
  /// this can't be a `.select()` on `workspaceProvider`. Every group edit
  /// reassigns the node list in the same turn (and a project load sets the
  /// nodes right before the groups), so watching the list recomputes at the
  /// right times; the int result then dedupes the polling ticks away, and the
  /// toolbar doesn't rebuild for them.
  GroupCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return groupCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$groupCountHash() => r'74cf85e91219d3e5915126dd98183c0c333de8fe';

/// Active (enabled) scheduled tasks and when the next one runs, already
/// worded for the tooltip (`at 22:30`, `tomorrow at 07:00`).
///
/// Recomputes itself when that run time passes and at midnight, so the
/// wording never goes stale while the task list stays the same; the record
/// result dedupes those recomputes when nothing visible changed.

@ProviderFor(scheduledTasksSummary)
final scheduledTasksSummaryProvider = ScheduledTasksSummaryProvider._();

/// Active (enabled) scheduled tasks and when the next one runs, already
/// worded for the tooltip (`at 22:30`, `tomorrow at 07:00`).
///
/// Recomputes itself when that run time passes and at midnight, so the
/// wording never goes stale while the task list stays the same; the record
/// result dedupes those recomputes when nothing visible changed.

final class ScheduledTasksSummaryProvider
    extends
        $FunctionalProvider<
          ({int active, String? nextRun}),
          ({int active, String? nextRun}),
          ({int active, String? nextRun})
        >
    with $Provider<({int active, String? nextRun})> {
  /// Active (enabled) scheduled tasks and when the next one runs, already
  /// worded for the tooltip (`at 22:30`, `tomorrow at 07:00`).
  ///
  /// Recomputes itself when that run time passes and at midnight, so the
  /// wording never goes stale while the task list stays the same; the record
  /// result dedupes those recomputes when nothing visible changed.
  ScheduledTasksSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledTasksSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledTasksSummaryHash();

  @$internal
  @override
  $ProviderElement<({int active, String? nextRun})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({int active, String? nextRun}) create(Ref ref) {
    return scheduledTasksSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({int active, String? nextRun}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({int active, String? nextRun})>(
        value,
      ),
    );
  }
}

String _$scheduledTasksSummaryHash() =>
    r'0cf48bc75074b6bb8aaf34b3de86f9dba91e6395';
