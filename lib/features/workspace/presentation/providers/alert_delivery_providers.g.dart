// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_delivery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The services alerts reach the operator through, as providers so tests
/// can override them with fakes that show and play nothing.

@ProviderFor(desktopNotificationService)
final desktopNotificationServiceProvider =
    DesktopNotificationServiceProvider._();

/// The services alerts reach the operator through, as providers so tests
/// can override them with fakes that show and play nothing.

final class DesktopNotificationServiceProvider
    extends
        $FunctionalProvider<
          DesktopNotificationService,
          DesktopNotificationService,
          DesktopNotificationService
        >
    with $Provider<DesktopNotificationService> {
  /// The services alerts reach the operator through, as providers so tests
  /// can override them with fakes that show and play nothing.
  DesktopNotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'desktopNotificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$desktopNotificationServiceHash();

  @$internal
  @override
  $ProviderElement<DesktopNotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DesktopNotificationService create(Ref ref) {
    return desktopNotificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DesktopNotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DesktopNotificationService>(value),
    );
  }
}

String _$desktopNotificationServiceHash() =>
    r'38fe8d3a478023b664be3c54fffb8a66c1c148b0';

@ProviderFor(alertSoundService)
final alertSoundServiceProvider = AlertSoundServiceProvider._();

final class AlertSoundServiceProvider
    extends
        $FunctionalProvider<
          AlertSoundService,
          AlertSoundService,
          AlertSoundService
        >
    with $Provider<AlertSoundService> {
  AlertSoundServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alertSoundServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alertSoundServiceHash();

  @$internal
  @override
  $ProviderElement<AlertSoundService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AlertSoundService create(Ref ref) {
    return alertSoundService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlertSoundService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlertSoundService>(value),
    );
  }
}

String _$alertSoundServiceHash() => r'8aa252f1fa7df59cfca61b5b2ef4c71187116e04';
