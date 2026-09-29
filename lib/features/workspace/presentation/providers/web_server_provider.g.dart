// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_server_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Web Access server lifecycle; state = whether it's listening. Also the
/// [WebApiSource] the routes read from, so the API reports exactly what the
/// app's providers hold.

@ProviderFor(WebServerNotifier)
final webServerProvider = WebServerNotifierProvider._();

/// Web Access server lifecycle; state = whether it's listening. Also the
/// [WebApiSource] the routes read from, so the API reports exactly what the
/// app's providers hold.
final class WebServerNotifierProvider
    extends $NotifierProvider<WebServerNotifier, bool> {
  /// Web Access server lifecycle; state = whether it's listening. Also the
  /// [WebApiSource] the routes read from, so the API reports exactly what the
  /// app's providers hold.
  WebServerNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webServerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webServerNotifierHash();

  @$internal
  @override
  WebServerNotifier create() => WebServerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$webServerNotifierHash() => r'6ee47f4c8c57949a85639a807c2d65f2a0af63af';

/// Web Access server lifecycle; state = whether it's listening. Also the
/// [WebApiSource] the routes read from, so the API reports exactly what the
/// app's providers hold.

abstract class _$WebServerNotifier extends $Notifier<bool> {
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
