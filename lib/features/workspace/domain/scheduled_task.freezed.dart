// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduledTask {

 String get id; String get name; String get command; String get commandLabel; ScheduleTarget get target; String? get targetGroupId; ScheduleType get scheduleType; DateTime? get oneTimeAt; String? get timeOfDay; List<int>? get weekdays; bool get enabled; DateTime? get lastRunAt;
/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskCopyWith<ScheduledTask> get copyWith => _$ScheduledTaskCopyWithImpl<ScheduledTask>(this as ScheduledTask, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTask&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command)&&(identical(other.commandLabel, commandLabel) || other.commandLabel == commandLabel)&&(identical(other.target, target) || other.target == target)&&(identical(other.targetGroupId, targetGroupId) || other.targetGroupId == targetGroupId)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&(identical(other.oneTimeAt, oneTimeAt) || other.oneTimeAt == oneTimeAt)&&(identical(other.timeOfDay, timeOfDay) || other.timeOfDay == timeOfDay)&&const DeepCollectionEquality().equals(other.weekdays, weekdays)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.lastRunAt, lastRunAt) || other.lastRunAt == lastRunAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,command,commandLabel,target,targetGroupId,scheduleType,oneTimeAt,timeOfDay,const DeepCollectionEquality().hash(weekdays),enabled,lastRunAt);

@override
String toString() {
  return 'ScheduledTask(id: $id, name: $name, command: $command, commandLabel: $commandLabel, target: $target, targetGroupId: $targetGroupId, scheduleType: $scheduleType, oneTimeAt: $oneTimeAt, timeOfDay: $timeOfDay, weekdays: $weekdays, enabled: $enabled, lastRunAt: $lastRunAt)';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskCopyWith<$Res>  {
  factory $ScheduledTaskCopyWith(ScheduledTask value, $Res Function(ScheduledTask) _then) = _$ScheduledTaskCopyWithImpl;
@useResult
$Res call({
 String id, String name, String command, String commandLabel, ScheduleTarget target, String? targetGroupId, ScheduleType scheduleType, DateTime? oneTimeAt, String? timeOfDay, List<int>? weekdays, bool enabled, DateTime? lastRunAt
});




}
/// @nodoc
class _$ScheduledTaskCopyWithImpl<$Res>
    implements $ScheduledTaskCopyWith<$Res> {
  _$ScheduledTaskCopyWithImpl(this._self, this._then);

  final ScheduledTask _self;
  final $Res Function(ScheduledTask) _then;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? command = null,Object? commandLabel = null,Object? target = null,Object? targetGroupId = freezed,Object? scheduleType = null,Object? oneTimeAt = freezed,Object? timeOfDay = freezed,Object? weekdays = freezed,Object? enabled = null,Object? lastRunAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,commandLabel: null == commandLabel ? _self.commandLabel : commandLabel // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as ScheduleTarget,targetGroupId: freezed == targetGroupId ? _self.targetGroupId : targetGroupId // ignore: cast_nullable_to_non_nullable
as String?,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,oneTimeAt: freezed == oneTimeAt ? _self.oneTimeAt : oneTimeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timeOfDay: freezed == timeOfDay ? _self.timeOfDay : timeOfDay // ignore: cast_nullable_to_non_nullable
as String?,weekdays: freezed == weekdays ? _self.weekdays : weekdays // ignore: cast_nullable_to_non_nullable
as List<int>?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduledTask].
extension ScheduledTaskPatterns on ScheduledTask {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduledTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduledTask() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduledTask value)  $default,){
final _that = this;
switch (_that) {
case _ScheduledTask():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduledTask value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduledTask() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String command,  String commandLabel,  ScheduleTarget target,  String? targetGroupId,  ScheduleType scheduleType,  DateTime? oneTimeAt,  String? timeOfDay,  List<int>? weekdays,  bool enabled,  DateTime? lastRunAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduledTask() when $default != null:
return $default(_that.id,_that.name,_that.command,_that.commandLabel,_that.target,_that.targetGroupId,_that.scheduleType,_that.oneTimeAt,_that.timeOfDay,_that.weekdays,_that.enabled,_that.lastRunAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String command,  String commandLabel,  ScheduleTarget target,  String? targetGroupId,  ScheduleType scheduleType,  DateTime? oneTimeAt,  String? timeOfDay,  List<int>? weekdays,  bool enabled,  DateTime? lastRunAt)  $default,) {final _that = this;
switch (_that) {
case _ScheduledTask():
return $default(_that.id,_that.name,_that.command,_that.commandLabel,_that.target,_that.targetGroupId,_that.scheduleType,_that.oneTimeAt,_that.timeOfDay,_that.weekdays,_that.enabled,_that.lastRunAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String command,  String commandLabel,  ScheduleTarget target,  String? targetGroupId,  ScheduleType scheduleType,  DateTime? oneTimeAt,  String? timeOfDay,  List<int>? weekdays,  bool enabled,  DateTime? lastRunAt)?  $default,) {final _that = this;
switch (_that) {
case _ScheduledTask() when $default != null:
return $default(_that.id,_that.name,_that.command,_that.commandLabel,_that.target,_that.targetGroupId,_that.scheduleType,_that.oneTimeAt,_that.timeOfDay,_that.weekdays,_that.enabled,_that.lastRunAt);case _:
  return null;

}
}

}

/// @nodoc


class _ScheduledTask implements ScheduledTask {
  const _ScheduledTask({required this.id, required this.name, required this.command, required this.commandLabel, required this.target, this.targetGroupId, required this.scheduleType, this.oneTimeAt, this.timeOfDay, this.weekdays, this.enabled = true, this.lastRunAt});
  

@override final  String id;
@override final  String name;
@override final  String command;
@override final  String commandLabel;
@override final  ScheduleTarget target;
@override final  String? targetGroupId;
@override final  ScheduleType scheduleType;
@override final  DateTime? oneTimeAt;
@override final  String? timeOfDay;
@override final  List<int>? weekdays;
@override@JsonKey() final  bool enabled;
@override final  DateTime? lastRunAt;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskCopyWith<_ScheduledTask> get copyWith => __$ScheduledTaskCopyWithImpl<_ScheduledTask>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTask&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command)&&(identical(other.commandLabel, commandLabel) || other.commandLabel == commandLabel)&&(identical(other.target, target) || other.target == target)&&(identical(other.targetGroupId, targetGroupId) || other.targetGroupId == targetGroupId)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&(identical(other.oneTimeAt, oneTimeAt) || other.oneTimeAt == oneTimeAt)&&(identical(other.timeOfDay, timeOfDay) || other.timeOfDay == timeOfDay)&&const DeepCollectionEquality().equals(other.weekdays, weekdays)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.lastRunAt, lastRunAt) || other.lastRunAt == lastRunAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,command,commandLabel,target,targetGroupId,scheduleType,oneTimeAt,timeOfDay,const DeepCollectionEquality().hash(weekdays),enabled,lastRunAt);

@override
String toString() {
  return 'ScheduledTask(id: $id, name: $name, command: $command, commandLabel: $commandLabel, target: $target, targetGroupId: $targetGroupId, scheduleType: $scheduleType, oneTimeAt: $oneTimeAt, timeOfDay: $timeOfDay, weekdays: $weekdays, enabled: $enabled, lastRunAt: $lastRunAt)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskCopyWith<$Res> implements $ScheduledTaskCopyWith<$Res> {
  factory _$ScheduledTaskCopyWith(_ScheduledTask value, $Res Function(_ScheduledTask) _then) = __$ScheduledTaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String command, String commandLabel, ScheduleTarget target, String? targetGroupId, ScheduleType scheduleType, DateTime? oneTimeAt, String? timeOfDay, List<int>? weekdays, bool enabled, DateTime? lastRunAt
});




}
/// @nodoc
class __$ScheduledTaskCopyWithImpl<$Res>
    implements _$ScheduledTaskCopyWith<$Res> {
  __$ScheduledTaskCopyWithImpl(this._self, this._then);

  final _ScheduledTask _self;
  final $Res Function(_ScheduledTask) _then;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? command = null,Object? commandLabel = null,Object? target = null,Object? targetGroupId = freezed,Object? scheduleType = null,Object? oneTimeAt = freezed,Object? timeOfDay = freezed,Object? weekdays = freezed,Object? enabled = null,Object? lastRunAt = freezed,}) {
  return _then(_ScheduledTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,commandLabel: null == commandLabel ? _self.commandLabel : commandLabel // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as ScheduleTarget,targetGroupId: freezed == targetGroupId ? _self.targetGroupId : targetGroupId // ignore: cast_nullable_to_non_nullable
as String?,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,oneTimeAt: freezed == oneTimeAt ? _self.oneTimeAt : oneTimeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timeOfDay: freezed == timeOfDay ? _self.timeOfDay : timeOfDay // ignore: cast_nullable_to_non_nullable
as String?,weekdays: freezed == weekdays ? _self.weekdays : weekdays // ignore: cast_nullable_to_non_nullable
as List<int>?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
