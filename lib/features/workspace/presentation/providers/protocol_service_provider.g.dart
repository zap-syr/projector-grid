// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The NTCONTROL client shared by the workspace. A provider rather than a
/// field so tests can override it with a fake that never opens a socket.

@ProviderFor(protocolService)
final protocolServiceProvider = ProtocolServiceProvider._();

/// The NTCONTROL client shared by the workspace. A provider rather than a
/// field so tests can override it with a fake that never opens a socket.

final class ProtocolServiceProvider
    extends
        $FunctionalProvider<
          PanasonicProtocolService,
          PanasonicProtocolService,
          PanasonicProtocolService
        >
    with $Provider<PanasonicProtocolService> {
  /// The NTCONTROL client shared by the workspace. A provider rather than a
  /// field so tests can override it with a fake that never opens a socket.
  ProtocolServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'protocolServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$protocolServiceHash();

  @$internal
  @override
  $ProviderElement<PanasonicProtocolService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PanasonicProtocolService create(Ref ref) {
    return protocolService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PanasonicProtocolService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PanasonicProtocolService>(value),
    );
  }
}

String _$protocolServiceHash() => r'2b1d738c1787acda1bc788d22dee2ebb1df626d7';
