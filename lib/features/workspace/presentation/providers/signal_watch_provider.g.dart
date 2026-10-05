// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signal_watch_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Queries `QVX:NSGS1` on every powered-on projector every [period] while
/// the Signal lost rule is on, and keeps each projector's latest dropout.
/// The regular poll (30 s at best) misses dropouts between polls; a cable
/// pulled for ~1 s still leaves ~3.5 s without signal while the projector
/// re-locks, so 2 s catches every one (measured, ROADMAP §4 spike).
///
/// Sized for 150 projectors: each gets a fixed slot in the period, so the
/// queries go out evenly (one per ~13 ms) instead of in a burst; at most
/// [maxInFlight] are open at once; a projector whose query hasn't come back,
/// or that the app is already talking to ([WorkspaceNotifier.isNodeBusy]),
/// is skipped for that round. Time is counted in ticks of the scheduler's
/// own timer, so a busy event loop stretches the period rather than piling
/// queries up.

@ProviderFor(SignalWatchNotifier)
final signalWatchProvider = SignalWatchNotifierProvider._();

/// Queries `QVX:NSGS1` on every powered-on projector every [period] while
/// the Signal lost rule is on, and keeps each projector's latest dropout.
/// The regular poll (30 s at best) misses dropouts between polls; a cable
/// pulled for ~1 s still leaves ~3.5 s without signal while the projector
/// re-locks, so 2 s catches every one (measured, ROADMAP §4 spike).
///
/// Sized for 150 projectors: each gets a fixed slot in the period, so the
/// queries go out evenly (one per ~13 ms) instead of in a burst; at most
/// [maxInFlight] are open at once; a projector whose query hasn't come back,
/// or that the app is already talking to ([WorkspaceNotifier.isNodeBusy]),
/// is skipped for that round. Time is counted in ticks of the scheduler's
/// own timer, so a busy event loop stretches the period rather than piling
/// queries up.
final class SignalWatchNotifierProvider
    extends $NotifierProvider<SignalWatchNotifier, Map<String, SignalLoss>> {
  /// Queries `QVX:NSGS1` on every powered-on projector every [period] while
  /// the Signal lost rule is on, and keeps each projector's latest dropout.
  /// The regular poll (30 s at best) misses dropouts between polls; a cable
  /// pulled for ~1 s still leaves ~3.5 s without signal while the projector
  /// re-locks, so 2 s catches every one (measured, ROADMAP §4 spike).
  ///
  /// Sized for 150 projectors: each gets a fixed slot in the period, so the
  /// queries go out evenly (one per ~13 ms) instead of in a burst; at most
  /// [maxInFlight] are open at once; a projector whose query hasn't come back,
  /// or that the app is already talking to ([WorkspaceNotifier.isNodeBusy]),
  /// is skipped for that round. Time is counted in ticks of the scheduler's
  /// own timer, so a busy event loop stretches the period rather than piling
  /// queries up.
  SignalWatchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signalWatchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signalWatchNotifierHash();

  @$internal
  @override
  SignalWatchNotifier create() => SignalWatchNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, SignalLoss> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, SignalLoss>>(value),
    );
  }
}

String _$signalWatchNotifierHash() =>
    r'9dd32ac4df185b4838c04e06e9acd93e6fc7a4d3';

/// Queries `QVX:NSGS1` on every powered-on projector every [period] while
/// the Signal lost rule is on, and keeps each projector's latest dropout.
/// The regular poll (30 s at best) misses dropouts between polls; a cable
/// pulled for ~1 s still leaves ~3.5 s without signal while the projector
/// re-locks, so 2 s catches every one (measured, ROADMAP §4 spike).
///
/// Sized for 150 projectors: each gets a fixed slot in the period, so the
/// queries go out evenly (one per ~13 ms) instead of in a burst; at most
/// [maxInFlight] are open at once; a projector whose query hasn't come back,
/// or that the app is already talking to ([WorkspaceNotifier.isNodeBusy]),
/// is skipped for that round. Time is counted in ticks of the scheduler's
/// own timer, so a busy event loop stretches the period rather than piling
/// queries up.

abstract class _$SignalWatchNotifier
    extends $Notifier<Map<String, SignalLoss>> {
  Map<String, SignalLoss> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<Map<String, SignalLoss>, Map<String, SignalLoss>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, SignalLoss>, Map<String, SignalLoss>>,
              Map<String, SignalLoss>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
