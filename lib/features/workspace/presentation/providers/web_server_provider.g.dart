// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_server_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Web Access server lifecycle; state = whether it's listening.

@ProviderFor(WebServerNotifier)
final webServerProvider = WebServerNotifierProvider._();

/// Web Access server lifecycle; state = whether it's listening.
final class WebServerNotifierProvider
    extends $NotifierProvider<WebServerNotifier, bool> {
  /// Web Access server lifecycle; state = whether it's listening.
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

String _$webServerNotifierHash() => r'41a49b22e04bee32f775ffb4d5ddd5b2b87d5449';

/// Web Access server lifecycle; state = whether it's listening.

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
