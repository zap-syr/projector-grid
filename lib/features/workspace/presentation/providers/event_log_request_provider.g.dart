// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_request_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EventLogRequestNotifier)
final eventLogRequestProvider = EventLogRequestNotifierProvider._();

final class EventLogRequestNotifierProvider
    extends $NotifierProvider<EventLogRequestNotifier, EventLogRequest?> {
  EventLogRequestNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventLogRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventLogRequestNotifierHash();

  @$internal
  @override
  EventLogRequestNotifier create() => EventLogRequestNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventLogRequest? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventLogRequest?>(value),
    );
  }
}

String _$eventLogRequestNotifierHash() =>
    r'620b07f6b0834b097b014aca6e18293b740155cf';

abstract class _$EventLogRequestNotifier extends $Notifier<EventLogRequest?> {
  EventLogRequest? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<EventLogRequest?, EventLogRequest?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EventLogRequest?, EventLogRequest?>,
              EventLogRequest?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
