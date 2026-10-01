// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pre_show_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One projector's pre-show while a Remote Preview of it is open — in the
/// app's dialog or on a web page — so both show the same state and either can
/// change it. Not `keepAlive`: read on first watch, forgotten when the last
/// preview closes (pre-show itself is sticky projector-side).

@ProviderFor(PreShow)
final preShowProvider = PreShowFamily._();

/// One projector's pre-show while a Remote Preview of it is open — in the
/// app's dialog or on a web page — so both show the same state and either can
/// change it. Not `keepAlive`: read on first watch, forgotten when the last
/// preview closes (pre-show itself is sticky projector-side).
final class PreShowProvider extends $NotifierProvider<PreShow, PreShowState> {
  /// One projector's pre-show while a Remote Preview of it is open — in the
  /// app's dialog or on a web page — so both show the same state and either can
  /// change it. Not `keepAlive`: read on first watch, forgotten when the last
  /// preview closes (pre-show itself is sticky projector-side).
  PreShowProvider._({
    required PreShowFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'preShowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$preShowHash();

  @override
  String toString() {
    return r'preShowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PreShow create() => PreShow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreShowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreShowState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreShowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$preShowHash() => r'252a0e1d9ebf9045237332c91df97637c46ba9a2';

/// One projector's pre-show while a Remote Preview of it is open — in the
/// app's dialog or on a web page — so both show the same state and either can
/// change it. Not `keepAlive`: read on first watch, forgotten when the last
/// preview closes (pre-show itself is sticky projector-side).

final class PreShowFamily extends $Family
    with
        $ClassFamilyOverride<
          PreShow,
          PreShowState,
          PreShowState,
          PreShowState,
          String
        > {
  PreShowFamily._()
    : super(
        retry: null,
        name: r'preShowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One projector's pre-show while a Remote Preview of it is open — in the
  /// app's dialog or on a web page — so both show the same state and either can
  /// change it. Not `keepAlive`: read on first watch, forgotten when the last
  /// preview closes (pre-show itself is sticky projector-side).

  PreShowProvider call(String nodeId) =>
      PreShowProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'preShowProvider';
}

/// One projector's pre-show while a Remote Preview of it is open — in the
/// app's dialog or on a web page — so both show the same state and either can
/// change it. Not `keepAlive`: read on first watch, forgotten when the last
/// preview closes (pre-show itself is sticky projector-side).

abstract class _$PreShow extends $Notifier<PreShowState> {
  late final _$args = ref.$arg as String;
  String get nodeId => _$args;

  PreShowState build(String nodeId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PreShowState, PreShowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PreShowState, PreShowState>,
              PreShowState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
