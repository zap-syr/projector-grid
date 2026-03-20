import 'package:freezed_annotation/freezed_annotation.dart';

part 'projector_group.freezed.dart';

@freezed
abstract class ProjectorGroup with _$ProjectorGroup {
  const factory ProjectorGroup({
    required String id,
    required String name,
    required int color,
    @Default('') String oscAddress,
  }) = _ProjectorGroup;
}
