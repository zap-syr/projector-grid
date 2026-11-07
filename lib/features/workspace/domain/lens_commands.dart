/// NTCONTROL lens motor commands, shared by the control bar and the Web API
/// (`web_actions.dart`) so the two can't encode a step differently.
library;

/// `VXX:LNSI<code>`: the motor each lens step drives.
enum LensAxis {
  shiftH(2),
  shiftV(3),
  focus(4),
  zoom(5);

  const LensAxis(this.code);
  final int code;
}

/// The speed digit is the index: slow 0, normal 1, fast 2.
enum LensSpeed { slow, normal, fast }

/// One motor step: `VXX:LNSI<axis>=+00<speed>0<dir>`. [plus] = right / up /
/// far / in (direction digit 0); otherwise left / down / near / out (1).
String lensStepCommand(
  LensAxis axis, {
  required bool plus,
  required LensSpeed speed,
}) => 'VXX:LNSI${axis.code}=+00${speed.index}0${plus ? 0 : 1}';

const String kLensHomeCommand = 'VXX:LNSI1=+00001';

/// Commands that drive a lens motor: `VXX:LNSI` (steps, Home `LNSI1`,
/// calibration `LNSI0`, absolute position `LNSI7` to `LNSIA`), `VXX:LNSS`
/// (absolute position of several axes at once) and `VXX:LNMI1` (lens memory
/// load). Saving or deleting a lens memory (`LNMI2`, `LNMI3`) and lens type
/// (`VXX:LNEI`) move nothing and stay allowed on a locked projector.
const _lensMotionPrefixes = ['VXX:LNSI', 'VXX:LNSS', 'VXX:LNMI1'];

/// Whoever sends [cmd] (the control bar, OSC, the Web page, a schedule, a
/// custom command). Upper-cased first: a custom command is stored as typed.
bool isLensMotionCommand(String cmd) {
  final upper = cmd.toUpperCase();
  return _lensMotionPrefixes.any(upper.startsWith);
}

/// How much of a selection has its lens locked, for the lock button.
enum LensLockState { none, some, all }

/// [locked] holds one flag per selected projector; an empty selection
/// reads as [LensLockState.none].
LensLockState lensLockState(Iterable<bool> locked) {
  var any = false;
  var every = true;
  for (final l in locked) {
    any = any || l;
    every = every && l;
  }
  if (!any) return LensLockState.none;
  return every ? LensLockState.all : LensLockState.some;
}
