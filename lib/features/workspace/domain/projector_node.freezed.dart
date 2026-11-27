// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projector_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectorNode {

 String get id; String get name; String get ipAddress; int get port; String get login; String get password; double get x; double get y; PowerStatus get powerStatus; ShutterStatus get shutterStatus; ConnectionStatus get connectionStatus;/// A poll has tried this projector since it was loaded, added or
/// re-addressed. Until then `offline` only means "not asked yet", which
/// must not raise the Offline alert.
 bool get polled; String get serialNumber; String get runtime; String get lightRuntime; String get intakeTemp; String get exhaustTemp; String get acVoltage; String get errors; String get input; String get signal;/// Active test pattern as its `OTS:xx` command (`OTS:00` = off); null
/// until first polled.
 String? get testPattern;/// While offline: when the projector last answered a poll this session
/// (Monitoring's "last seen 16:41"); null while it answers, and when it
/// hasn't answered since the app started or it was re-addressed.
/// Telemetry, so an undo never rolls it back.
 DateTime? get lastSeen; String? get groupId;/// The app refuses lens motor commands (shift, focus, zoom, home,
/// calibration) to this projector; NTCONTROL has no such lock of its
/// own. Saved with the project, kept out of undo.
 bool get lensLocked;
/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectorNodeCopyWith<ProjectorNode> get copyWith => _$ProjectorNodeCopyWithImpl<ProjectorNode>(this as ProjectorNode, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProjectorNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectorNode&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.ipAddress, _this.ipAddress) || other.ipAddress == _this.ipAddress)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.login, _this.login) || other.login == _this.login)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.powerStatus, _this.powerStatus) || other.powerStatus == _this.powerStatus)&&(identical(other.shutterStatus, _this.shutterStatus) || other.shutterStatus == _this.shutterStatus)&&(identical(other.connectionStatus, _this.connectionStatus) || other.connectionStatus == _this.connectionStatus)&&(identical(other.polled, _this.polled) || other.polled == _this.polled)&&(identical(other.serialNumber, _this.serialNumber) || other.serialNumber == _this.serialNumber)&&(identical(other.runtime, _this.runtime) || other.runtime == _this.runtime)&&(identical(other.lightRuntime, _this.lightRuntime) || other.lightRuntime == _this.lightRuntime)&&(identical(other.intakeTemp, _this.intakeTemp) || other.intakeTemp == _this.intakeTemp)&&(identical(other.exhaustTemp, _this.exhaustTemp) || other.exhaustTemp == _this.exhaustTemp)&&(identical(other.acVoltage, _this.acVoltage) || other.acVoltage == _this.acVoltage)&&(identical(other.errors, _this.errors) || other.errors == _this.errors)&&(identical(other.input, _this.input) || other.input == _this.input)&&(identical(other.signal, _this.signal) || other.signal == _this.signal)&&(identical(other.testPattern, _this.testPattern) || other.testPattern == _this.testPattern)&&(identical(other.lastSeen, _this.lastSeen) || other.lastSeen == _this.lastSeen)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.lensLocked, _this.lensLocked) || other.lensLocked == _this.lensLocked));
}


@override
int get hashCode {
  final _this = this as ProjectorNode;
  return Object.hashAll([runtimeType,_this.id,_this.name,_this.ipAddress,_this.port,_this.login,_this.password,_this.x,_this.y,_this.powerStatus,_this.shutterStatus,_this.connectionStatus,_this.polled,_this.serialNumber,_this.runtime,_this.lightRuntime,_this.intakeTemp,_this.exhaustTemp,_this.acVoltage,_this.errors,_this.input,_this.signal,_this.testPattern,_this.lastSeen,_this.groupId,_this.lensLocked]);
}

@override
String toString() {
  final _this = this as ProjectorNode;
  return 'ProjectorNode(id: ${_this.id}, name: ${_this.name}, ipAddress: ${_this.ipAddress}, port: ${_this.port}, login: ${_this.login}, password: ${_this.password}, x: ${_this.x}, y: ${_this.y}, powerStatus: ${_this.powerStatus}, shutterStatus: ${_this.shutterStatus}, connectionStatus: ${_this.connectionStatus}, polled: ${_this.polled}, serialNumber: ${_this.serialNumber}, runtime: ${_this.runtime}, lightRuntime: ${_this.lightRuntime}, intakeTemp: ${_this.intakeTemp}, exhaustTemp: ${_this.exhaustTemp}, acVoltage: ${_this.acVoltage}, errors: ${_this.errors}, input: ${_this.input}, signal: ${_this.signal}, testPattern: ${_this.testPattern}, lastSeen: ${_this.lastSeen}, groupId: ${_this.groupId}, lensLocked: ${_this.lensLocked})';
}


}

/// @nodoc
abstract mixin class $ProjectorNodeCopyWith<$Res>  {
  factory $ProjectorNodeCopyWith(ProjectorNode value, $Res Function(ProjectorNode) _then) = _$ProjectorNodeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String ipAddress, int port, String login, String password, double x, double y, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus, bool polled, String serialNumber, String runtime, String lightRuntime, String intakeTemp, String exhaustTemp, String acVoltage, String errors, String input, String signal, String? testPattern, DateTime? lastSeen, String? groupId, bool lensLocked
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? port = null,Object? login = null,Object? password = null,Object? x = null,Object? y = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,Object? polled = null,Object? serialNumber = null,Object? runtime = null,Object? lightRuntime = null,Object? intakeTemp = null,Object? exhaustTemp = null,Object? acVoltage = null,Object? errors = null,Object? input = null,Object? signal = null,Object? testPattern = freezed,Object? lastSeen = freezed,Object? groupId = freezed,Object? lensLocked = null,}) {
  return _then(ProjectorNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,polled: null == polled ? _self.polled : polled // ignore: cast_nullable_to_non_nullable
as bool,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,lightRuntime: null == lightRuntime ? _self.lightRuntime : lightRuntime // ignore: cast_nullable_to_non_nullable
as String,intakeTemp: null == intakeTemp ? _self.intakeTemp : intakeTemp // ignore: cast_nullable_to_non_nullable
as String,exhaustTemp: null == exhaustTemp ? _self.exhaustTemp : exhaustTemp // ignore: cast_nullable_to_non_nullable
as String,acVoltage: null == acVoltage ? _self.acVoltage : acVoltage // ignore: cast_nullable_to_non_nullable
as String,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,signal: null == signal ? _self.signal : signal // ignore: cast_nullable_to_non_nullable
as String,testPattern: freezed == testPattern ? _self.testPattern : testPattern // ignore: cast_nullable_to_non_nullable
as String?,lastSeen: freezed == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,lensLocked: null == lensLocked ? _self.lensLocked : lensLocked // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  bool polled,  String serialNumber,  String runtime,  String lightRuntime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal,  String? testPattern,  DateTime? lastSeen,  String? groupId,  bool lensLocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.polled,_that.serialNumber,_that.runtime,_that.lightRuntime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal,_that.testPattern,_that.lastSeen,_that.groupId,_that.lensLocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  bool polled,  String serialNumber,  String runtime,  String lightRuntime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal,  String? testPattern,  DateTime? lastSeen,  String? groupId,  bool lensLocked)  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode():
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.polled,_that.serialNumber,_that.runtime,_that.lightRuntime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal,_that.testPattern,_that.lastSeen,_that.groupId,_that.lensLocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String ipAddress,  int port,  String login,  String password,  double x,  double y,  PowerStatus powerStatus,  ShutterStatus shutterStatus,  ConnectionStatus connectionStatus,  bool polled,  String serialNumber,  String runtime,  String lightRuntime,  String intakeTemp,  String exhaustTemp,  String acVoltage,  String errors,  String input,  String signal,  String? testPattern,  DateTime? lastSeen,  String? groupId,  bool lensLocked)?  $default,) {final _that = this;
switch (_that) {
case _ProjectorNode() when $default != null:
return $default(_that.id,_that.name,_that.ipAddress,_that.port,_that.login,_that.password,_that.x,_that.y,_that.powerStatus,_that.shutterStatus,_that.connectionStatus,_that.polled,_that.serialNumber,_that.runtime,_that.lightRuntime,_that.intakeTemp,_that.exhaustTemp,_that.acVoltage,_that.errors,_that.input,_that.signal,_that.testPattern,_that.lastSeen,_that.groupId,_that.lensLocked);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectorNode implements ProjectorNode {
  const _ProjectorNode({required this.id, required this.name, required this.ipAddress, this.port = 1024, this.login = 'admin1', this.password = 'panasonic', required this.x, required this.y, this.powerStatus = PowerStatus.standby, this.shutterStatus = ShutterStatus.closed, this.connectionStatus = ConnectionStatus.offline, this.polled = false, this.serialNumber = '-', this.runtime = '-', this.lightRuntime = '-', this.intakeTemp = '-', this.exhaustTemp = '-', this.acVoltage = '-', this.errors = '-', this.input = '-', this.signal = '-', this.testPattern, this.lastSeen, this.groupId, this.lensLocked = false});
  

@override final  String id;
@override final  String name;
@override final  String ipAddress;
@override@JsonKey() final  int port;
@override@JsonKey() final  String login;
@override@JsonKey() final  String password;
@override final  double x;
@override final  double y;
@override@JsonKey() final  PowerStatus powerStatus;
@override@JsonKey() final  ShutterStatus shutterStatus;
@override@JsonKey() final  ConnectionStatus connectionStatus;
/// A poll has tried this projector since it was loaded, added or
/// re-addressed. Until then `offline` only means "not asked yet", which
/// must not raise the Offline alert.
@override@JsonKey() final  bool polled;
@override@JsonKey() final  String serialNumber;
@override@JsonKey() final  String runtime;
@override@JsonKey() final  String lightRuntime;
@override@JsonKey() final  String intakeTemp;
@override@JsonKey() final  String exhaustTemp;
@override@JsonKey() final  String acVoltage;
@override@JsonKey() final  String errors;
@override@JsonKey() final  String input;
@override@JsonKey() final  String signal;
/// Active test pattern as its `OTS:xx` command (`OTS:00` = off); null
/// until first polled.
@override final  String? testPattern;
/// While offline: when the projector last answered a poll this session
/// (Monitoring's "last seen 16:41"); null while it answers, and when it
/// hasn't answered since the app started or it was re-addressed.
/// Telemetry, so an undo never rolls it back.
@override final  DateTime? lastSeen;
@override final  String? groupId;
/// The app refuses lens motor commands (shift, focus, zoom, home,
/// calibration) to this projector; NTCONTROL has no such lock of its
/// own. Saved with the project, kept out of undo.
@override@JsonKey() final  bool lensLocked;

/// Create a copy of ProjectorNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectorNodeCopyWith<_ProjectorNode> get copyWith => __$ProjectorNodeCopyWithImpl<_ProjectorNode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectorNode&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.port, port) || other.port == port)&&(identical(other.login, login) || other.login == login)&&(identical(other.password, password) || other.password == password)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.powerStatus, powerStatus) || other.powerStatus == powerStatus)&&(identical(other.shutterStatus, shutterStatus) || other.shutterStatus == shutterStatus)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus)&&(identical(other.polled, polled) || other.polled == polled)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.lightRuntime, lightRuntime) || other.lightRuntime == lightRuntime)&&(identical(other.intakeTemp, intakeTemp) || other.intakeTemp == intakeTemp)&&(identical(other.exhaustTemp, exhaustTemp) || other.exhaustTemp == exhaustTemp)&&(identical(other.acVoltage, acVoltage) || other.acVoltage == acVoltage)&&(identical(other.errors, errors) || other.errors == errors)&&(identical(other.input, input) || other.input == input)&&(identical(other.signal, signal) || other.signal == signal)&&(identical(other.testPattern, testPattern) || other.testPattern == testPattern)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.lensLocked, lensLocked) || other.lensLocked == lensLocked));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,name,ipAddress,port,login,password,x,y,powerStatus,shutterStatus,connectionStatus,polled,serialNumber,runtime,lightRuntime,intakeTemp,exhaustTemp,acVoltage,errors,input,signal,testPattern,lastSeen,groupId,lensLocked]);
}

@override
String toString() {
    return 'ProjectorNode(id: $id, name: $name, ipAddress: $ipAddress, port: $port, login: $login, password: $password, x: $x, y: $y, powerStatus: $powerStatus, shutterStatus: $shutterStatus, connectionStatus: $connectionStatus, polled: $polled, serialNumber: $serialNumber, runtime: $runtime, lightRuntime: $lightRuntime, intakeTemp: $intakeTemp, exhaustTemp: $exhaustTemp, acVoltage: $acVoltage, errors: $errors, input: $input, signal: $signal, testPattern: $testPattern, lastSeen: $lastSeen, groupId: $groupId, lensLocked: $lensLocked)';
}


}

/// @nodoc
abstract mixin class _$ProjectorNodeCopyWith<$Res> implements $ProjectorNodeCopyWith<$Res> {
  factory _$ProjectorNodeCopyWith(_ProjectorNode value, $Res Function(_ProjectorNode) _then) = __$ProjectorNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String ipAddress, int port, String login, String password, double x, double y, PowerStatus powerStatus, ShutterStatus shutterStatus, ConnectionStatus connectionStatus, bool polled, String serialNumber, String runtime, String lightRuntime, String intakeTemp, String exhaustTemp, String acVoltage, String errors, String input, String signal, String? testPattern, DateTime? lastSeen, String? groupId, bool lensLocked
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? ipAddress = null,Object? port = null,Object? login = null,Object? password = null,Object? x = null,Object? y = null,Object? powerStatus = null,Object? shutterStatus = null,Object? connectionStatus = null,Object? polled = null,Object? serialNumber = null,Object? runtime = null,Object? lightRuntime = null,Object? intakeTemp = null,Object? exhaustTemp = null,Object? acVoltage = null,Object? errors = null,Object? input = null,Object? signal = null,Object? testPattern = freezed,Object? lastSeen = freezed,Object? groupId = freezed,Object? lensLocked = null,}) {
  return _then(_ProjectorNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ipAddress: null == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,powerStatus: null == powerStatus ? _self.powerStatus : powerStatus // ignore: cast_nullable_to_non_nullable
as PowerStatus,shutterStatus: null == shutterStatus ? _self.shutterStatus : shutterStatus // ignore: cast_nullable_to_non_nullable
as ShutterStatus,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,polled: null == polled ? _self.polled : polled // ignore: cast_nullable_to_non_nullable
as bool,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as String,lightRuntime: null == lightRuntime ? _self.lightRuntime : lightRuntime // ignore: cast_nullable_to_non_nullable
as String,intakeTemp: null == intakeTemp ? _self.intakeTemp : intakeTemp // ignore: cast_nullable_to_non_nullable
as String,exhaustTemp: null == exhaustTemp ? _self.exhaustTemp : exhaustTemp // ignore: cast_nullable_to_non_nullable
as String,acVoltage: null == acVoltage ? _self.acVoltage : acVoltage // ignore: cast_nullable_to_non_nullable
as String,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,signal: null == signal ? _self.signal : signal // ignore: cast_nullable_to_non_nullable
as String,testPattern: freezed == testPattern ? _self.testPattern : testPattern // ignore: cast_nullable_to_non_nullable
as String?,lastSeen: freezed == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,lensLocked: null == lensLocked ? _self.lensLocked : lensLocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
