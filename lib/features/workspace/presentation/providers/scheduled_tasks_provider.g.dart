// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ScheduledTasksNotifier)
final scheduledTasksProvider = ScheduledTasksNotifierProvider._();

final class ScheduledTasksNotifierProvider
    extends $NotifierProvider<ScheduledTasksNotifier, List<ScheduledTask>> {
  ScheduledTasksNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledTasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledTasksNotifierHash();

  @$internal
  @override
  ScheduledTasksNotifier create() => ScheduledTasksNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ScheduledTask> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ScheduledTask>>(value),
    );
  }
}

String _$scheduledTasksNotifierHash() =>
    r'b0dabc772b639aed36858485895e5a92e9a41d34';

abstract class _$ScheduledTasksNotifier extends $Notifier<List<ScheduledTask>> {
  List<ScheduledTask> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<ScheduledTask>, List<ScheduledTask>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ScheduledTask>, List<ScheduledTask>>,
              List<ScheduledTask>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
