// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_preview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live "RemoView" preview feed for one projector, keyed by its host (IP).
///
/// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
/// listen and is disposed — closing the socket — when the last widget stops
/// watching, so dismissing the preview dialog tears the feed down. Two
/// viewports on the same host (e.g. the menu and the table hit back to back)
/// share one socket. Deliberately shell-agnostic: no navigation or window
/// assumptions live here or in the controller, so the §5.3 migration to real
/// OS windows only swaps the widget wrapper.

@ProviderFor(RemotePreview)
final remotePreviewProvider = RemotePreviewFamily._();

/// Live "RemoView" preview feed for one projector, keyed by its host (IP).
///
/// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
/// listen and is disposed — closing the socket — when the last widget stops
/// watching, so dismissing the preview dialog tears the feed down. Two
/// viewports on the same host (e.g. the menu and the table hit back to back)
/// share one socket. Deliberately shell-agnostic: no navigation or window
/// assumptions live here or in the controller, so the §5.3 migration to real
/// OS windows only swaps the widget wrapper.
final class RemotePreviewProvider
    extends $NotifierProvider<RemotePreview, RemotePreviewState> {
  /// Live "RemoView" preview feed for one projector, keyed by its host (IP).
  ///
  /// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
  /// listen and is disposed — closing the socket — when the last widget stops
  /// watching, so dismissing the preview dialog tears the feed down. Two
  /// viewports on the same host (e.g. the menu and the table hit back to back)
  /// share one socket. Deliberately shell-agnostic: no navigation or window
  /// assumptions live here or in the controller, so the §5.3 migration to real
  /// OS windows only swaps the widget wrapper.
  RemotePreviewProvider._({
    required RemotePreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'remotePreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$remotePreviewHash();

  @override
  String toString() {
    return r'remotePreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RemotePreview create() => RemotePreview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemotePreviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemotePreviewState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RemotePreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$remotePreviewHash() => r'e8835a45a054a16df2ca6cc9b2a0332d3d2c91b4';

/// Live "RemoView" preview feed for one projector, keyed by its host (IP).
///
/// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
/// listen and is disposed — closing the socket — when the last widget stops
/// watching, so dismissing the preview dialog tears the feed down. Two
/// viewports on the same host (e.g. the menu and the table hit back to back)
/// share one socket. Deliberately shell-agnostic: no navigation or window
/// assumptions live here or in the controller, so the §5.3 migration to real
/// OS windows only swaps the widget wrapper.

final class RemotePreviewFamily extends $Family
    with
        $ClassFamilyOverride<
          RemotePreview,
          RemotePreviewState,
          RemotePreviewState,
          RemotePreviewState,
          String
        > {
  RemotePreviewFamily._()
    : super(
        retry: null,
        name: r'remotePreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live "RemoView" preview feed for one projector, keyed by its host (IP).
  ///
  /// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
  /// listen and is disposed — closing the socket — when the last widget stops
  /// watching, so dismissing the preview dialog tears the feed down. Two
  /// viewports on the same host (e.g. the menu and the table hit back to back)
  /// share one socket. Deliberately shell-agnostic: no navigation or window
  /// assumptions live here or in the controller, so the §5.3 migration to real
  /// OS windows only swaps the widget wrapper.

  RemotePreviewProvider call(String host) =>
      RemotePreviewProvider._(argument: host, from: this);

  @override
  String toString() => r'remotePreviewProvider';
}

/// Live "RemoView" preview feed for one projector, keyed by its host (IP).
///
/// Not `keepAlive`: [RemotePreviewController] opens its WebSocket on first
/// listen and is disposed — closing the socket — when the last widget stops
/// watching, so dismissing the preview dialog tears the feed down. Two
/// viewports on the same host (e.g. the menu and the table hit back to back)
/// share one socket. Deliberately shell-agnostic: no navigation or window
/// assumptions live here or in the controller, so the §5.3 migration to real
/// OS windows only swaps the widget wrapper.

abstract class _$RemotePreview extends $Notifier<RemotePreviewState> {
  late final _$args = ref.$arg as String;
  String get host => _$args;

  RemotePreviewState build(String host);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RemotePreviewState, RemotePreviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RemotePreviewState, RemotePreviewState>,
              RemotePreviewState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
