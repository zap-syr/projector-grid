// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'osc_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OscNotifier)
final oscProvider = OscNotifierProvider._();

final class OscNotifierProvider extends $NotifierProvider<OscNotifier, bool> {
  OscNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oscProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oscNotifierHash();

  @$internal
  @override
  OscNotifier create() => OscNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$oscNotifierHash() => r'93e672b3d8ea663c8f9ead653ef6825ec7e6943c';

abstract class _$OscNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
