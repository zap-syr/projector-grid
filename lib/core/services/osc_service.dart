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
  // Lens
  'lens/shift/up/slow': 'VXX:LNSI1=+00020',
  'lens/shift/up/normal': 'VXX:LNSI1=+00100',
  'lens/shift/up/fast': 'VXX:LNSI1=+00400',
  'lens/shift/down/slow': 'VXX:LNSI1=-00020',
  'lens/shift/down/normal': 'VXX:LNSI1=-00100',
  'lens/shift/down/fast': 'VXX:LNSI1=-00400',
  'lens/shift/left/slow': 'VXX:LNSI2=-00020',
  'lens/shift/left/normal': 'VXX:LNSI2=-00100',
  'lens/shift/left/fast': 'VXX:LNSI2=-00400',
  'lens/shift/right/slow': 'VXX:LNSI2=+00020',
  'lens/shift/right/normal': 'VXX:LNSI2=+00100',
  'lens/shift/right/fast': 'VXX:LNSI2=+00400',
  'lens/home': 'VXX:LNSI3=+00001',
  'lens/calibration': 'VXX:LNSI4=+00001',
  'lens/type': 'VXX:LNSI5=+00001',
  // Focus
  'focus/near/slow': 'VXX:LNSI6=-00020',
  'focus/near/normal': 'VXX:LNSI6=-00100',
  'focus/near/fast': 'VXX:LNSI6=-00400',
  'focus/far/slow': 'VXX:LNSI6=+00020',
  'focus/far/normal': 'VXX:LNSI6=+00100',
  'focus/far/fast': 'VXX:LNSI6=+00400',
  // Zoom
  'zoom/in/slow': 'VXX:LNSI7=+00020',
  'zoom/in/normal': 'VXX:LNSI7=+00100',
  'zoom/in/fast': 'VXX:LNSI7=+00400',
  'zoom/out/slow': 'VXX:LNSI7=-00020',
  'zoom/out/normal': 'VXX:LNSI7=-00100',
  'zoom/out/fast': 'VXX:LNSI7=-00400',
  // Test Pattern
  'testpattern/off': 'OTP:00',
  'testpattern/white': 'OTP:01',
  'testpattern/black': 'OTP:03',
  'testpattern/red': 'OTP:11',
  'testpattern/green': 'OTP:12',
  'testpattern/blue': 'OTP:13',
  'testpattern/cross-hatch': 'OTP:21',
  'testpattern/color-bars': 'OTP:41',
  'testpattern/staircase-white': 'OTP:51',
  'testpattern/staircase-red': 'OTP:52',
  'testpattern/staircase-green': 'OTP:53',
  'testpattern/staircase-blue': 'OTP:54',
  'testpattern/focus': 'OTP:61',
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
  'back-color/blue': 'OBK:0',
  'back-color/black': 'OBK:1',
  'back-color/logo': 'OBK:3',
  // Startup logo
  'startup-logo/on': 'VXX:LOSU0=+00001',
  'startup-logo/off': 'VXX:LOSU0=+00000',
  // Projection
  'projection/front-desk': 'OPJ:0',
  'projection/front-ceiling': 'OPJ:1',
  'projection/rear-desk': 'OPJ:2',
  'projection/rear-ceiling': 'OPJ:3',
  // Shutter fade
  'shutter-fade-in/0': 'VXX:FDIN0=+00000',
  'shutter-fade-in/0.5': 'VXX:FDIN0=+00001',
  'shutter-fade-in/1': 'VXX:FDIN0=+00002',
  'shutter-fade-in/1.5': 'VXX:FDIN0=+00003',
  'shutter-fade-in/2': 'VXX:FDIN0=+00004',
  'shutter-fade-in/3': 'VXX:FDIN0=+00005',
  'shutter-fade-in/5': 'VXX:FDIN0=+00006',
  'shutter-fade-in/7': 'VXX:FDIN0=+00007',
  'shutter-fade-in/10': 'VXX:FDIN0=+00008',
  'shutter-fade-out/0': 'VXX:FDOU0=+00000',
  'shutter-fade-out/0.5': 'VXX:FDOU0=+00001',
  'shutter-fade-out/1': 'VXX:FDOU0=+00002',
  'shutter-fade-out/1.5': 'VXX:FDOU0=+00003',
  'shutter-fade-out/2': 'VXX:FDOU0=+00004',
  'shutter-fade-out/3': 'VXX:FDOU0=+00005',
  'shutter-fade-out/5': 'VXX:FDOU0=+00006',
  'shutter-fade-out/7': 'VXX:FDOU0=+00007',
  'shutter-fade-out/10': 'VXX:FDOU0=+00008',
  // Quad pixel drive
  'quad-pixel/on': 'VXX:QDRD0=+00001',
  'quad-pixel/off': 'VXX:QDRD0=+00000',
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

    // /pprjm/all/{command...}
    if (address.startsWith('/pprjm/all/')) {
      final commandPath = address.substring('/pprjm/all/'.length);
      final ntCmd = _oscCommandMap[commandPath];
      if (ntCmd != null && onCommand != null) {
        onCommand!(ntcontrolCmd: ntCmd, all: true);
      } else {
        debugPrint('OSC: Unknown command path: $commandPath');
      }
      return;
    }

    // /pprjm/group/{group-name}/{command...}
    if (address.startsWith('/pprjm/group/')) {
      final remainder = address.substring('/pprjm/group/'.length);
      final firstSlash = remainder.indexOf('/');
      if (firstSlash == -1) {
        debugPrint('OSC: Missing command after group name: $address');
        return;
      }
      final groupName = remainder.substring(0, firstSlash);
      final commandPath = remainder.substring(firstSlash + 1);
      final ntCmd = _oscCommandMap[commandPath];
      if (ntCmd == null) {
        debugPrint('OSC: Unknown command path: $commandPath');
        return;
      }
      final groupOscAddress = '/group/$groupName';
      final groupId = resolveGroupId?.call(groupOscAddress);
      if (groupId == null) {
        debugPrint('OSC: No group found for address: $groupOscAddress');
        return;
      }
      onCommand?.call(ntcontrolCmd: ntCmd, groupId: groupId, all: false);
      return;
    }

    // /pprjm/status — request: send all 3 status messages immediately, bypass change detection.
    if (address == '/pprjm/status') {
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
      _sendMessage('/pprjm/status/online', status.online);
      _lastOnline = status.online;
    }
    if (status.offline != _lastOffline) {
      _sendMessage('/pprjm/status/offline', status.offline);
      _lastOffline = status.offline;
    }
    if (status.warnings != _lastWarnings) {
      _sendMessage('/pprjm/status/warning', status.warnings);
      _lastWarnings = status.warnings;
    }
  }

  /// Sends all 3 status messages unconditionally (used for on-demand /pprjm/status requests).
  void sendStatusForced() {
    if (!_isActive || _socket == null || getStatus == null) return;

    final status = getStatus!();
    _sendMessage('/pprjm/status/online', status.online);
    _sendMessage('/pprjm/status/offline', status.offline);
    _sendMessage('/pprjm/status/warning', status.warnings);
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
