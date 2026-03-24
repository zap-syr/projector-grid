// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_commands_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CustomCommandsNotifier)
final customCommandsProvider = CustomCommandsNotifierProvider._();

final class CustomCommandsNotifierProvider
    extends $NotifierProvider<CustomCommandsNotifier, List<CustomCommand>> {
  CustomCommandsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customCommandsNotifierHash();

  @$internal
  @override
  CustomCommandsNotifier create() => CustomCommandsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CustomCommand> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<CustomCommand>>(value),
    );
  }
}

String _$customCommandsNotifierHash() =>
    r'0952cead3d3c7d34594e050f9f36863f4b223687';

abstract class _$CustomCommandsNotifier extends $Notifier<List<CustomCommand>> {
  List<CustomCommand> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<CustomCommand>, List<CustomCommand>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<CustomCommand>, List<CustomCommand>>,
              List<CustomCommand>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
