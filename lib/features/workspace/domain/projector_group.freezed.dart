// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projector_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectorGroup {

 String get id; String get name; int get color; String get oscAddress;
/// Create a copy of ProjectorGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectorGroupCopyWith<ProjectorGroup> get copyWith => _$ProjectorGroupCopyWithImpl<ProjectorGroup>(this as ProjectorGroup, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectorGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.oscAddress, oscAddress) || other.oscAddress == oscAddress));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,color,oscAddress);

@override
String toString() {
  return 'ProjectorGroup(id: $id, name: $name, color: $color, oscAddress: $oscAddress)';
}


}

/// @nodoc
abstract mixin class $ProjectorGroupCopyWith<$Res>  {
  factory $ProjectorGroupCopyWith(ProjectorGroup value, $Res Function(ProjectorGroup) _then) = _$ProjectorGroupCopyWithImpl;
@useResult
$Res call({
 String id, String name, int color, String oscAddress
});




}
/// @nodoc
class _$ProjectorGroupCopyWithImpl<$Res>
    implements $ProjectorGroupCopyWith<$Res> {
  _$ProjectorGroupCopyWithImpl(this._self, this._then);

  final ProjectorGroup _self;
  final $Res Function(ProjectorGroup) _then;

/// Create a copy of ProjectorGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? oscAddress = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,oscAddress: null == oscAddress ? _self.oscAddress : oscAddress // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectorGroup].
extension ProjectorGroupPatterns on ProjectorGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectorGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectorGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectorGroup value)  $default,){
final _that = this;
switch (_that) {
case _ProjectorGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectorGroup value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectorGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int color,  String oscAddress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectorGroup() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.oscAddress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int color,  String oscAddress)  $default,) {final _that = this;
switch (_that) {
case _ProjectorGroup():
return $default(_that.id,_that.name,_that.color,_that.oscAddress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int color,  String oscAddress)?  $default,) {final _that = this;
switch (_that) {
case _ProjectorGroup() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.oscAddress);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectorGroup implements ProjectorGroup {
  const _ProjectorGroup({required this.id, required this.name, required this.color, this.oscAddress = ''});
  

@override final  String id;
@override final  String name;
@override final  int color;
@override@JsonKey() final  String oscAddress;

/// Create a copy of ProjectorGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectorGroupCopyWith<_ProjectorGroup> get copyWith => __$ProjectorGroupCopyWithImpl<_ProjectorGroup>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectorGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.oscAddress, oscAddress) || other.oscAddress == oscAddress));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,color,oscAddress);

@override
String toString() {
  return 'ProjectorGroup(id: $id, name: $name, color: $color, oscAddress: $oscAddress)';
}


}

/// @nodoc
abstract mixin class _$ProjectorGroupCopyWith<$Res> implements $ProjectorGroupCopyWith<$Res> {
  factory _$ProjectorGroupCopyWith(_ProjectorGroup value, $Res Function(_ProjectorGroup) _then) = __$ProjectorGroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int color, String oscAddress
});




}
/// @nodoc
class __$ProjectorGroupCopyWithImpl<$Res>
    implements _$ProjectorGroupCopyWith<$Res> {
  __$ProjectorGroupCopyWithImpl(this._self, this._then);

  final _ProjectorGroup _self;
  final $Res Function(_ProjectorGroup) _then;

/// Create a copy of ProjectorGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? oscAddress = null,}) {
  return _then(_ProjectorGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,oscAddress: null == oscAddress ? _self.oscAddress : oscAddress // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
