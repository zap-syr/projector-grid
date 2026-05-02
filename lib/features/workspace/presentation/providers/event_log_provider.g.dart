// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EventLogNotifier)
final eventLogProvider = EventLogNotifierProvider._();

final class EventLogNotifierProvider
    extends $NotifierProvider<EventLogNotifier, List<LogEvent>> {
  EventLogNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventLogNotifierHash();

  @$internal
  @override
  EventLogNotifier create() => EventLogNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<LogEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<LogEvent>>(value),
    );
  }
}

String _$eventLogNotifierHash() => r'35a206722d14fa20e6303997d2fb21895cc30cff';

abstract class _$EventLogNotifier extends $Notifier<List<LogEvent>> {
  List<LogEvent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<LogEvent>, List<LogEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<LogEvent>, List<LogEvent>>,
              List<LogEvent>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
