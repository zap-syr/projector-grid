// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projector_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectorNode {

 String get id; String get name; String get ipAddress; double get x; double get y; bool get isSelected; PowerStatus get powerStatus; ShutterStatus get shutterStatus; ConnectionStatus get connectionStatus;
/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectorNodeCopyWith<ProjectorNode> get copyWith => _$ProjectorNodeCopyWithImpl<ProjectorNode>(this as ProjectorNode, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectorNode&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.powerStatus, powerStatus) || other.powerStatus == powerStatus)&&(identical(other.shutterStatus, shutterStatus) || other.shutterStatus == shutterStatus)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,ipAddress,x,y,isSelected,powerStatus,shutterStatus,connectionStatus);

@override
String toString() {
  return 'ProjectorNode(id: $id, name: $name, ipAddress: $ipAddress, x: $x, y: $y, isSelected: $isSelected, powerStatus: $powerStatus, shutterStatus: $shutterStatus, connectionStatus: $connectionStatus)';
}


}

/// @nodoc
abstract mixin class $ProjectorNodeCopyWith<$Res>  {
  factory $ProjectorNodeCopyWith(ProjectorNode value, $Res Function(ProjectorNode) _then) = _$ProjectorNodeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String ipAddress, double x, double y, bool isSelected, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus
});




}
/// @nodoc
class _$ProjectorNodeCopyWithImpl<$Res>
    implements $ProjectorNodeCopyWith<$Res> {
  _$ProjectorNodeCopyWithImpl(this._self, this._then);

  final ProjectorNode _self;
  final $Res Function(ProjectorNode) _then;

/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? x = null,Object? y = null,Object? isSelected = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectorNode].
extension ProjectorNodePatterns on ProjectorNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectorNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectorNode value)  $default,){
final _that = this;
switch (_that) {
case _ProjectorNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectorNode value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus)  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode():
return $default(_that.id,_that.name,_that.ipAddress,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String ipAddress,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus)?  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectorNode implements ProjectorNode {
  const _ProjectorNode({required this.id, required this.name, required this.ipAddress, required this.x, required this.y, this.isSelected = false, this.powerStatus = PowerStatus.standby, this.shutterStatus = ShutterStatus.closed, this.connectionStatus = ConnectionStatus.offline});
  

@override final  String id;
@override final  String name;
@override final  String ipAddress;
@override final  double x;
@override final  double y;
@override@JsonKey() final  bool isSelected;
@override@JsonKey() final  PowerStatus powerStatus;
@override@JsonKey() final  ShutterStatus shutterStatus;
@override@JsonKey() final  ConnectionStatus connectionStatus;

/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectorNodeCopyWith<_ProjectorNode> get copyWith => __$ProjectorNodeCopyWithImpl<_ProjectorNode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectorNode&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.powerStatus, powerStatus) || other.powerStatus == powerStatus)&&(identical(other.shutterStatus, shutterStatus) || other.shutterStatus == shutterStatus)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,ipAddress,x,y,isSelected,powerStatus,shutterStatus,connectionStatus);

@override
String toString() {
  return 'ProjectorNode(id: $id, name: $name, ipAddress: $ipAddress, x: $x, y: $y, isSelected: $isSelected, powerStatus: $powerStatus, shutterStatus: $shutterStatus, connectionStatus: $connectionStatus)';
}


}

/// @nodoc
abstract mixin class _$ProjectorNodeCopyWith<$Res> implements $ProjectorNodeCopyWith<$Res> {
  factory _$ProjectorNodeCopyWith(_ProjectorNode value, $Res Function(_ProjectorNode) _then) = __$ProjectorNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String ipAddress, double x, double y, bool isSelected, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus
});




}
/// @nodoc
class __$ProjectorNodeCopyWithImpl<$Res>
    implements _$ProjectorNodeCopyWith<$Res> {
  __$ProjectorNodeCopyWithImpl(this._self, this._then);

  final _ProjectorNode _self;
  final $Res Function(_ProjectorNode) _then;

/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? x = null,Object? y = null,Object? isSelected = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,}) {
  return _then(_ProjectorNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,
  ));
}


}

// dart format on
