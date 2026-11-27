import 'dart:typed_data';

import 'package:projector_grid/core/services/warp_transfer.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';

/// The state and the answers of a projector for the warp transfer: table
/// blocks per type, the geometry mode, the stored time and the numbers of
/// control points. It is shared by the loopback server and the fake protocol
/// service, so both answer the same way.
///
/// Replies are lines as the projector sends them, without the `\r`: `01` and
/// hex for a frame, `00ERR3` for a command it does not understand.
class FakeWarpProjector {
  /// Every binary frame received, scripted ones included.
  final List<Uint8List> frames = [];

  /// Every ASCII command this projector answered or dropped.
  final List<String> asciiCommands = [];

  /// Blocks by memory key: the type with the 0x4x table aliased to 0x7x, as the
  /// projector reads a 0x4x write back as the 0x7x memory.
  final Map<int, Uint8List> blocks = {};

  /// Memories whose SAVE was received, as the last byte of the frame.
  final List<int> saves = [];

  /// The last marks frame data (type 0x90), if one was received.
  Uint8List? marks;

  int mode = 0;
  final Map<int, String> storedTimes = {};
  final Map<int, String> gridCounts = {};

  /// The method byte of every READ reply packet.
  int readMethod = 0;

  /// Reads reply with a wrong checksum.
  bool corruptReadChecksum = false;

  /// Replies to answer instead of handling the frame with this index (the
  /// frame is recorded but changes nothing). A null value drops the
  /// connection without a reply.
  final Map<int, String?> scripted = {};

  /// ASCII commands that start with one of these get no reply.
  final Set<String> droppedAscii = {};

  // A write in progress, and where the next read of a type continues.
  ({int type, int method, List<Uint8List> parts})? _pending;
  final Map<int, int> _readOffsets = {};

  static String frameLine(List<int> frame) => '01${warpBytesToHex(frame)}';

  static String errorLine(int code) =>
      frameLine([0x02, 0x00, 0xFF, code, 0x03]);

  static String writeAckLine({int status = 0}) =>
      frameLine([0x02, 0x00, 0xA9, 0xC0, status, 0x03]);

  /// The reply to the frame number [index] is [line] (null: drop).
  void script(int index, String? line) => scripted[index] = line;

  /// The frame number [index] is answered with an `FF code` frame.
  void failFrame(int index, int code) => script(index, errorLine(code));

  /// The frame number [index] is answered with a WRITE ack of [status].
  void rejectFrame(int index, int status) =>
      script(index, writeAckLine(status: status));

  /// The connection of the frame number [index] drops.
  void dropFrame(int index) => script(index, null);

  static int _memoryKey(int type) =>
      ((type & 0xF0) == 0x40 ? 0x70 : type & 0xF0) | (type & 0x0E);

  /// Puts a block in memory as a write of [type] would.
  void setBlock(int type, Uint8List block) =>
      blocks[_memoryKey(type)] = Uint8List.fromList(block);

  Uint8List? blockOf(int type) => blocks[_memoryKey(type)];

  /// The reply line for [frame], or null when the connection drops.
  String? handleBinary(Uint8List frame) {
    final index = frames.length;
    frames.add(Uint8List.fromList(frame));
    if (scripted.containsKey(index)) return scripted[index];
    if (frame.length < 5 ||
        frame[0] != 0x02 ||
        frame[1] != 0x00 ||
        frame.last != 0x03) {
      return '00ERR3';
    }
    switch ((frame[2] << 8) | frame[3]) {
      case 0xA9C0:
        return _write(frame);
      case 0xA8C0:
        return _read(frame);
      case 0xAAE0 || 0xAAE1 || 0xAAE2 || 0xAAE3:
        saves.add(frame[3]);
        return frameLine([0x02, 0x00, 0xAA, frame[3], 0x00, 0x03]);
      case 0xAC07 || 0xAB07:
        return frameLine([0x02, 0x00, frame[2], 0x07, 0x00, 0x03]);
      default:
        return '00ERR1';
    }
  }

  String _write(Uint8List f) {
    final size = (f[4] << 8) | f[5];
    if (size < 3 || f.length != 9 + (size - 3) + 2) return '00ERR3';
    final type = f[6];
    final method = f[7];
    final location = f[8];
    final data = Uint8List.fromList(f.sublist(9, 9 + size - 3));
    if (f[9 + size - 3] != warpChecksum(type, method, location, data)) {
      return '00ERR3';
    }
    final begins = location == 1 || location == 3;
    if (begins) {
      _pending = (type: type, method: method, parts: []);
    } else if (_pending == null || _pending!.type != type) {
      return '00ERR3';
    }
    _pending!.parts.add(data);
    if (location == 2 || location == 3) {
      final joined = Uint8List.fromList([
        for (final p in _pending!.parts) ...p,
      ]);
      if (type == 0x90) {
        marks = joined;
      } else {
        blocks[_memoryKey(type)] = joined;
      }
      _pending = null;
    }
    return writeAckLine();
  }

  String _read(Uint8List f) {
    final type = f[4];
    final top = f[5] != 0;
    final block = blocks[_memoryKey(type)];
    if (block == null) {
      // An empty live memory answers with a one-byte packet that never ends;
      // an empty stored memory with error 0x8B.
      if ((type & 0x0E) == 0) {
        return _readLine(type, 0, Uint8List(1), 0);
      }
      return errorLine(0x8B);
    }
    if (top) _readOffsets[type] = 0;
    final offset = _readOffsets[type];
    if (offset == null) return '00ERR3';
    final n = block.length - offset < warpMaxChunk
        ? block.length - offset
        : warpMaxChunk;
    final first = offset == 0;
    final last = offset + n >= block.length;
    final location = first && last
        ? 3
        : first
        ? 1
        : last
        ? 2
        : 0;
    _readOffsets[type] = offset + n;
    return _readLine(
      type,
      readMethod,
      Uint8List.sublistView(block, offset, offset + n),
      location,
    );
  }

  String _readLine(int type, int method, Uint8List data, int location) {
    final size = 3 + data.length;
    var cs = warpChecksum(type, method, location, data);
    if (corruptReadChecksum) cs ^= 0xFF;
    return frameLine([
      0x02,
      0x00,
      0xA8,
      0xC0,
      size >> 8,
      size & 0xFF,
      type,
      method,
      location,
      ...data,
      cs,
      0x03,
    ]);
  }

  /// True when [command] gets no reply.
  bool dropsAscii(String command) {
    final drops = droppedAscii.any(command.startsWith);
    if (drops) asciiCommands.add(command);
    return drops;
  }

  static final RegExp _setMode = RegExp(r'^VXX:GMMI0=\+(\d{5})$');
  static final RegExp _setValue = RegExp(r'^VXX:(GDTS1|GGNS1)=(\d):(.+)$');
  static final RegExp _getValue = RegExp(r'^QVX:(GDTS1|GGNS1)=(\d)$');

  /// The reply body (no `00`) for an ASCII command this projector knows, or
  /// null when it is not one of them.
  String? handleAscii(String command) {
    asciiCommands.add(command);
    if (command == 'QVX:GMMI0') {
      return 'GMMI0=+${mode.toString().padLeft(5, '0')}';
    }
    final setMode = _setMode.firstMatch(command);
    if (setMode != null) {
      mode = int.parse(setMode.group(1)!);
      return command;
    }
    final set = _setValue.firstMatch(command);
    if (set != null) {
      final target = set.group(1) == 'GDTS1' ? storedTimes : gridCounts;
      target[int.parse(set.group(2)!)] = set.group(3)!;
      return command;
    }
    final get = _getValue.firstMatch(command);
    if (get != null) {
      final target = get.group(1) == 'GDTS1' ? storedTimes : gridCounts;
      final n = int.parse(get.group(2)!);
      final value = target[n];
      return value == null ? 'ER401' : '${get.group(1)}=$n:$value';
    }
    return null;
  }
}

/// A [WarpLink] on a [FakeWarpProjector], for the tests of the sequences. It
/// logs every command in order: a `Uint8List` for a frame, a `String` for an
/// ASCII command.
class MemoryWarpLink implements WarpLink {
  MemoryWarpLink([FakeWarpProjector? projector])
    : projector = projector ?? FakeWarpProjector();

  final FakeWarpProjector projector;
  final List<Object> log = [];

  @override
  Future<Uint8List> binary(Uint8List frame) async {
    log.add(frame);
    final line = projector.handleBinary(frame);
    if (line == null) {
      throw const WarpTransportException('connection dropped');
    }
    return parseWarpBinaryReply(line);
  }

  @override
  Future<String?> ascii(String command) async {
    log.add(command);
    if (projector.dropsAscii(command)) return null;
    return projector.handleAscii(command) ?? 'ER401';
  }
}
