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

 String get id; String get name; String get ipAddress; int get port; String get login; String get password; double get x; double get y; bool get isSelected; PowerStatus get powerStatus; ShutterStatus get shutterStatus; ConnectionStatus get connectionStatus; String get serialNumber; String get runtime; String get intakeTemp; String get exhaustTemp; String get acVoltage; String get errors; String get input; String get signal;
/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectorNodeCopyWith<ProjectorNode> get copyWith => _$ProjectorNodeCopyWithImpl<ProjectorNode>(this as ProjectorNode, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectorNode&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.port, port) || other.port == port)&&(identical(other.login, login) || other.login == login)&&(identical(other.password, password) || other.password == password)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.powerStatus, powerStatus) || other.powerStatus == powerStatus)&&(identical(other.shutterStatus, shutterStatus) || other.shutterStatus == shutterStatus)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.intakeTemp, intakeTemp) || other.intakeTemp == intakeTemp)&&(identical(other.exhaustTemp, exhaustTemp) || other.exhaustTemp == exhaustTemp)&&(identical(other.acVoltage, acVoltage) || other.acVoltage == acVoltage)&&(identical(other.errors, errors) || other.errors == errors)&&(identical(other.input, input) || other.input == input)&&(identical(other.signal, signal) || other.signal == signal));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,ipAddress,port,login,password,x,y,isSelected,powerStatus,shutterStatus,connectionStatus,serialNumber,runtime,intakeTemp,exhaustTemp,acVoltage,errors,input,signal]);

@override
String toString() {
  return 'ProjectorNode(id: $id, name: $name, ipAddress: $ipAddress, port: $port, login: $login, password: $password, x: $x, y: $y, isSelected: $isSelected, powerStatus: $powerStatus, shutterStatus: $shutterStatus, connectionStatus: $connectionStatus, serialNumber: $serialNumber, runtime: $runtime, intakeTemp: $intakeTemp, exhaustTemp: $exhaustTemp, acVoltage: $acVoltage, errors: $errors, input: $input, signal: $signal)';
}


}

/// @nodoc
abstract mixin class $ProjectorNodeCopyWith<$Res>  {
  factory $ProjectorNodeCopyWith(ProjectorNode value, $Res Function(ProjectorNode) _then) = _$ProjectorNodeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String ipAddress, int port, String login, String password, double x, double y, bool isSelected, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus, String serialNumber, String runtime, String intakeTemp, String exhaustTemp, String acVoltage, String errors, String input, String signal
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? port = null,Object? login = null,Object? password = null,Object? x = null,Object? y = null,Object? isSelected = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,Object? serialNumber = null,Object? runtime = null,Object? intakeTemp = null,Object? exhaustTemp = null,Object? acVoltage = null,Object? errors = null,Object? input = null,Object? signal = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,intakeTemp: null == intakeTemp ? _self.intakeTemp : intakeTemp // ignore: cast_nullable_to_non_nullable
as String,exhaustTemp: null == exhaustTemp ? _self.exhaustTemp : exhaustTemp // ignore: cast_nullable_to_non_nullable
as String,acVoltage: null == acVoltage ? _self.acVoltage : acVoltage // ignore: cast_nullable_to_non_nullable
as String,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,signal: null == signal ? _self.signal : signal // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  String serialNumber,  String runtime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.serialNumber,_that.runtime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  String serialNumber,  String runtime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal)  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode():
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.serialNumber,_that.runtime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  bool isSelected,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  String serialNumber,  String runtime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal)?  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.isSelected,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.serialNumber,_that.runtime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectorNode implements ProjectorNode {
  const _ProjectorNode({required this.id, required this.name, required this.ipAddress, this.port = 1024, this.login = 'admin1', this.password = 'panasonic', required this.x, required this.y, this.isSelected = false, this.powerStatus = PowerStatus.standby, this.shutterStatus = ShutterStatus.closed, this.connectionStatus = ConnectionStatus.offline, this.serialNumber = '-', this.runtime = '-', this.intakeTemp = '-', this.exhaustTemp = '-', this.acVoltage = '-', this.errors = '-', this.input = '-', this.signal = '-'});
  

@override final  String id;
@override final  String name;
@override final  String ipAddress;
@override@JsonKey() final  int port;
@override@JsonKey() final  String login;
@override@JsonKey() final  String password;
@override final  double x;
@override final  double y;
@override@JsonKey() final  bool isSelected;
@override@JsonKey() final  PowerStatus powerStatus;
@override@JsonKey() final  ShutterStatus shutterStatus;
@override@JsonKey() final  ConnectionStatus connectionStatus;
@override@JsonKey() final  String serialNumber;
@override@JsonKey() final  String runtime;
@override@JsonKey() final  String intakeTemp;
@override@JsonKey() final  String exhaustTemp;
@override@JsonKey() final  String acVoltage;
@override@JsonKey() final  String errors;
@override@JsonKey() final  String input;
@override@JsonKey() final  String signal;

/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectorNodeCopyWith<_ProjectorNode> get copyWith => __$ProjectorNodeCopyWithImpl<_ProjectorNode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectorNode&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.port, port) || other.port == port)&&(identical(other.login, login) || other.login == login)&&(identical(other.password, password) || other.password == password)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.powerStatus, powerStatus) || other.powerStatus == powerStatus)&&(identical(other.shutterStatus, shutterStatus) || other.shutterStatus == shutterStatus)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.intakeTemp, intakeTemp) || other.intakeTemp == intakeTemp)&&(identical(other.exhaustTemp, exhaustTemp) || other.exhaustTemp == exhaustTemp)&&(identical(other.acVoltage, acVoltage) || other.acVoltage == acVoltage)&&(identical(other.errors, errors) || other.errors == errors)&&(identical(other.input, input) || other.input == input)&&(identical(other.signal, signal) || other.signal == signal));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,ipAddress,port,login,password,x,y,isSelected,powerStatus,shutterStatus,connectionStatus,serialNumber,runtime,intakeTemp,exhaustTemp,acVoltage,errors,input,signal]);

@override
String toString() {
  return 'ProjectorNode(id: $id, name: $name, ipAddress: $ipAddress, port: $port, login: $login, password: $password, x: $x, y: $y, isSelected: $isSelected, powerStatus: $powerStatus, shutterStatus: $shutterStatus, connectionStatus: $connectionStatus, serialNumber: $serialNumber, runtime: $runtime, intakeTemp: $intakeTemp, exhaustTemp: $exhaustTemp, acVoltage: $acVoltage, errors: $errors, input: $input, signal: $signal)';
}


}

/// @nodoc
abstract mixin class _$ProjectorNodeCopyWith<$Res> implements $ProjectorNodeCopyWith<$Res> {
  factory _$ProjectorNodeCopyWith(_ProjectorNode value, $Res Function(_ProjectorNode) _then) = __$ProjectorNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String ipAddress, int port, String login, String password, double x, double y, bool isSelected, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus, String serialNumber, String runtime, String intakeTemp, String exhaustTemp, String acVoltage, String errors, String input, String signal
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? port = null,Object? login = null,Object? password = null,Object? x = null,Object? y = null,Object? isSelected = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,Object? serialNumber = null,Object? runtime = null,Object? intakeTemp = null,Object? exhaustTemp = null,Object? acVoltage = null,Object? errors = null,Object? input = null,Object? signal = null,}) {
  return _then(_ProjectorNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,intakeTemp: null == intakeTemp ? _self.intakeTemp : intakeTemp // ignore: cast_nullable_to_non_nullable
as String,exhaustTemp: null == exhaustTemp ? _self.exhaustTemp : exhaustTemp // ignore: cast_nullable_to_non_nullable
as String,acVoltage: null == acVoltage ? _self.acVoltage : acVoltage // ignore: cast_nullable_to_non_nullable
as String,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,signal: null == signal ? _self.signal : signal // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
