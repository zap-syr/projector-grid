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
