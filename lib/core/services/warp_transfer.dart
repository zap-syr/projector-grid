import 'dart:typed_data';

import '../../features/workspace/domain/geometry_overlay.dart';
import '../../features/workspace/domain/warp_codec.dart';
import '../../features/workspace/domain/warp_model_caps.dart';
import '../../features/workspace/domain/warp_table.dart';
import 'panasonic_protocol_service.dart';

// The transfer sequences of the free-form warp memories (PC-1 to PC-3 and the
// live RAM preview). Every frame is one call on the link and therefore one
// connection; all frames of one projector go out strictly one after the
// other, and a sequence stops at the first failure.

/// How the sequences reach one projector. Each call is one connection.
abstract interface class WarpLink {
  /// Sends one binary frame and returns the reply frame. Throws a
  /// [WarpProtocolException] for an error of the projector and a
  /// [WarpTransportException] when there was no usable reply.
  Future<Uint8List> binary(Uint8List frame);

  /// Sends an ASCII command and returns the reply without its `00` prefix,
  /// `ERxxx` codes included. Null when there was no reply at all.
  Future<String?> ascii(String command);
}

/// A [WarpLink] over [PanasonicProtocolService] (in the app, the instance
/// that runs on the worker isolate) for one projector.
class ProtocolWarpLink implements WarpLink {
  const ProtocolWarpLink(
    this.service, {
    required this.ip,
    required this.port,
    required this.login,
    required this.password,
  });

  final PanasonicProtocolService service;
  final String ip;
  final int port;
  final String login;
  final String password;

  @override
  Future<Uint8List> binary(Uint8List frame) =>
      service.sendBinaryCommand(ip, port, login, password, frame);

  @override
  Future<String?> ascii(String command) => service
      .sendRawCommandPreservingErrorCodes(ip, port, login, password, command);
}

/// Raised before anything is sent when a node of the table cannot be held by
/// the table format: the encoders do not clamp, the value would wrap.
class WarpNotEncodableException implements Exception {
  const WarpNotEncodableException(this.check, {required this.fpgaTable});

  /// How many nodes are out of range and the first of them.
  final WarpEncodableCheck check;

  /// True when the FPGA table is the one that failed, false for the full one.
  final bool fpgaTable;

  @override
  String toString() =>
      'WarpNotEncodableException: ${check.badCount} node(s) of the '
      '${fpgaTable ? 'FPGA' : 'full'} table are out of range';
}

/// Most packets a read follows: the largest table, three planes of 128 x 78
/// nodes, is 45 packets.
const int warpMaxReadPackets = 64;

/// The first packet of an empty RAM read has this location: one data byte,
/// never a last packet.
const int _emptyRamLocation = 0;

/// The error code of an `FF xx` frame for a slot with no table or a type the
/// model does not have.
const int _notAvailableCode = 0x8B;

// ---------------------------------------------------------------- read

/// The outcome of [readWarpBlock].
sealed class WarpReadResult {
  const WarpReadResult();
}

/// The block that was read, packets joined.
class WarpBlockRead extends WarpReadResult {
  const WarpBlockRead(this.block, this.method);

  /// Node counts, header and planes, as stored; see [decodeTable].
  final Uint8List block;

  /// The method byte of the first packet.
  final int method;
}

/// The projector answered `FF 8B`: the slot holds no table of this type, or
/// the model has no such type.
class WarpBlockNotAvailable extends WarpReadResult {
  const WarpBlockNotAvailable();
}

/// An empty RAM: nothing was ever written to the live preview.
class WarpBlockEmpty extends WarpReadResult {
  const WarpBlockEmpty();
}

/// Reads the table block of [type]: the first packet, then the next ones
/// until a packet ends the block. Every packet is checked for its checksum
/// and type. Throws a [WarpProtocolException] for an error, a damaged packet or
/// a block that does not end within [warpMaxReadPackets] packets.
Future<WarpReadResult> readWarpBlock(WarpLink link, {required int type}) async {
  final parts = <Uint8List>[];
  var method = 0;
  for (var packet = 0; packet < warpMaxReadPackets; packet++) {
    final top = packet == 0;
    final Uint8List reply;
    try {
      reply = await link.binary(buildReadFrame(type, top: top));
    } on WarpProtocolException catch (e) {
      if (top && e.code == _notAvailableCode) {
        return const WarpBlockNotAvailable();
      }
      rethrow;
    }
    final WarpReadReply parsed;
    try {
      parsed = parseReadReply(reply);
    } on FormatException catch (e) {
      throw WarpProtocolException('damaged READ reply: ${e.message}');
    }
    if (!parsed.checksumOk) {
      throw WarpProtocolException(
        'READ packet ${packet + 1} of type 0x${type.toRadixString(16)} '
        'has a wrong checksum',
      );
    }
    if (parsed.type != type) {
      throw WarpProtocolException(
        'READ reply is for type 0x${parsed.type.toRadixString(16)}, '
        'asked for 0x${type.toRadixString(16)}',
      );
    }
    if (top) {
      if (parsed.location == _emptyRamLocation) return const WarpBlockEmpty();
      method = parsed.method;
    }
    parts.add(parsed.data);
    if (parsed.location >= 2) {
      return WarpBlockRead(
        Uint8List.fromList([for (final p in parts) ...p]),
        method,
      );
    }
  }
  throw WarpProtocolException(
    'READ of type 0x${type.toRadixString(16)} did not end within '
    '$warpMaxReadPackets packets',
  );
}

// ---------------------------------------------------------------- reload

/// The numbers of control points a memory was stored with.
typedef WarpGridCounts = ({int columns, int rows});

/// The control points of a memory that has no `GGNS1` value: 3 x 3, the
/// corners, the middle of each side and the centre.
const WarpGridCounts warpDefaultGridCounts = (columns: 3, rows: 3);

/// What [reloadWarpMemory] found in one memory.
class WarpReloadResult {
  const WarpReloadResult({
    required this.mode,
    required this.storedAt,
    required this.read,
    required this.gridCounts,
    required this.gridCountsDefaulted,
  });

  /// The geometry mode number the projector is in (`GMMI0`; 3 to 5 are
  /// PC-1 to PC-3).
  final int mode;

  /// When the memory was stored (UTC), null when no time was saved.
  final DateTime? storedAt;

  /// The raw block, or why there is none. Decode it with [decodeTable].
  final WarpReadResult read;

  /// The control points the memory was stored with.
  final WarpGridCounts gridCounts;

  /// True when the projector has no `GGNS1` value and [gridCounts] is the
  /// default.
  final bool gridCountsDefaulted;
}

int _slotNumber(WarpSlot slot) {
  if (slot == WarpSlot.ram) {
    throw ArgumentError.value(slot, 'slot', 'a memory PC-1 to PC-3 is needed');
  }
  return slot.offset ~/ 2;
}

/// A reply of a `QVX:` query or null for `ER401`. Throws for no reply and for
/// any other error.
Future<String?> _query(WarpLink link, String command) async {
  final reply = await link.ascii(command);
  if (reply == null) {
    throw WarpTransportException('no reply to $command');
  }
  if (reply == 'ER401') return null;
  if (PanasonicProtocolService.isErrorCode(reply)) {
    throw WarpProtocolException('$command answered $reply');
  }
  return reply;
}

/// A write command: any reply that is not an error is success. Throws for no
/// reply and for an error.
Future<void> _write(WarpLink link, String command) async {
  final reply = await link.ascii(command);
  if (reply == null) {
    throw WarpTransportException('no reply to $command');
  }
  if (PanasonicProtocolService.isErrorCode(reply)) {
    throw WarpProtocolException('$command answered $reply');
  }
}

final RegExp _modeReply = RegExp(r'^GMMI0=([+-]?\d+)$');
final RegExp _storedReply = RegExp(r'^GDTS1=(\d):(\d{14})$');
final RegExp _gridReply = RegExp(r'^GGNS1=(\d):(\d{1,3}):(\d{1,3})$');

/// Reads memory [slot]: the geometry mode, the time it was stored, the table
/// block and the numbers of control points, in that order.
///
/// A block that is not there (see [WarpReadResult]) is a result, not an
/// error. Throws a [WarpProtocolException] for an error or a reply of an
/// unexpected shape and a [WarpTransportException] for no reply.
Future<WarpReloadResult> reloadWarpMemory(
  WarpLink link,
  WarpSlot slot,
  WarpModelCaps caps,
) async {
  final n = _slotNumber(slot);

  final modeReply = await _query(link, 'QVX:GMMI0');
  final modeMatch = modeReply == null ? null : _modeReply.firstMatch(modeReply);
  if (modeMatch == null) {
    throw WarpProtocolException('unexpected GMMI0 reply: $modeReply');
  }
  final mode = int.parse(modeMatch.group(1)!);

  final storedReply = await _query(link, 'QVX:GDTS1=$n');
  DateTime? storedAt;
  if (storedReply != null) {
    final m = _storedReply.firstMatch(storedReply);
    if (m == null || int.parse(m.group(1)!) != n) {
      throw WarpProtocolException('unexpected GDTS1 reply: $storedReply');
    }
    final s = m.group(2)!;
    int part(int from, int to) => int.parse(s.substring(from, to));
    storedAt = DateTime.utc(
      part(0, 4),
      part(4, 6),
      part(6, 8),
      part(8, 10),
      part(10, 12),
      part(12, 14),
    );
  }

  final read = await readWarpBlock(
    link,
    type: warpTypeCode(caps.fullBase, slot),
  );

  final gridReply = await _query(link, 'QVX:GGNS1=$n');
  var counts = warpDefaultGridCounts;
  if (gridReply != null) {
    final m = _gridReply.firstMatch(gridReply);
    if (m == null || int.parse(m.group(1)!) != n) {
      throw WarpProtocolException('unexpected GGNS1 reply: $gridReply');
    }
    counts = (columns: int.parse(m.group(2)!), rows: int.parse(m.group(3)!));
  }

  return WarpReloadResult(
    mode: mode,
    storedAt: storedAt,
    read: read,
    gridCounts: counts,
    gridCountsDefaulted: gridReply == null,
  );
}

// ---------------------------------------------------------------- write

/// Called after every frame or command of a sequence with the number done so
/// far and the total, which is known before the first one is sent.
typedef WarpProgress = void Function(int done, int total);

/// What a finished [storeWarpMemory] or [restoreWarpBackup] sent.
class WarpStoreResult {
  const WarpStoreResult({
    required this.frames,
    required this.fpgaEncoding,
    required this.dateSaved,
    required this.gridCountsSaved,
    this.metadataError,
  });

  /// Binary frames sent, SAVE included.
  final int frames;

  /// How the FPGA table went out; null for a restore, which writes none.
  final WarpEncoding? fpgaEncoding;

  /// Whether the stored time was written. The table is stored in any case:
  /// when this or [gridCountsSaved] is false, only that value was not saved
  /// (a restore writes no time and leaves this true).
  final bool dateSaved;

  /// Whether the numbers of control points were written.
  final bool gridCountsSaved;

  /// The first error of the two writes after SAVE, when one failed.
  final Object? metadataError;

  /// True when the table and both values are in the projector.
  bool get complete => dateSaved && gridCountsSaved;
}

/// `YYYYMMDDhhmmss` in UTC, zero-padded: the value of `GDTS1`.
String warpStoredTimeStamp(DateTime time) {
  final t = time.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

bool _allZero(Uint8List bytes) => bytes.every((b) => b == 0);

/// WRITE frames sent in order, each ack checked; the first failure ends the
/// sequence. Returns the number of steps done so far.
Future<int> _sendFrames(
  WarpLink link,
  List<Uint8List> frames,
  int done,
  int total,
  WarpProgress? onProgress,
) async {
  for (final frame in frames) {
    checkWriteAck(await link.binary(frame));
    onProgress?.call(++done, total);
  }
  return done;
}

/// The FPGA table of [full] and how to write it into a memory: row deltas when
/// every step fits, absolute words otherwise.
({WarpTable table, WarpEncoding encoding}) _fpgaPlan(
  WarpTable full,
  WarpModelCaps caps,
) {
  final table = fpgaTableFromFull(full, caps.geometry);
  return (table: table, encoding: fpgaEncodingFor(table, bits: caps.bits));
}

/// Refuses a table that the format cannot hold. Both tables are checked, the
/// full one first.
void _checkEncodable(WarpTable full, WarpTable fpga, int bits) {
  final fullCheck = checkWarpEncodable(full, bits);
  if (!fullCheck.ok) {
    throw WarpNotEncodableException(fullCheck, fpgaTable: false);
  }
  final fpgaCheck = checkWarpEncodable(fpga, bits);
  if (!fpgaCheck.ok) {
    throw WarpNotEncodableException(fpgaCheck, fpgaTable: true);
  }
}

/// Writes the numbers of control points and the stored time after a SAVE.
/// The table is in the projector by then, so a failure here is reported in
/// the result and does not stop the other write.
Future<({bool dateSaved, bool gridCountsSaved, Object? error})> _writeMetadata(
  WarpLink link,
  int n, {
  required String? stamp,
  required WarpGridCounts? counts,
  required int done,
  required int total,
  required WarpProgress? onProgress,
}) async {
  Object? error;
  var dateSaved = true;
  var gridCountsSaved = true;
  if (stamp != null) {
    try {
      await _write(link, 'VXX:GDTS1=$n:$stamp');
    } on WarpProtocolException catch (e) {
      dateSaved = false;
      error = e;
    } on WarpTransportException catch (e) {
      dateSaved = false;
      error = e;
    }
    onProgress?.call(++done, total);
  }
  if (counts != null) {
    try {
      await _write(link, 'VXX:GGNS1=$n:${counts.columns}:${counts.rows}');
    } on WarpProtocolException catch (e) {
      gridCountsSaved = false;
      error ??= e;
    } on WarpTransportException catch (e) {
      gridCountsSaved = false;
      error ??= e;
    }
    onProgress?.call(++done, total);
  }
  return (dateSaved: dateSaved, gridCountsSaved: gridCountsSaved, error: error);
}

/// Stores [full] into memory [slot] (PC-1 to PC-3).
///
/// The order is: the FPGA table, the full table, SAVE, the stored time
/// (`GDTS1`, from [now] in UTC), the numbers of control points (`GGNS1`).
/// Nothing is sent when a node cannot be encoded
/// ([WarpNotEncodableException], for the full and the FPGA table alike); the
/// first failing frame ends the sequence and SAVE is never sent after a
/// failed step. The header of [full] is replaced: [readHeader], the header
/// read from the slot, is kept as it is, and a missing or all-zero one (a
/// slot never written) becomes [defaultWarpHeader].
///
/// A failure of the two writes after SAVE does not throw: the table is
/// stored, and the result says which value is missing
/// ([WarpStoreResult.complete]).
Future<WarpStoreResult> storeWarpMemory(
  WarpLink link, {
  required WarpSlot slot,
  required WarpModelCaps caps,
  required WarpTable full,
  Uint8List? readHeader,
  required int gridColumns,
  required int gridRows,
  required DateTime now,
  WarpProgress? onProgress,
}) async {
  final n = _slotNumber(slot);
  final planes = full.planes.length;
  final separateRgb = planes == 3;

  final Uint8List header;
  if (readHeader == null || _allZero(readHeader)) {
    header = defaultWarpHeader(planes);
  } else if (readHeader.length == warpHeaderLength(planes)) {
    header = readHeader;
  } else {
    throw ArgumentError.value(
      readHeader.length,
      'readHeader',
      'a table with $planes plane(s) has a header of '
          '${warpHeaderLength(planes)} bytes',
    );
  }
  final table = WarpTable(
    columns: full.columns,
    rows: full.rows,
    header: warpHeaderWithLast(header, warpHeaderLastFull),
    planes: full.planes,
  );
  final fpga = _fpgaPlan(table, caps);
  _checkEncodable(table, fpga.table, caps.bits);

  // Everything is encoded before the first frame: a value the encoder
  // refuses must not leave a half-written memory.
  final fpgaFrames = tableWriteFrames(
    fpga.table,
    type: warpTypeCode(caps.fpgaBase, slot, separateRgb: separateRgb),
    encoding: fpga.encoding,
    bits: caps.bits,
  );
  final fullFrames = tableWriteFrames(
    table,
    type: warpTypeCode(caps.fullBase, slot, separateRgb: separateRgb),
    encoding: WarpEncoding.triple,
    bits: caps.bits,
  );
  final total = fpgaFrames.length + fullFrames.length + 1 + 2;

  var done = await _sendFrames(link, fpgaFrames, 0, total, onProgress);
  done = await _sendFrames(link, fullFrames, done, total, onProgress);
  checkSaveAck(await link.binary(buildSaveFrame(slot)), slot);
  onProgress?.call(++done, total);

  final metadata = await _writeMetadata(
    link,
    n,
    stamp: warpStoredTimeStamp(now),
    counts: (columns: gridColumns, rows: gridRows),
    done: done,
    total: total,
    onProgress: onProgress,
  );
  return WarpStoreResult(
    frames: fpgaFrames.length + fullFrames.length + 1,
    fpgaEncoding: fpga.encoding,
    dateSaved: metadata.dateSaved,
    gridCountsSaved: metadata.gridCountsSaved,
    metadataError: metadata.error,
  );
}

/// Puts a backed-up block back into memory [slot]: the raw bytes, unchanged,
/// cut into the same 4096-byte frames as a write of the full table of type
/// [fullType] (from [warpTypeCode], with the separate-colour flag when the
/// block has three planes), then SAVE, then the numbers of control points
/// when they are given. Failures end the sequence as in [storeWarpMemory];
/// only the full table is written, and the stored time is left as it is.
Future<WarpStoreResult> restoreWarpBackup(
  WarpLink link, {
  required WarpSlot slot,
  required int fullType,
  required Uint8List rawBlock,
  int? gridColumns,
  int? gridRows,
  WarpProgress? onProgress,
}) async {
  final n = _slotNumber(slot);
  final frames = chunkWrite(fullType, warpMethodFull, Uint8List(0), rawBlock);
  final counts = gridColumns != null && gridRows != null
      ? (columns: gridColumns, rows: gridRows)
      : null;
  final total = frames.length + 1 + (counts == null ? 0 : 1);

  var done = await _sendFrames(link, frames, 0, total, onProgress);
  checkSaveAck(await link.binary(buildSaveFrame(slot)), slot);
  onProgress?.call(++done, total);

  final metadata = await _writeMetadata(
    link,
    n,
    stamp: null,
    counts: counts,
    done: done,
    total: total,
    onProgress: onProgress,
  );
  return WarpStoreResult(
    frames: frames.length + 1,
    fpgaEncoding: null,
    dateSaved: true,
    gridCountsSaved: metadata.gridCountsSaved,
    metadataError: metadata.error,
  );
}

/// What [writeWarpPreview] sent.
class WarpPreviewResult {
  const WarpPreviewResult({required this.frames, required this.encoding});

  final int frames;

  /// How the table went out.
  final WarpEncoding encoding;
}

/// Writes the live preview of [full] into the RAM of the projector: its FPGA
/// table, as row deltas when they fit. Otherwise absolute values with method
/// 0x10: 1/64 px for the models with a 4K FPGA (type base 0x80), and words
/// for the others (type base 0x50), which is not confirmed on hardware.
/// Nothing is sent for a table that cannot be encoded.
Future<WarpPreviewResult> writeWarpPreview(
  WarpLink link, {
  required WarpModelCaps caps,
  required WarpTable full,
}) async {
  final plan = _fpgaPlan(full, caps);
  _checkEncodable(full, plan.table, caps.bits);
  final encoding = plan.encoding == WarpEncoding.delta
      ? WarpEncoding.delta
      : caps.fpgaBase == 0x80
      ? WarpEncoding.fpga64
      : WarpEncoding.word;
  final frames = tableWriteFrames(
    plan.table,
    type: warpTypeCode(
      caps.fpgaBase,
      WarpSlot.ram,
      separateRgb: full.planes.length == 3,
    ),
    encoding: encoding,
    bits: caps.bits,
  );
  await _sendFrames(link, frames, 0, frames.length, null);
  return WarpPreviewResult(frames: frames.length, encoding: encoding);
}

// ---------------------------------------------------------------- overlay

/// Shows or hides the cursor on the control point at ([x], [y]).
Future<void> sendWarpCursor(
  WarpLink link, {
  required bool on,
  required int x,
  required int y,
  int kind = 0,
}) async => checkCursorAck(
  await link.binary(buildCursorFrame(on: on, x: x, y: y, kind: kind)),
);

/// Shows or hides the grid through the control points.
Future<void> sendWarpGridOverlay(
  WarpLink link, {
  required bool on,
  required int columns,
  required int rows,
  required int rgb,
}) async => checkGridOverlayAck(
  await link.binary(
    buildGridOverlayFrame(on: on, columns: columns, rows: rows, rgb: rgb),
  ),
);

/// Highlights the control points whose mark is 1 (see [gridPointMarks]).
Future<void> sendWarpPointMarks(WarpLink link, List<int> marks) async =>
    checkWriteAck(await link.binary(buildGridPointMarksFrame(marks)));

/// What the projector shows for a selection: the cursor on the point at
/// ([x], [y]) first, then the marks.
Future<void> sendWarpSelection(
  WarpLink link, {
  required int x,
  required int y,
  required List<int> marks,
}) async {
  await sendWarpCursor(link, on: true, x: x, y: y);
  await sendWarpPointMarks(link, marks);
}
