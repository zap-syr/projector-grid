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
        isAutoDispose: true,
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

String _$workspaceNotifierHash() => r'd75226c761009a8efce95b6a9312d518d5ade238';

abstract class _$WorkspaceNotifier extends $Notifier<List<ProjectorNode>> {
  List<ProjectorNode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<ProjectorNode>, List<ProjectorNode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ProjectorNode>, List<ProjectorNode>>,
              List<ProjectorNode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
