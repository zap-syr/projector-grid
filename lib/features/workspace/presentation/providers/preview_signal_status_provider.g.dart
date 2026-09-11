// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preview_signal_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live input/signal for one projector's Remote Preview, driven by the
/// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
/// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
/// fully on (Standby, mid pre-show, still starting up), so the preview's
/// signal tag can't depend on them. This mirrors what the projector's own
/// `preview.cgi` does: it holds this value until the WebSocket sends a
/// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
/// may have opened onto an already-live signal), every `SIGNAL` event, and
/// every transition into a live frame (covers e.g. STARTINGUP → picture,
/// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
/// per *actual* signal change on this one projector, independent of frame
/// rate and of how many other tiles a multiview has open.

@ProviderFor(PreviewSignalStatus)
final previewSignalStatusProvider = PreviewSignalStatusFamily._();

/// Live input/signal for one projector's Remote Preview, driven by the
/// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
/// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
/// fully on (Standby, mid pre-show, still starting up), so the preview's
/// signal tag can't depend on them. This mirrors what the projector's own
/// `preview.cgi` does: it holds this value until the WebSocket sends a
/// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
/// may have opened onto an already-live signal), every `SIGNAL` event, and
/// every transition into a live frame (covers e.g. STARTINGUP → picture,
/// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
/// per *actual* signal change on this one projector, independent of frame
/// rate and of how many other tiles a multiview has open.
final class PreviewSignalStatusProvider
    extends $NotifierProvider<PreviewSignalStatus, WebSignalStatus?> {
  /// Live input/signal for one projector's Remote Preview, driven by the
  /// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
  /// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
  /// fully on (Standby, mid pre-show, still starting up), so the preview's
  /// signal tag can't depend on them. This mirrors what the projector's own
  /// `preview.cgi` does: it holds this value until the WebSocket sends a
  /// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
  /// may have opened onto an already-live signal), every `SIGNAL` event, and
  /// every transition into a live frame (covers e.g. STARTINGUP → picture,
  /// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
  /// per *actual* signal change on this one projector, independent of frame
  /// rate and of how many other tiles a multiview has open.
  PreviewSignalStatusProvider._({
    required PreviewSignalStatusFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'previewSignalStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$previewSignalStatusHash();

  @override
  String toString() {
    return r'previewSignalStatusProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  PreviewSignalStatus create() => PreviewSignalStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebSignalStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebSignalStatus?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewSignalStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$previewSignalStatusHash() =>
    r'cd995dacfb420f642ec137d2e218d7ce6c65f771';

/// Live input/signal for one projector's Remote Preview, driven by the
/// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
/// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
/// fully on (Standby, mid pre-show, still starting up), so the preview's
/// signal tag can't depend on them. This mirrors what the projector's own
/// `preview.cgi` does: it holds this value until the WebSocket sends a
/// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
/// may have opened onto an already-live signal), every `SIGNAL` event, and
/// every transition into a live frame (covers e.g. STARTINGUP → picture,
/// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
/// per *actual* signal change on this one projector, independent of frame
/// rate and of how many other tiles a multiview has open.

final class PreviewSignalStatusFamily extends $Family
    with
        $ClassFamilyOverride<
          PreviewSignalStatus,
          WebSignalStatus?,
          WebSignalStatus?,
          WebSignalStatus?,
          (String, String, String)
        > {
  PreviewSignalStatusFamily._()
    : super(
        retry: null,
        name: r'previewSignalStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live input/signal for one projector's Remote Preview, driven by the
  /// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
  /// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
  /// fully on (Standby, mid pre-show, still starting up), so the preview's
  /// signal tag can't depend on them. This mirrors what the projector's own
  /// `preview.cgi` does: it holds this value until the WebSocket sends a
  /// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
  /// may have opened onto an already-live signal), every `SIGNAL` event, and
  /// every transition into a live frame (covers e.g. STARTINGUP → picture,
  /// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
  /// per *actual* signal change on this one projector, independent of frame
  /// rate and of how many other tiles a multiview has open.

  PreviewSignalStatusProvider call(
    String host,
    String login,
    String password,
  ) => PreviewSignalStatusProvider._(
    argument: (host, login, password),
    from: this,
  );

  @override
  String toString() => r'previewSignalStatusProvider';
}

/// Live input/signal for one projector's Remote Preview, driven by the
/// projector's web UI (`/cgi-bin/simple_status_hidden.cgi`) instead of
/// NTCONTROL — `QIN` / `QVX:NSGS1` return `ER401` whenever the projector isn't
/// fully on (Standby, mid pre-show, still starting up), so the preview's
/// signal tag can't depend on them. This mirrors what the projector's own
/// `preview.cgi` does: it holds this value until the WebSocket sends a
/// `SIGNAL` message, then re-fetches. Refreshed on: first build (the dialog
/// may have opened onto an already-live signal), every `SIGNAL` event, and
/// every transition into a live frame (covers e.g. STARTINGUP → picture,
/// belt-and-braces alongside SIGNAL). No polling — cost is one HTTP request
/// per *actual* signal change on this one projector, independent of frame
/// rate and of how many other tiles a multiview has open.

abstract class _$PreviewSignalStatus extends $Notifier<WebSignalStatus?> {
  late final _$args = ref.$arg as (String, String, String);
  String get host => _$args.$1;
  String get login => _$args.$2;
  String get password => _$args.$3;

  WebSignalStatus? build(String host, String login, String password);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<WebSignalStatus?, WebSignalStatus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WebSignalStatus?, WebSignalStatus?>,
              WebSignalStatus?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args.$1, _$args.$2, _$args.$3));
  }
}
