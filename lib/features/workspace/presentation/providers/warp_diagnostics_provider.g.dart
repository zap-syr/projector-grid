// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warp_diagnostics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The save dialog, as a provider so tests never open a real one.

@ProviderFor(warpDiagnosticsSaveDialog)
final warpDiagnosticsSaveDialogProvider = WarpDiagnosticsSaveDialogProvider._();

/// The save dialog, as a provider so tests never open a real one.

final class WarpDiagnosticsSaveDialogProvider
    extends
        $FunctionalProvider<
          NativeSaveDialog,
          NativeSaveDialog,
          NativeSaveDialog
        >
    with $Provider<NativeSaveDialog> {
  /// The save dialog, as a provider so tests never open a real one.
  WarpDiagnosticsSaveDialogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'warpDiagnosticsSaveDialogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$warpDiagnosticsSaveDialogHash();

  @$internal
  @override
  $ProviderElement<NativeSaveDialog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NativeSaveDialog create(Ref ref) {
    return warpDiagnosticsSaveDialog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NativeSaveDialog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NativeSaveDialog>(value),
    );
  }
}

String _$warpDiagnosticsSaveDialogHash() =>
    r'0fcf2c24fd5d4b4056c878ff05918eb111cf8afa';

/// The app version for the report header, as the app log writes it
/// (`2.0.1+13`). A provider so tests need no platform channel.

@ProviderFor(warpDiagnosticsAppVersion)
final warpDiagnosticsAppVersionProvider = WarpDiagnosticsAppVersionProvider._();

/// The app version for the report header, as the app log writes it
/// (`2.0.1+13`). A provider so tests need no platform channel.

final class WarpDiagnosticsAppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The app version for the report header, as the app log writes it
  /// (`2.0.1+13`). A provider so tests need no platform channel.
  WarpDiagnosticsAppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'warpDiagnosticsAppVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$warpDiagnosticsAppVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return warpDiagnosticsAppVersion(ref);
  }
}

String _$warpDiagnosticsAppVersionHash() =>
    r'2b7d6d837f212424e32a163f092a2592263d6fa2';

/// A read-only survey of one projector's free grid memories, saved as a text
/// file for a model whose table format the app does not understand. Manual:
/// nothing runs until [save] is called. Not `keepAlive`: it lives while the
/// notice that starts it is on screen.
///
/// Like every transfer it claims the projector from the regular poll first
/// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
/// connections at once, and gives the claim back before the save dialog opens.

@ProviderFor(WarpDiagnostics)
final warpDiagnosticsProvider = WarpDiagnosticsFamily._();

/// A read-only survey of one projector's free grid memories, saved as a text
/// file for a model whose table format the app does not understand. Manual:
/// nothing runs until [save] is called. Not `keepAlive`: it lives while the
/// notice that starts it is on screen.
///
/// Like every transfer it claims the projector from the regular poll first
/// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
/// connections at once, and gives the claim back before the save dialog opens.
final class WarpDiagnosticsProvider
    extends $NotifierProvider<WarpDiagnostics, WarpDiagnosticsState> {
  /// A read-only survey of one projector's free grid memories, saved as a text
  /// file for a model whose table format the app does not understand. Manual:
  /// nothing runs until [save] is called. Not `keepAlive`: it lives while the
  /// notice that starts it is on screen.
  ///
  /// Like every transfer it claims the projector from the regular poll first
  /// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
  /// connections at once, and gives the claim back before the save dialog opens.
  WarpDiagnosticsProvider._({
    required WarpDiagnosticsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'warpDiagnosticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$warpDiagnosticsHash();

  @override
  String toString() {
    return r'warpDiagnosticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WarpDiagnostics create() => WarpDiagnostics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WarpDiagnosticsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WarpDiagnosticsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WarpDiagnosticsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$warpDiagnosticsHash() => r'0482f2dfaa8285eb4052a616e3635558948132d8';

/// A read-only survey of one projector's free grid memories, saved as a text
/// file for a model whose table format the app does not understand. Manual:
/// nothing runs until [save] is called. Not `keepAlive`: it lives while the
/// notice that starts it is on screen.
///
/// Like every transfer it claims the projector from the regular poll first
/// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
/// connections at once, and gives the claim back before the save dialog opens.

final class WarpDiagnosticsFamily extends $Family
    with
        $ClassFamilyOverride<
          WarpDiagnostics,
          WarpDiagnosticsState,
          WarpDiagnosticsState,
          WarpDiagnosticsState,
          String
        > {
  WarpDiagnosticsFamily._()
    : super(
        retry: null,
        name: r'warpDiagnosticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A read-only survey of one projector's free grid memories, saved as a text
  /// file for a model whose table format the app does not understand. Manual:
  /// nothing runs until [save] is called. Not `keepAlive`: it lives while the
  /// notice that starts it is on screen.
  ///
  /// Like every transfer it claims the projector from the regular poll first
  /// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
  /// connections at once, and gives the claim back before the save dialog opens.

  WarpDiagnosticsProvider call(String nodeId) =>
      WarpDiagnosticsProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'warpDiagnosticsProvider';
}

/// A read-only survey of one projector's free grid memories, saved as a text
/// file for a model whose table format the app does not understand. Manual:
/// nothing runs until [save] is called. Not `keepAlive`: it lives while the
/// notice that starts it is on screen.
///
/// Like every transfer it claims the projector from the regular poll first
/// (`claimNodeForExternalPoll`), so the projector never sees two of the app's
/// connections at once, and gives the claim back before the save dialog opens.

abstract class _$WarpDiagnostics extends $Notifier<WarpDiagnosticsState> {
  late final _$args = ref.$arg as String;
  String get nodeId => _$args;

  WarpDiagnosticsState build(String nodeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WarpDiagnosticsState, WarpDiagnosticsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WarpDiagnosticsState, WarpDiagnosticsState>,
              WarpDiagnosticsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
