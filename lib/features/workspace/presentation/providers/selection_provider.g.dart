// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the set of currently-selected projector node IDs.
///
/// This is pure UI state — it deliberately lives outside [ProjectorNode] so
/// that selecting/deselecting nodes doesn't rebuild the node list, doesn't
/// get captured in undo/redo snapshots, and never touches project-file
/// serialization.

@ProviderFor(SelectionNotifier)
final selectionProvider = SelectionNotifierProvider._();

/// Holds the set of currently-selected projector node IDs.
///
/// This is pure UI state — it deliberately lives outside [ProjectorNode] so
/// that selecting/deselecting nodes doesn't rebuild the node list, doesn't
/// get captured in undo/redo snapshots, and never touches project-file
/// serialization.
final class SelectionNotifierProvider
    extends $NotifierProvider<SelectionNotifier, Set<String>> {
  /// Holds the set of currently-selected projector node IDs.
  ///
  /// This is pure UI state — it deliberately lives outside [ProjectorNode] so
  /// that selecting/deselecting nodes doesn't rebuild the node list, doesn't
  /// get captured in undo/redo snapshots, and never touches project-file
  /// serialization.
  SelectionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectionNotifierHash();

  @$internal
  @override
  SelectionNotifier create() => SelectionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$selectionNotifierHash() => r'12264568227cfb502ad23877344f1567a3311f41';

/// Holds the set of currently-selected projector node IDs.
///
/// This is pure UI state — it deliberately lives outside [ProjectorNode] so
/// that selecting/deselecting nodes doesn't rebuild the node list, doesn't
/// get captured in undo/redo snapshots, and never touches project-file
/// serialization.

abstract class _$SelectionNotifier extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
