// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alignment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Alignment mode (ROADMAP_PLAN.md §3.2): one focused projector open with
/// its pattern, neighbours or everyone optionally open with the Others
/// pattern, the rest of the scope closed. Holds no widget state so the web
/// API (§5) can drive the same methods.

@ProviderFor(AlignmentNotifier)
final alignmentProvider = AlignmentNotifierProvider._();

/// Alignment mode (ROADMAP_PLAN.md §3.2): one focused projector open with
/// its pattern, neighbours or everyone optionally open with the Others
/// pattern, the rest of the scope closed. Holds no widget state so the web
/// API (§5) can drive the same methods.
final class AlignmentNotifierProvider
    extends $NotifierProvider<AlignmentNotifier, AlignmentState> {
  /// Alignment mode (ROADMAP_PLAN.md §3.2): one focused projector open with
  /// its pattern, neighbours or everyone optionally open with the Others
  /// pattern, the rest of the scope closed. Holds no widget state so the web
  /// API (§5) can drive the same methods.
  AlignmentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alignmentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alignmentNotifierHash();

  @$internal
  @override
  AlignmentNotifier create() => AlignmentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlignmentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlignmentState>(value),
    );
  }
}

String _$alignmentNotifierHash() => r'7f63cb38afd764e24319d01b2f9bcab4cd34dabe';

/// Alignment mode (ROADMAP_PLAN.md §3.2): one focused projector open with
/// its pattern, neighbours or everyone optionally open with the Others
/// pattern, the rest of the scope closed. Holds no widget state so the web
/// API (§5) can drive the same methods.

abstract class _$AlignmentNotifier extends $Notifier<AlignmentState> {
  AlignmentState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AlignmentState, AlignmentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AlignmentState, AlignmentState>,
              AlignmentState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
