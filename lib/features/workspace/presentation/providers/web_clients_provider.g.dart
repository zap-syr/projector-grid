// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_clients_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Signed-in web clients, kept by [WebServerNotifier] so the status bar and
/// Preferences can watch them without the server's internals.

@ProviderFor(WebClients)
final webClientsProvider = WebClientsProvider._();

/// Signed-in web clients, kept by [WebServerNotifier] so the status bar and
/// Preferences can watch them without the server's internals.
final class WebClientsProvider
    extends $NotifierProvider<WebClients, List<WebClient>> {
  /// Signed-in web clients, kept by [WebServerNotifier] so the status bar and
  /// Preferences can watch them without the server's internals.
  WebClientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webClientsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webClientsHash();

  @$internal
  @override
  WebClients create() => WebClients();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WebClient> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WebClient>>(value),
    );
  }
}

String _$webClientsHash() => r'3b30d8af54129ba31a0ce650ffb1fe8eda5883d6';

/// Signed-in web clients, kept by [WebServerNotifier] so the status bar and
/// Preferences can watch them without the server's internals.

abstract class _$WebClients extends $Notifier<List<WebClient>> {
  List<WebClient> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<WebClient>, List<WebClient>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<WebClient>, List<WebClient>>,
              List<WebClient>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
