// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'canvas_reveal_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A request for the canvas to scroll a card into view (Monitoring's *Find
/// on canvas*). [seq] grows with every request, so asking for the same
/// projector twice scrolls twice.

@ProviderFor(CanvasRevealNotifier)
final canvasRevealProvider = CanvasRevealNotifierProvider._();

/// A request for the canvas to scroll a card into view (Monitoring's *Find
/// on canvas*). [seq] grows with every request, so asking for the same
/// projector twice scrolls twice.
final class CanvasRevealNotifierProvider
    extends
        $NotifierProvider<CanvasRevealNotifier, ({String nodeId, int seq})?> {
  /// A request for the canvas to scroll a card into view (Monitoring's *Find
  /// on canvas*). [seq] grows with every request, so asking for the same
  /// projector twice scrolls twice.
  CanvasRevealNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canvasRevealProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canvasRevealNotifierHash();

  @$internal
  @override
  CanvasRevealNotifier create() => CanvasRevealNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String nodeId, int seq})? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({String nodeId, int seq})?>(value),
    );
  }
}

String _$canvasRevealNotifierHash() =>
    r'1c8af68332c2ba4a698afbddf1fb35a133d5b7da';

/// A request for the canvas to scroll a card into view (Monitoring's *Find
/// on canvas*). [seq] grows with every request, so asking for the same
/// projector twice scrolls twice.

abstract class _$CanvasRevealNotifier
    extends $Notifier<({String nodeId, int seq})?> {
  ({String nodeId, int seq})? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<({String nodeId, int seq})?, ({String nodeId, int seq})?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String nodeId, int seq})?,
                ({String nodeId, int seq})?
              >,
              ({String nodeId, int seq})?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
