// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'osc_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OscNotifier)
final oscProvider = OscNotifierProvider._();

final class OscNotifierProvider
    extends $NotifierProvider<OscNotifier, OscStatus> {
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
  Override overrideWithValue(OscStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OscStatus>(value),
    );
  }
}

String _$oscNotifierHash() => r'0fa4bc20a8507e9f20397e486014d955b1015c45';

abstract class _$OscNotifier extends $Notifier<OscStatus> {
  OscStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<OscStatus, OscStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OscStatus, OscStatus>,
              OscStatus,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
