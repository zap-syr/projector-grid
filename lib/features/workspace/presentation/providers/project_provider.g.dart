// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectStateNotifier)
final projectStateProvider = ProjectStateNotifierProvider._();

final class ProjectStateNotifierProvider
    extends $NotifierProvider<ProjectStateNotifier, ProjectState> {
  ProjectStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectStateNotifierHash();

  @$internal
  @override
  ProjectStateNotifier create() => ProjectStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectState>(value),
    );
  }
}

String _$projectStateNotifierHash() =>
    r'f88effc45a9200d463ad6db8ba47e8c59fc3754f';

abstract class _$ProjectStateNotifier extends $Notifier<ProjectState> {
  ProjectState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ProjectState, ProjectState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProjectState, ProjectState>,
              ProjectState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
