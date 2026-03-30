import 'dart:io';
import 'dart:async';
import 'package:osc/osc.dart';
import 'package:flutter/foundation.dart';

/// Maps OSC address command segments to Panasonic NTCONTROL protocol commands.
const Map<String, String> _oscCommandMap = {
  // Power
  'power/on': 'PON',
  'power/off': 'POF',
  // Shutter
  'shutter/open': 'OSH:0',
  'shutter/close': 'OSH:1',
  // OSD
  'osd/on': 'OOS:1',
  'osd/off': 'OOS:0',
  // Input
  'input/hdmi1': 'IIS:HD1',
  'input/hdmi2': 'IIS:HD2',
  'input/sdi1': 'IIS:SD1',
  'input/sdi2': 'IIS:SD2',
  'input/digital-link': 'IIS:DL1',
  'input/dvi-d': 'IIS:DVI',
  'input/displayport': 'IIS:DP1',
  // Lens shift vertical (LNSI3): +SSSSSD — SSS=speed(200/100/000), D=direction(0=up,1=down)
  'lens/shift/up/slow': 'VXX:LNSI3=+00000',
  'lens/shift/up/normal': 'VXX:LNSI3=+00100',
  'lens/shift/up/fast': 'VXX:LNSI3=+00200',
  'lens/shift/down/slow': 'VXX:LNSI3=+00001',
  'lens/shift/down/normal': 'VXX:LNSI3=+00101',
  'lens/shift/down/fast': 'VXX:LNSI3=+00201',
  // Lens shift horizontal (LNSI2): D=0=right, D=1=left
  'lens/shift/left/slow': 'VXX:LNSI2=+00001',
  'lens/shift/left/normal': 'VXX:LNSI2=+00101',
  'lens/shift/left/fast': 'VXX:LNSI2=+00201',
  'lens/shift/right/slow': 'VXX:LNSI2=+00000',
  'lens/shift/right/normal': 'VXX:LNSI2=+00100',
  'lens/shift/right/fast': 'VXX:LNSI2=+00200',
  // Lens home & calibration
  'lens/home': 'VXX:LNSI1=+00001',
  'lens/calibration': 'VXX:LNSI0=+00001',
  // Focus (LNSI4): D=0=far/in, D=1=near/out
  'focus/near/slow': 'VXX:LNSI4=+00001',
  'focus/near/normal': 'VXX:LNSI4=+00101',
  'focus/near/fast': 'VXX:LNSI4=+00201',
  'focus/far/slow': 'VXX:LNSI4=+00000',
  'focus/far/normal': 'VXX:LNSI4=+00100',
  'focus/far/fast': 'VXX:LNSI4=+00200',
  // Zoom (LNSI5): D=0=in/tele, D=1=out/wide
  'zoom/in/slow': 'VXX:LNSI5=+00000',
  'zoom/in/normal': 'VXX:LNSI5=+00100',
  'zoom/in/fast': 'VXX:LNSI5=+00200',
  'zoom/out/slow': 'VXX:LNSI5=+00001',
  'zoom/out/normal': 'VXX:LNSI5=+00101',
  'zoom/out/fast': 'VXX:LNSI5=+00201',
  // Test patterns
  'testpattern/off': 'OTS:00',
  'testpattern/white': 'OTS:01',
  'testpattern/black': 'OTS:02',
  'testpattern/red': 'OTS:22',
  'testpattern/green': 'OTS:23',
  'testpattern/blue': 'OTS:24',
  'testpattern/cyan': 'OTS:28',
  'testpattern/magenta': 'OTS:29',
  'testpattern/yellow': 'OTS:30',
  'testpattern/window': 'OTS:05',
  'testpattern/reversed-window': 'OTS:06',
  'testpattern/color-bars-vertical': 'OTS:08',
  'testpattern/color-bars-horizontal': 'OTS:51',
  'testpattern/focus': 'OTS:78',
  'testpattern/aspect-frame': 'OTS:59',
  'testpattern/cross-hatch': 'OTS:07',
  'testpattern/cross-hatch-red': 'OTS:70',
  'testpattern/cross-hatch-green': 'OTS:71',
  'testpattern/cross-hatch-blue': 'OTS:72',
  'testpattern/cross-hatch-cyan': 'OTS:73',
  'testpattern/cross-hatch-magenta': 'OTS:74',
  'testpattern/cross-hatch-yellow': 'OTS:75',
  'testpattern/circle': 'OTS:87',
  // Picture mode
  'picture-mode/dynamic': 'VXX:PMDI0=+00001',
  'picture-mode/natural': 'VXX:PMDI0=+00002',
  'picture-mode/standard': 'VXX:PMDI0=+00003',
  'picture-mode/cinema': 'VXX:PMDI0=+00004',
  'picture-mode/graphic': 'VXX:PMDI0=+00006',
  'picture-mode/dicom-sim': 'VXX:PMDI0=+00007',
  'picture-mode/rec709': 'VXX:PMDI0=+00012',
  'picture-mode/user': 'VXX:PMDI0=+00014',
  // Back color
  'back-color/blue': 'OBC:0',
  'back-color/black': 'OBC:1',
  'back-color/user-logo': 'OBC:2',
  'back-color/default-logo': 'OBC:3',
  // Startup logo
  'startup-logo/off': 'MLO:0',
  'startup-logo/user-logo': 'MLO:1',
  'startup-logo/default-logo': 'MLO:2',
  // Projection method
  'projection/front-desk': 'OIL:0',
  'projection/rear-desk': 'OIL:1',
  'projection/front-ceiling': 'OIL:2',
  'projection/rear-ceiling': 'OIL:3',
  'projection/front-auto': 'OIL:4',
  'projection/rear-auto': 'OIL:5',
  // Shutter fade in (SEFS1) — float seconds
  'shutter-fade-in/0': 'VXX:SEFS1=0.0',
  'shutter-fade-in/0.5': 'VXX:SEFS1=0.5',
  'shutter-fade-in/1': 'VXX:SEFS1=1.0',
  'shutter-fade-in/1.5': 'VXX:SEFS1=1.5',
  'shutter-fade-in/2': 'VXX:SEFS1=2.0',
  'shutter-fade-in/3': 'VXX:SEFS1=3.0',
  'shutter-fade-in/5': 'VXX:SEFS1=5.0',
  'shutter-fade-in/7': 'VXX:SEFS1=7.0',
  'shutter-fade-in/10': 'VXX:SEFS1=10.0',
  // Shutter fade out (SEFS2)
  'shutter-fade-out/0': 'VXX:SEFS2=0.0',
  'shutter-fade-out/0.5': 'VXX:SEFS2=0.5',
  'shutter-fade-out/1': 'VXX:SEFS2=1.0',
  'shutter-fade-out/1.5': 'VXX:SEFS2=1.5',
  'shutter-fade-out/2': 'VXX:SEFS2=2.0',
  'shutter-fade-out/3': 'VXX:SEFS2=3.0',
  'shutter-fade-out/5': 'VXX:SEFS2=5.0',
  'shutter-fade-out/7': 'VXX:SEFS2=7.0',
  'shutter-fade-out/10': 'VXX:SEFS2=10.0',
  // Quad pixel drive
  'quad-pixel/on': 'VXX:QPDI1=+00001',
  'quad-pixel/off': 'VXX:QPDI1=+00000',
};

/// Callback type for dispatching resolved NTCONTROL commands.
typedef OscCommandCallback = Future<void> Function({
  required String ntcontrolCmd,
  String? groupId,
  bool all,
});

/// Callback type for collecting projector status counts.
typedef OscStatusCallback = ({int online, int offline, int warnings});

class OscService {
  RawDatagramSocket? _socket;
  bool _isActive = false;
  String _sendIp = '127.0.0.1';
  int _sendPort = 9000;

  // Previous counts — used to detect changes and skip redundant sends.
  int? _lastOnline;
  int? _lastOffline;
  int? _lastWarnings;

  /// Called when a valid OSC command is received and resolved.
  OscCommandCallback? onCommand;

  /// Called to get current projector status counts for outgoing messages.
  OscStatusCallback Function()? getStatus;

  /// Group OSC address → group ID resolver.
  String? Function(String oscAddress)? resolveGroupId;

  /// Custom command OSC slug → NTCONTROL command resolver.
  String? Function(String oscSlug)? resolveCustomCommand;

  bool get isActive => _isActive;

  Future<void> start({
    required String networkDevice,
    required int receivePort,
    required String sendIp,
    required int sendPort,
  }) async {
    await stop();
    _sendIp = sendIp;
    _sendPort = sendPort;
    _lastOnline = null;
    _lastOffline = null;
    _lastWarnings = null;

    try {
      final bindAddress = networkDevice.isEmpty
          ? InternetAddress.anyIPv4
          : InternetAddress(networkDevice);
      _socket = await RawDatagramSocket.bind(bindAddress, receivePort);
      _isActive = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) _handleDatagram(datagram);
        }
      });

      debugPrint('OSC: Listening on ${bindAddress.address}:$receivePort → sending to $_sendIp:$_sendPort');
    } catch (e) {
      debugPrint('OSC: Failed to start — $e');
      _isActive = false;
    }
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _isActive = false;
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final msg = OSCMessage.fromBytes(datagram.data);
      _processMessage(msg);
    } catch (e) {
      debugPrint('OSC: Failed to parse message — $e');
    }
  }

  void _processMessage(OSCMessage msg) {
    final address = msg.address;

    // /pgrid/all/{command...}
    // Also handles /pgrid/all/custom/{slug} for user-defined commands.
    if (address.startsWith('/pgrid/all/')) {
      final commandPath = address.substring('/pgrid/all/'.length);
      if (commandPath.startsWith('custom/')) {
        final slug = commandPath.substring('custom/'.length);
        final ntCmd = resolveCustomCommand?.call(slug);
        if (ntCmd != null && onCommand != null) {
          onCommand!(ntcontrolCmd: ntCmd, all: true);
        } else {
          debugPrint('OSC: Unknown custom command slug: $slug');
        }
      } else {
        final ntCmd = _oscCommandMap[commandPath];
        if (ntCmd != null && onCommand != null) {
          onCommand!(ntcontrolCmd: ntCmd, all: true);
        } else {
          debugPrint('OSC: Unknown command path: $commandPath');
        }
      }
      return;
    }

    // /pgrid/group/{group-name}/{command...}
    // Also handles /pgrid/group/{group-name}/custom/{slug} for user-defined commands.
    if (address.startsWith('/pgrid/group/')) {
      final remainder = address.substring('/pgrid/group/'.length);
      final firstSlash = remainder.indexOf('/');
      if (firstSlash == -1) {
        debugPrint('OSC: Missing command after group name: $address');
        return;
      }
      final groupName = remainder.substring(0, firstSlash);
      final commandPath = remainder.substring(firstSlash + 1);
      final groupOscAddress = '/group/$groupName';
      final groupId = resolveGroupId?.call(groupOscAddress);
      if (groupId == null) {
        debugPrint('OSC: No group found for address: $groupOscAddress');
        return;
      }
      if (commandPath.startsWith('custom/')) {
        final slug = commandPath.substring('custom/'.length);
        final ntCmd = resolveCustomCommand?.call(slug);
        if (ntCmd != null && onCommand != null) {
          onCommand!(ntcontrolCmd: ntCmd, groupId: groupId, all: false);
        } else {
          debugPrint('OSC: Unknown custom command slug: $slug');
        }
      } else {
        final ntCmd = _oscCommandMap[commandPath];
        if (ntCmd == null) {
          debugPrint('OSC: Unknown command path: $commandPath');
          return;
        }
        onCommand?.call(ntcontrolCmd: ntCmd, groupId: groupId, all: false);
      }
      return;
    }

    // /pgrid/status — request: send all 3 status messages immediately, bypass change detection.
    if (address == '/pgrid/status') {
      sendStatusForced();
      return;
    }

    debugPrint('OSC: Unrecognized address: $address');
  }

  /// Sends each status message only if its value has changed since last send.
  void sendStatusIfActive() {
    if (!_isActive || _socket == null || getStatus == null) return;

    final status = getStatus!();

    if (status.online != _lastOnline) {
      _sendMessage('/pgrid/status/online', status.online);
      _lastOnline = status.online;
    }
    if (status.offline != _lastOffline) {
      _sendMessage('/pgrid/status/offline', status.offline);
      _lastOffline = status.offline;
    }
    if (status.warnings != _lastWarnings) {
      _sendMessage('/pgrid/status/warning', status.warnings);
      _lastWarnings = status.warnings;
    }
  }

  /// Sends all 3 status messages unconditionally (used for on-demand /pgrid/status requests).
  void sendStatusForced() {
    if (!_isActive || _socket == null || getStatus == null) return;

    final status = getStatus!();
    _sendMessage('/pgrid/status/online', status.online);
    _sendMessage('/pgrid/status/offline', status.offline);
    _sendMessage('/pgrid/status/warning', status.warnings);
    _lastOnline = status.online;
    _lastOffline = status.offline;
    _lastWarnings = status.warnings;
  }

  void _sendMessage(String address, int value) {
    try {
      final msg = OSCMessage(address, arguments: [value]);
      _socket!.send(msg.toBytes(), InternetAddress(_sendIp), _sendPort);
    } catch (e) {
      debugPrint('OSC: Failed to send $address — $e');
    }
  }
}
