// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poll_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
/// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
/// undo/redo snapshots or project-file serialization.

@ProviderFor(PollStatusNotifier)
final pollStatusProvider = PollStatusNotifierProvider._();

/// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
/// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
/// undo/redo snapshots or project-file serialization.
final class PollStatusNotifierProvider
    extends $NotifierProvider<PollStatusNotifier, PollStatus> {
  /// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
  /// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
  /// undo/redo snapshots or project-file serialization.
  PollStatusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pollStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pollStatusNotifierHash();

  @$internal
  @override
  PollStatusNotifier create() => PollStatusNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PollStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PollStatus>(value),
    );
  }
}

String _$pollStatusNotifierHash() =>
    r'6a5773d1678b465ca1ad42533722822463666011';

/// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
/// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
/// undo/redo snapshots or project-file serialization.

abstract class _$PollStatusNotifier extends $Notifier<PollStatus> {
  PollStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PollStatus, PollStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PollStatus, PollStatus>,
              PollStatus,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
