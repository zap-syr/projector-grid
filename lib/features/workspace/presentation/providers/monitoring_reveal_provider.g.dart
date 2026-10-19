// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitoring_reveal_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A projector the Monitoring table or cards should scroll into view (the
/// quick status popover's *Show in Monitoring*), or null. Whichever view is
/// showing takes it and clears it, so switching Table / Cards afterwards
/// doesn't scroll again.

@ProviderFor(MonitoringRevealNotifier)
final monitoringRevealProvider = MonitoringRevealNotifierProvider._();

/// A projector the Monitoring table or cards should scroll into view (the
/// quick status popover's *Show in Monitoring*), or null. Whichever view is
/// showing takes it and clears it, so switching Table / Cards afterwards
/// doesn't scroll again.
final class MonitoringRevealNotifierProvider
    extends $NotifierProvider<MonitoringRevealNotifier, String?> {
  /// A projector the Monitoring table or cards should scroll into view (the
  /// quick status popover's *Show in Monitoring*), or null. Whichever view is
  /// showing takes it and clears it, so switching Table / Cards afterwards
  /// doesn't scroll again.
  MonitoringRevealNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitoringRevealProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitoringRevealNotifierHash();

  @$internal
  @override
  MonitoringRevealNotifier create() => MonitoringRevealNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$monitoringRevealNotifierHash() =>
    r'46ecc7ac378d72566aca0b19e41f29d6cc9f0cbd';

/// A projector the Monitoring table or cards should scroll into view (the
/// quick status popover's *Show in Monitoring*), or null. Whichever view is
/// showing takes it and clears it, so switching Table / Cards afterwards
/// doesn't scroll again.

abstract class _$MonitoringRevealNotifier extends $Notifier<String?> {
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
