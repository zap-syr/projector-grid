import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

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
  'input/computer1': 'IIS:RG1',
  'input/computer2': 'IIS:RG2',
  'input/video': 'IIS:VID',
  'input/yc': 'IIS:SVD',
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

/// One outgoing OSC 1.0 message: strings as UTF-8, null-terminated and
/// padded to 4 bytes; ints as 32-bit big-endian; doubles as 32-bit floats.
///
/// Not package:osc's own encoder: it writes a string's UTF-16 code units
/// one byte each, so `°` goes out as a lone 0xB0 and a Cyrillic projector
/// name is cut down to garbage.
List<int> encodeOscMessage(String address, List<Object> arguments) {
  final out = BytesBuilder();
  void string(String s) {
    final bytes = utf8.encode(s);
    out
      ..add(bytes)
      ..add(List.filled(4 - bytes.length % 4, 0));
  }

  string(address);
  string(
    ',${arguments.map((a) => switch (a) {
      String() => 's',
      int() => 'i',
      double() => 'f',
      _ => throw ArgumentError.value(a, 'arguments', 'OSC string, int or double'),
    }).join()}',
  );
  for (final a in arguments) {
    switch (a) {
      case String():
        string(a);
      case int():
        out.add((ByteData(4)..setInt32(0, a)).buffer.asUint8List());
      case double():
        out.add((ByteData(4)..setFloat32(0, a)).buffer.asUint8List());
    }
  }
  return out.takeBytes();
}

/// Callback type for collecting projector status counts. [critical] and
/// [warning] are unacknowledged alerts, not projectors.
typedef OscStatusCallback = ({
  int online,
  int offline,
  int critical,
  int warning,
});

class OscService {
  RawDatagramSocket? _socket;
  bool _isActive = false;
  String _sendIp = '127.0.0.1';
  int _sendPort = 9000;

  // Per-address cooldown: the same OSC address cannot trigger more than once
  // per _commandCooldown. This prevents a runaway show controller from
  // flooding the app with concurrent TCP operations.
  static const _commandCooldown = Duration(milliseconds: 50);
  final Map<String, DateTime> _lastCommandTimes = {};

  // Previous counts — used to detect changes and skip redundant sends.
  int? _lastOnline;
  int? _lastOffline;
  int? _lastCritical;
  int? _lastWarning;

  // RawDatagramSocket.send() returns 0 instead of throwing when the socket
  // can't take the datagram yet — on Windows that's most back-to-back sends,
  // so the 3-message status burst used to silently lose messages. Unsent
  // datagrams wait here, in order, until the socket reports it is writable.
  final Queue<List<int>> _outbox = Queue();

  /// Called when a valid OSC command is received and resolved.
  OscCommandCallback? onCommand;

  /// Called to get current projector status counts for outgoing messages.
  OscStatusCallback Function()? getStatus;

  /// Group OSC address → group ID resolver.
  String? Function(String oscAddress)? resolveGroupId;

  /// Custom command OSC slug → NTCONTROL command resolver.
  String? Function(String oscSlug)? resolveCustomCommand;

  bool get isActive => _isActive;

  // Bumped by every start()/stop() call. A start() in flight checks this
  // right after its RawDatagramSocket.bind() await resolves — if a newer
  // start()/stop() call has since superseded it, its freshly-bound socket is
  // closed immediately instead of being kept, so overlapping calls (rapid
  // toggling, a Preferences save racing app init) can't leak a socket.
  int _startGeneration = 0;

  Future<void> start({
    required String networkDevice,
    required int receivePort,
    required String sendIp,
    required int sendPort,
  }) async {
    // Claim the generation *after* stop() — stop() also bumps _startGeneration,
    // so capturing it earlier would leave `generation` permanently stale and
    // make the post-bind check below abort every successful bind.
    await stop();
    final generation = ++_startGeneration;
    _sendIp = sendIp;
    _sendPort = sendPort;
    _lastOnline = null;
    _lastOffline = null;
    _lastCritical = null;
    _lastWarning = null;

    try {
      final bindAddress = networkDevice.isEmpty
          ? InternetAddress.anyIPv4
          : InternetAddress(networkDevice);
      final socket = await RawDatagramSocket.bind(bindAddress, receivePort);

      if (generation != _startGeneration) {
        // Superseded by a newer start()/stop() while the bind was pending.
        socket.close();
        return;
      }

      _socket = socket;
      _isActive = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) _handleDatagram(datagram);
        } else if (event == RawSocketEvent.write) {
          _flushOutbox();
        }
      });

      debugPrint(
        'OSC: Listening on ${bindAddress.address}:$receivePort → sending to $_sendIp:$_sendPort',
      );
    } catch (e) {
      debugPrint('OSC: Failed to start — $e');
      _isActive = false;
    }
  }

  Future<void> stop() async {
    _startGeneration++; // invalidate any in-flight start()
    _socket?.close();
    _socket = null;
    _isActive = false;
    _lastCommandTimes.clear();
    _outbox.clear();
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final msg = OSCMessage.fromBytes(datagram.data);
      _processMessage(msg);
    } catch (e) {
      debugPrint('OSC: Failed to parse message — $e');
    }
  }

  /// Routes [msg] exactly as if it had arrived on the socket, without binding
  /// one.
  @visibleForTesting
  void processMessage(OSCMessage msg) => _processMessage(msg);

  void _processMessage(OSCMessage msg) {
    final address = msg.address;

    final now = DateTime.now();
    final last = _lastCommandTimes[address];
    if (last != null && now.difference(last) < _commandCooldown) return;
    _lastCommandTimes[address] = now;

    // /pgrid/all/{command...}
    // Also handles /pgrid/all/custom/{slug} for user-defined commands.
    if (address.startsWith('/pgrid/all/')) {
      final commandPath = address.substring('/pgrid/all/'.length);
      if (commandPath.startsWith('custom/')) {
        final slug = commandPath.substring('custom/'.length);
        final ntCmd = resolveCustomCommand?.call(slug);
        if (ntCmd != null && onCommand != null) {
          unawaited(
            onCommand!(
              ntcontrolCmd: ntCmd,
              all: true,
            ).catchError((Object e) => debugPrint('OSC command error: $e')),
          );
        } else {
          debugPrint('OSC: Unknown custom command slug: $slug');
        }
      } else {
        final ntCmd = _oscCommandMap[commandPath];
        if (ntCmd != null && onCommand != null) {
          unawaited(
            onCommand!(
              ntcontrolCmd: ntCmd,
              all: true,
            ).catchError((Object e) => debugPrint('OSC command error: $e')),
          );
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
          unawaited(
            onCommand!(
              ntcontrolCmd: ntCmd,
              groupId: groupId,
              all: false,
            ).catchError((Object e) => debugPrint('OSC command error: $e')),
          );
        } else {
          debugPrint('OSC: Unknown custom command slug: $slug');
        }
      } else {
        final ntCmd = _oscCommandMap[commandPath];
        if (ntCmd == null) {
          debugPrint('OSC: Unknown command path: $commandPath');
          return;
        }
        if (onCommand != null) {
          unawaited(
            onCommand!(
              ntcontrolCmd: ntCmd,
              groupId: groupId,
              all: false,
            ).catchError((Object e) => debugPrint('OSC command error: $e')),
          );
        }
      }
      return;
    }

    // /pgrid/status — request: send every status message immediately, bypass change detection.
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
    if (status.critical != _lastCritical) {
      _sendMessage('/pgrid/status/critical', status.critical);
      _lastCritical = status.critical;
    }
    if (status.warning != _lastWarning) {
      _sendMessage('/pgrid/status/warning', status.warning);
      _lastWarning = status.warning;
    }
  }

  /// Sends every status message unconditionally (used for on-demand /pgrid/status requests).
  void sendStatusForced() {
    if (!_isActive || _socket == null || getStatus == null) return;

    final status = getStatus!();
    _sendMessage('/pgrid/status/online', status.online);
    _sendMessage('/pgrid/status/offline', status.offline);
    _sendMessage('/pgrid/status/critical', status.critical);
    _sendMessage('/pgrid/status/warning', status.warning);
    _lastOnline = status.online;
    _lastOffline = status.offline;
    _lastCritical = status.critical;
    _lastWarning = status.warning;
  }

  /// Sends one message with any arguments (strings, ints, floats) to the
  /// send target, if the service is running. For the alert messages.
  void sendMessage(String address, List<Object> arguments) {
    if (!_isActive || _socket == null) return;
    _outbox.add(encodeOscMessage(address, arguments));
    _flushOutbox();
  }

  void _sendMessage(String address, int value) => sendMessage(address, [value]);

  void _flushOutbox() {
    final socket = _socket;
    if (socket == null) return;
    while (_outbox.isNotEmpty) {
      try {
        if (socket.send(_outbox.first, InternetAddress(_sendIp), _sendPort) ==
            0) {
          // Delivery of the next write event resets this flag, so it has to
          // be re-armed on every stall.
          socket.writeEventsEnabled = true;
          return;
        }
      } catch (e) {
        debugPrint('OSC: Failed to send datagram — $e');
      }
      _outbox.removeFirst();
    }
  }
}
