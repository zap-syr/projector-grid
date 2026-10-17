// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitoring_panel_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The projector whose panel is open over the Monitoring view, or null.
/// Session only. Kept apart from `selectionProvider`: opening a panel here
/// mustn't change what the Controls view has selected.

@ProviderFor(MonitoringPanelNotifier)
final monitoringPanelProvider = MonitoringPanelNotifierProvider._();

/// The projector whose panel is open over the Monitoring view, or null.
/// Session only. Kept apart from `selectionProvider`: opening a panel here
/// mustn't change what the Controls view has selected.
final class MonitoringPanelNotifierProvider
    extends $NotifierProvider<MonitoringPanelNotifier, String?> {
  /// The projector whose panel is open over the Monitoring view, or null.
  /// Session only. Kept apart from `selectionProvider`: opening a panel here
  /// mustn't change what the Controls view has selected.
  MonitoringPanelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringPanelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringPanelNotifierHash();

  @$internal
  @override
  MonitoringPanelNotifier create() => MonitoringPanelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$monitoringPanelNotifierHash() =>
    r'231473be02e057aea64939d3d8921719dc9ba2b5';

/// The projector whose panel is open over the Monitoring view, or null.
/// Session only. Kept apart from `selectionProvider`: opening a panel here
/// mustn't change what the Controls view has selected.

abstract class _$MonitoringPanelNotifier extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
