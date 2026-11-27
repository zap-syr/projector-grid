// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warp_edit_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The free grid editor's session with one projector: the memory PC-1 to
/// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
/// while the editor is open, and nothing else talks to the projector's warp
/// memories.
///
/// Every transfer claims the projector from the regular poll and the signal
/// watch first (`claimNodeForExternalPoll`), so one projector never sees
/// more than one of the app's transfers at a time.

@ProviderFor(WarpEditSession)
final warpEditSessionProvider = WarpEditSessionFamily._();

/// The free grid editor's session with one projector: the memory PC-1 to
/// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
/// while the editor is open, and nothing else talks to the projector's warp
/// memories.
///
/// Every transfer claims the projector from the regular poll and the signal
/// watch first (`claimNodeForExternalPoll`), so one projector never sees
/// more than one of the app's transfers at a time.
final class WarpEditSessionProvider
    extends $NotifierProvider<WarpEditSession, WarpSessionState> {
  /// The free grid editor's session with one projector: the memory PC-1 to
  /// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
  /// while the editor is open, and nothing else talks to the projector's warp
  /// memories.
  ///
  /// Every transfer claims the projector from the regular poll and the signal
  /// watch first (`claimNodeForExternalPoll`), so one projector never sees
  /// more than one of the app's transfers at a time.
  WarpEditSessionProvider._({
    required WarpEditSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'warpEditSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$warpEditSessionHash();

  @override
  String toString() {
    return r'warpEditSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WarpEditSession create() => WarpEditSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WarpSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WarpSessionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WarpEditSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$warpEditSessionHash() => r'8071a9a5e13385181ea774116695b626e812d511';

/// The free grid editor's session with one projector: the memory PC-1 to
/// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
/// while the editor is open, and nothing else talks to the projector's warp
/// memories.
///
/// Every transfer claims the projector from the regular poll and the signal
/// watch first (`claimNodeForExternalPoll`), so one projector never sees
/// more than one of the app's transfers at a time.

final class WarpEditSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          WarpEditSession,
          WarpSessionState,
          WarpSessionState,
          WarpSessionState,
          String
        > {
  WarpEditSessionFamily._()
    : super(
        retry: null,
        name: r'warpEditSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The free grid editor's session with one projector: the memory PC-1 to
  /// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
  /// while the editor is open, and nothing else talks to the projector's warp
  /// memories.
  ///
  /// Every transfer claims the projector from the regular poll and the signal
  /// watch first (`claimNodeForExternalPoll`), so one projector never sees
  /// more than one of the app's transfers at a time.

  WarpEditSessionProvider call(String nodeId) =>
      WarpEditSessionProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'warpEditSessionProvider';
}

/// The free grid editor's session with one projector: the memory PC-1 to
/// PC-3 it shows, and every read and write of it. Not `keepAlive`: it lives
/// while the editor is open, and nothing else talks to the projector's warp
/// memories.
///
/// Every transfer claims the projector from the regular poll and the signal
/// watch first (`claimNodeForExternalPoll`), so one projector never sees
/// more than one of the app's transfers at a time.

abstract class _$WarpEditSession extends $Notifier<WarpSessionState> {
  late final _$args = ref.$arg as String;
  String get nodeId => _$args;

  WarpSessionState build(String nodeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WarpSessionState, WarpSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WarpSessionState, WarpSessionState>,
              WarpSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
