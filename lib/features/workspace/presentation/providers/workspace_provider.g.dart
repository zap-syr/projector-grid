// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkspaceNotifier)
final workspaceProvider = WorkspaceNotifierProvider._();

final class WorkspaceNotifierProvider
    extends $NotifierProvider<WorkspaceNotifier, List<ProjectorNode>> {
  WorkspaceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceNotifierHash();

  @$internal
  @override
  WorkspaceNotifier create() => WorkspaceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ProjectorNode> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ProjectorNode>>(value),
    );
  }
}

String _$workspaceNotifierHash() => r'd21e63fd0de774ef00b3c67ba40271185b725678';

abstract class _$WorkspaceNotifier extends $Notifier<List<ProjectorNode>> {
  List<ProjectorNode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<ProjectorNode>, List<ProjectorNode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ProjectorNode>, List<ProjectorNode>>,
              List<ProjectorNode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
