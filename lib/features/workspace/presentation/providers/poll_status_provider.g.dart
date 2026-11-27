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
        isAutoDispose: false,
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
    r'163449d7111c911153596aba9bd466570d1663b9';

/// Tracks poll-cycle timing/progress. Pure UI feedback — deliberately kept
/// outside [WorkspaceNotifier]'s node-list state so it isn't captured in
/// undo/redo snapshots or project-file serialization.

abstract class _$PollStatusNotifier extends $Notifier<PollStatus> {
  PollStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PollStatus, PollStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PollStatus, PollStatus>,
              PollStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
