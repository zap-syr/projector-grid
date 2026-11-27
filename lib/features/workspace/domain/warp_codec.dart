import 'dart:math' as math;
import 'dart:typed_data';

import 'warp_table.dart';

/// How the points of one plane are packed into bytes.
enum WarpEncoding {
  /// Three bytes per coordinate, big-endian: the full table of a memory.
  triple,

  /// Two bytes per coordinate, little-endian: absolute 1/16, 1/8 or 1/4 px.
  word,

  /// Two bytes per coordinate, little-endian, 1/64 px, wrapping every 1024 px
  /// (the live preview of 4K FPGA models).
  fpga64,

  /// Per row: the start point as words, then one byte of x and one signed
  /// byte of y per further point, in 1/4 px (the FPGA table of a memory).
  delta,
}

/// A table memory. RAM is the live preview, PC-1 to PC-3 are the stored ones.
enum WarpSlot {
  ram(0),
  pc1(2),
  pc2(4),
  pc3(6);

  const WarpSlot(this.offset);

  /// Added to the type code base of a table.
  final int offset;

  /// The last byte of the SAVE frame: RAM goes to the current memory (0xE0),
  /// PC-n commits memory n (0xE0 + n).
  int get saveByte => 0xE0 + offset ~/ 2;
}

/// Method byte of a table written as a whole, header included.
const int warpMethodFull = 0x10;

/// Method byte of a table written as row deltas.
const int warpMethodDelta = 0x00;

/// Largest data chunk of one write frame.
const int warpMaxChunk = 0x1000;

/// Raised for an error the projector reported, or a reply that is not the
/// one that was asked for.
class WarpProtocolException implements Exception {
  const WarpProtocolException(this.message, {this.code});

  final String message;

  /// The code of an `FF xx` error frame, when there was one.
  final int? code;

  @override
  String toString() => 'WarpProtocolException: $message';
}

/// What the projector means by an error code of an `FF xx` frame.
String warpErrorMeaning(int code) => switch (code) {
  0x8B => 'no data in this slot / type not available',
  _ => 'unknown error',
};

// ---------------------------------------------------------------- numbers

/// The rounding the projector software uses: half away from zero, computed
/// as `trunc(trunc(sign + v * 2k) / 2)`. A plain `round()` differs at
/// half-way values.
int warpRound(double v, int k) {
  final sign = v >= 0 ? 1 : -1;
  return (sign + v * 2 * k).truncate() ~/ 2;
}

int _tripleScale(int bits) => switch (bits) {
  4 => 4096,
  3 => 256,
  _ => throw ArgumentError.value(
    bits,
    'bits',
    '3-byte encoding is not defined for this bit type',
  ),
};

int _wordScale(int bits) => switch (bits) {
  4 => 16,
  3 => 8,
  2 => 4,
  _ => throw ArgumentError.value(
    bits,
    'bits',
    '2-byte encoding is not defined for this bit type',
  ),
};

/// Writes [v] as three big-endian bytes. Bits 4 stores values from -1024 up to
/// 3072 px: the projector reads -600 correctly, and the whole range a point
/// can reach fits. Bits 3 is a signed 24-bit value.
void encodeTriple(double v, int bits, Uint8List out, int offset) {
  final k = _tripleScale(bits);
  final i = warpRound(v, k);
  final lo = bits == 4 ? -0x400000 : -0x800000;
  final hi = bits == 4 ? 0xBFFFFF : 0x7FFFFF;
  if (i < lo || i > hi) {
    throw ArgumentError.value(
      v,
      'v',
      'out of range [${lo / k}, ${(hi + 1) / k}) px for 3-byte bits $bits',
    );
  }
  final u = i & 0xFFFFFF;
  out[offset] = (u >> 16) & 0xFF;
  out[offset + 1] = (u >> 8) & 0xFF;
  out[offset + 2] = u & 0xFF;
}

double decodeTriple(Uint8List b, int offset, int bits) {
  final k = _tripleScale(bits);
  final u = (b[offset] << 16) | (b[offset + 1] << 8) | b[offset + 2];
  if (bits == 4) return (u < 0xC00000 ? u : u - 0x1000000) / k;
  return ((u & 0x800000) != 0 ? u - 0x1000000 : u) / k;
}

/// Writes [v] as two little-endian bytes. Bits 4 and 3 store -1024 or -2048
/// px up to 3072 or 6144 px (signed, split at 0xC000); bits 2 is unsigned.
void encodeWord(double v, int bits, Uint8List out, int offset) {
  final k = _wordScale(bits);
  final i = warpRound(v, k);
  final lo = bits == 2 ? 0 : -0x4000;
  final hi = bits == 2 ? 0xFFFF : 0xBFFF;
  if (i < lo || i > hi) {
    throw ArgumentError.value(
      v,
      'v',
      'out of range [${lo / k}, ${(hi + 1) / k}) px for 2-byte bits $bits',
    );
  }
  final u = i & 0xFFFF;
  out[offset] = u & 0xFF;
  out[offset + 1] = (u >> 8) & 0xFF;
}

double decodeWord(Uint8List b, int offset, int bits) {
  final k = _wordScale(bits);
  final u = b[offset] | (b[offset + 1] << 8);
  if (bits == 2) return u / k;
  return (u < 0xC000 ? u : u - 0x10000) / k;
}

/// Writes [v] in 1/64 px as two little-endian bytes. The value wraps every
/// 1024 px; [unwrapFpga64] restores it from the previous point.
void encodeFpga64(double v, Uint8List out, int offset) {
  final u = warpRound(v, 64) & 0xFFFF;
  out[offset] = u & 0xFF;
  out[offset + 1] = u >> 8;
}

/// The wrapped value of an fpga64 coordinate, in px.
double decodeFpga64Raw(Uint8List b, int offset) =>
    (b[offset] | (b[offset + 1] << 8)) / 64;

/// The value that [wrapped] stands for when the neighbouring point is at
/// [near]: the one of the form `wrapped + 1024 n` closest to it.
double unwrapFpga64(double wrapped, double near) =>
    wrapped + 1024 * ((near - wrapped) / 1024 + 0.5).floor();

// ---------------------------------------------------------------- hex

final RegExp _hexDigits = RegExp(r'^[0-9a-fA-F]*$');

String warpBytesToHex(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
  }
  return out.toString();
}

/// Whitespace is ignored. Throws a [FormatException] for odd lengths and
/// anything that is not a hex digit.
Uint8List warpHexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  if (clean.length.isOdd || !_hexDigits.hasMatch(clean)) {
    throw FormatException('not a hex byte string', hex);
  }
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

// ---------------------------------------------------------------- frames

/// The type byte of a table: the base of the model, plus the slot, plus one
/// when the table has three separate colour planes.
int warpTypeCode(int base, WarpSlot slot, {bool separateRgb = false}) =>
    base + slot.offset + (separateRgb ? 1 : 0);

/// `(type + method + location + sum of data) & 0xFF`.
int warpChecksum(int type, int method, int location, Uint8List data) {
  var sum = type + method + location;
  for (final b in data) {
    sum += b;
  }
  return sum & 0xFF;
}

/// A WRITE GEOMETRY DATA frame. The size field counts type, method,
/// location and data, not the checksum.
Uint8List buildWriteFrame(int type, int method, int location, Uint8List data) {
  final size = 3 + data.length;
  final out = Uint8List(9 + data.length + 2);
  out[0] = 0x02;
  out[1] = 0x00;
  out[2] = 0xA9;
  out[3] = 0xC0;
  out[4] = (size >> 8) & 0xFF;
  out[5] = size & 0xFF;
  out[6] = type;
  out[7] = method;
  out[8] = location;
  out.setRange(9, 9 + data.length, data);
  out[9 + data.length] = warpChecksum(type, method, location, data);
  out[9 + data.length + 1] = 0x03;
  return out;
}

/// A READ GEOMETRY DATA frame: [top] asks for the first packet, otherwise the
/// next one.
Uint8List buildReadFrame(int type, {required bool top}) => Uint8List.fromList([
  0x02,
  0x00,
  0xA8,
  0xC0,
  type,
  top ? 1 : 0,
  0x10,
  0x03,
  0x03,
]);

/// SAVE DATA: RAM into the current memory, or the staged table into PC-n.
Uint8List buildSaveFrame(WarpSlot slot) =>
    Uint8List.fromList([0x02, 0x00, 0xAA, slot.saveByte, 0x03]);

/// One packet of a READ reply.
class WarpReadReply {
  const WarpReadReply({
    required this.size,
    required this.type,
    required this.method,
    required this.location,
    required this.data,
    required this.checksumOk,
  });

  final int size;
  final int type;
  final int method;

  /// 3: the only packet, 1: first, 0: middle, 2: last. A packet with a
  /// location of 2 or more ends the block.
  final int location;
  final Uint8List data;
  final bool checksumOk;
}

/// Parses `02 00 A8 C0 <size> <type> <method> <location> <data> <cs> 03`.
/// Throws a [FormatException] for anything else or a reply that is cut short.
WarpReadReply parseReadReply(Uint8List reply) {
  if (reply.length < 10 ||
      reply[0] != 0x02 ||
      reply[2] != 0xA8 ||
      reply[3] != 0xC0) {
    throw FormatException('unexpected READ reply', warpBytesToHex(reply));
  }
  final size = (reply[4] << 8) | reply[5];
  final type = reply[6];
  final method = reply[7];
  final location = reply[8];
  final dataEnd = 9 + size - 3;
  if (size < 3 || reply.length < dataEnd + 1) {
    throw FormatException(
      'short READ reply (size $size, have ${reply.length} bytes)',
      warpBytesToHex(reply),
    );
  }
  final data = Uint8List.sublistView(reply, 9, dataEnd);
  return WarpReadReply(
    size: size,
    type: type,
    method: method,
    location: location,
    data: data,
    checksumOk: reply[dataEnd] == warpChecksum(type, method, location, data),
  );
}

/// A WRITE is acknowledged with `02 00 A9 C0 00 03`; a status other than 0 or
/// any other reply is an error.
void checkWriteAck(Uint8List reply) {
  if (reply.length >= 6 &&
      reply[0] == 0x02 &&
      reply[2] == 0xA9 &&
      reply[3] == 0xC0) {
    if (reply[4] != 0) {
      throw WarpProtocolException(
        'write rejected, status 0x${reply[4].toRadixString(16)}',
        code: reply[4],
      );
    }
    return;
  }
  throw WarpProtocolException(
    'unexpected WRITE reply: ${warpBytesToHex(reply)}',
  );
}

/// Splits a table into WRITE frames: the head (node counts and header) and
/// the point bytes are cut into chunks of [warpMaxChunk] bytes. The first
/// frame is a single packet (location 3) when everything fits, otherwise
/// 1, then 0 for the middle ones and 2 for the last.
List<Uint8List> chunkWrite(
  int type,
  int method,
  Uint8List head,
  Uint8List points,
) {
  final frames = <Uint8List>[];
  final firstLimit = warpMaxChunk - head.length;
  final total = points.length;
  var offset = math.min(total, firstLimit);
  frames.add(
    buildWriteFrame(
      type,
      method,
      total > firstLimit ? 1 : 3,
      Uint8List.fromList([
        ...head,
        ...Uint8List.sublistView(points, 0, offset),
      ]),
    ),
  );
  while (offset < total) {
    final remaining = total - offset;
    final n = math.min(remaining, warpMaxChunk);
    frames.add(
      buildWriteFrame(
        type,
        method,
        remaining > warpMaxChunk ? 0 : 2,
        Uint8List.sublistView(points, offset, offset + n),
      ),
    );
    offset += n;
  }
  return frames;
}

// ---------------------------------------------------------------- wire

/// The body of a binary command line: `01` and the frame as upper-case hex.
/// The line sent to the projector is the authentication hash, this body and
/// a carriage return.
String warpBinaryCommandBody(Uint8List frame) => '01${warpBytesToHex(frame)}';

/// The frame inside a binary reply line (`01` and hex). Throws a
/// [WarpProtocolException] for an ASCII error reply or an `FF xx` error frame
/// and a [FormatException] when the line is not hex at all.
Uint8List parseWarpBinaryReply(String line) {
  final reply = line.trim();
  if (RegExp(r'^(0[01])?ER', caseSensitive: false).hasMatch(reply)) {
    throw WarpProtocolException('projector error: $reply');
  }
  var hex = reply;
  if (RegExp(r'^0[01]02', caseSensitive: false).hasMatch(hex)) {
    hex = hex.substring(2);
  }
  final bytes = warpHexToBytes(hex);
  if (bytes.length >= 4 && bytes[0] == 0x02 && bytes[2] == 0xFF) {
    final code = bytes[3];
    throw WarpProtocolException(
      'projector error 0x${code.toRadixString(16)} (${warpErrorMeaning(code)})',
      code: code,
    );
  }
  return bytes;
}

// ---------------------------------------------------------------- tables

/// The two parts of an encoded table, ready for [chunkWrite].
class WarpEncodedTable {
  const WarpEncodedTable({
    required this.head,
    required this.points,
    required this.separateRgb,
  });

  /// Node counts and header: `[columns, rows, header...]`.
  final Uint8List head;

  /// The point bytes of every plane.
  final Uint8List points;

  /// True for a table with separate R, G and B planes (type code + 1).
  final bool separateRgb;
}

int _bytesPerPlane(WarpEncoding encoding, int columns, int rows) =>
    switch (encoding) {
      WarpEncoding.triple => columns * rows * 6,
      WarpEncoding.delta => rows * (4 + (columns - 1) * 2),
      WarpEncoding.word || WarpEncoding.fpga64 => columns * rows * 4,
    };

/// Reads a table block: the node counts, the header and the planes. The
/// header is kept as read. One or three planes are told apart by the block
/// length. Throws a [FormatException] when the length matches neither.
WarpTable decodeTable(Uint8List block, WarpEncoding encoding, int bits) {
  if (block.length < 2) {
    throw FormatException('block too short', warpBytesToHex(block));
  }
  final gx = block[0];
  final gy = block[1];
  int? planeCount;
  if (gx > 0 && gy > 0) {
    for (final n in const [1, 3]) {
      if (2 + warpHeaderLength(n) + n * _bytesPerPlane(encoding, gx, gy) ==
          block.length) {
        planeCount = n;
      }
    }
  }
  if (planeCount == null) {
    throw FormatException(
      'cannot match block length ${block.length} to $gx x $gy nodes with '
      '${encoding.name} encoding',
    );
  }
  final headerLength = warpHeaderLength(planeCount);
  final header = Uint8List.fromList(block.sublist(2, 2 + headerLength));
  var o = 2 + headerLength;
  final names = planeCount == 1 ? const ['W'] : const ['R', 'G', 'B'];
  final planes = <WarpPlane>[];
  for (final name in names) {
    final points = Float64List(gx * gy * 2);
    for (var y = 0; y < gy; y++) {
      if (encoding == WarpEncoding.delta) {
        var px = decodeWord(block, o, bits);
        var py = decodeWord(block, o + 2, bits);
        o += 4;
        points[(y * gx) * 2] = px;
        points[(y * gx) * 2 + 1] = py;
        for (var x = 1; x < gx; x++) {
          px += block[o] / 4;
          py += (block[o + 1] >= 128 ? block[o + 1] - 256 : block[o + 1]) / 4;
          o += 2;
          points[(y * gx + x) * 2] = px;
          points[(y * gx + x) * 2 + 1] = py;
        }
        continue;
      }
      for (var x = 0; x < gx; x++) {
        final i = (y * gx + x) * 2;
        switch (encoding) {
          case WarpEncoding.triple:
            points[i] = decodeTriple(block, o, bits);
            points[i + 1] = decodeTriple(block, o + 3, bits);
            o += 6;
          case WarpEncoding.word:
            points[i] = decodeWord(block, o, bits);
            points[i + 1] = decodeWord(block, o + 2, bits);
            o += 4;
          case WarpEncoding.fpga64:
            // The value wraps every 1024 px; continuity with the point on the
            // left (or the start of the row above) tells which turn it is on.
            final double nearX;
            final double nearY;
            if (x > 0) {
              nearX = points[i - 2];
              nearY = points[i - 1];
            } else if (y > 0) {
              nearX = points[((y - 1) * gx) * 2];
              nearY = points[((y - 1) * gx) * 2 + 1];
            } else {
              nearX = 0;
              nearY = 0;
            }
            points[i] = unwrapFpga64(decodeFpga64Raw(block, o), nearX);
            points[i + 1] = unwrapFpga64(decodeFpga64Raw(block, o + 2), nearY);
            o += 4;
          case WarpEncoding.delta:
            throw StateError('delta rows are decoded above');
        }
      }
    }
    planes.add(WarpPlane(name: name, columns: gx, rows: gy, points: points));
  }
  return WarpTable(columns: gx, rows: gy, header: header, planes: planes);
}

/// Packs [table]. The header is written as it is. The node counts are
/// single bytes, so a table has 1 to 255 columns and rows. Throws an
/// [ArgumentError] for a malformed table or a value the encoding cannot
/// hold, and for delta rows with a step that does not fit.
WarpEncodedTable encodeTable(WarpTable table, WarpEncoding encoding, int bits) {
  final n = table.planes.length;
  if (n != 1 && n != 3) {
    throw ArgumentError.value(n, 'planes', 'a table has 1 (W) or 3 (R, G, B)');
  }
  final gx = table.columns;
  final gy = table.rows;
  if (gx < 1 || gx > 255 || gy < 1 || gy > 255) {
    throw ArgumentError('node counts must fit one byte: $gx x $gy');
  }
  if (table.header.length != warpHeaderLength(n)) {
    throw ArgumentError(
      'header must be ${warpHeaderLength(n)} bytes for $n plane(s), '
      'got ${table.header.length}',
    );
  }
  final out = Uint8List(n * _bytesPerPlane(encoding, gx, gy));
  var o = 0;
  for (final plane in table.planes) {
    if (plane.columns != gx || plane.rows != gy) {
      throw ArgumentError(
        'plane ${plane.name} is ${plane.columns} x ${plane.rows}, '
        'expected $gx x $gy',
      );
    }
    for (var r = 0; r < gy; r++) {
      if (encoding == WarpEncoding.delta) {
        // Start point as words, then steps in 1/4 px with the rounding error
        // carried to the next step, exactly as the vendor software does.
        final scale = _wordScale(bits);
        final x0 = plane.x(0, r);
        final y0 = plane.y(0, r);
        encodeWord(x0, bits, out, o);
        encodeWord(y0, bits, out, o + 2);
        o += 4;
        var ax = warpRound(x0, scale) / scale;
        var ay = warpRound(y0, scale) / scale;
        for (var c = 1; c < gx; c++) {
          final dx = warpRound(plane.x(c, r) - ax, 4);
          final dy = warpRound(plane.y(c, r) - ay, 4);
          if (dx < 0 || dx > 255 || dy < -128 || dy > 127) {
            throw ArgumentError(
              'delta step (${dx / 4}, ${dy / 4}) px at column $c of row $r is '
              'out of range (dx 0 to 63.75, dy -32 to 31.75)',
            );
          }
          out[o] = dx;
          out[o + 1] = dy & 0xFF;
          o += 2;
          ax += dx / 4;
          ay += dy / 4;
        }
        continue;
      }
      for (var c = 0; c < gx; c++) {
        final x = plane.x(c, r);
        final y = plane.y(c, r);
        switch (encoding) {
          case WarpEncoding.triple:
            encodeTriple(x, bits, out, o);
            encodeTriple(y, bits, out, o + 3);
            o += 6;
          case WarpEncoding.word:
            encodeWord(x, bits, out, o);
            encodeWord(y, bits, out, o + 2);
            o += 4;
          case WarpEncoding.fpga64:
            encodeFpga64(x, out, o);
            encodeFpga64(y, out, o + 2);
            o += 4;
          case WarpEncoding.delta:
            throw StateError('delta rows are encoded above');
        }
      }
    }
  }
  return WarpEncodedTable(
    head: Uint8List.fromList([gx, gy, ...table.header]),
    points: out,
    separateRgb: n == 3,
  );
}

/// The WRITE frames for [table]: [encodeTable] and [chunkWrite], with the
/// method that goes with [encoding]. [type] comes from [warpTypeCode]; for a
/// table with three planes add the separate-colour flag there.
List<Uint8List> tableWriteFrames(
  WarpTable table, {
  required int type,
  required WarpEncoding encoding,
  required int bits,
}) {
  final encoded = encodeTable(table, encoding, bits);
  return chunkWrite(
    type,
    encoding == WarpEncoding.delta ? warpMethodDelta : warpMethodFull,
    encoded.head,
    encoded.points,
  );
}

// ---------------------------------------------------------------- limits

/// The outcome of [fpgaDeltaFits].
class WarpDeltaFit {
  const WarpDeltaFit.ok() : ok = true, column = -1, dx = 0, dy = 0;

  const WarpDeltaFit.fails({
    required this.column,
    required this.dx,
    required this.dy,
  }) : ok = false;

  final bool ok;

  /// The first column whose step does not fit (when not [ok]) and that step
  /// in px.
  final int column;
  final double dx;
  final double dy;
}

/// Whether every row of [plane] fits the delta format: each step to the right
/// is 0 to 63.75 px and each vertical step is -32 to 31.75 px. A negative
/// step (a folded row) does not fit either, so such rows are sent as words,
/// which cannot be misread. With [bits] the check also follows the rounding
/// of the encoder, so a plane that passes always encodes.
WarpDeltaFit fpgaDeltaFits(WarpPlane plane, {int? bits}) {
  for (var r = 0; r < plane.rows; r++) {
    double ax = 0;
    double ay = 0;
    if (bits != null) {
      final scale = _wordScale(bits);
      ax = warpRound(plane.x(0, r), scale) / scale;
      ay = warpRound(plane.y(0, r), scale) / scale;
    }
    for (var c = 1; c < plane.columns; c++) {
      final dx = plane.x(c, r) - plane.x(c - 1, r);
      final dy = plane.y(c, r) - plane.y(c - 1, r);
      var fits = !(dx > 63.75 || dx < 0 || dy < -32 || dy > 31.75);
      if (fits && bits != null) {
        final qx = warpRound(plane.x(c, r) - ax, 4);
        final qy = warpRound(plane.y(c, r) - ay, 4);
        fits = qx >= 0 && qx <= 255 && qy >= -128 && qy <= 127;
        ax += qx / 4;
        ay += qy / 4;
      }
      if (!fits) {
        return WarpDeltaFit.fails(column: c, dx: dx, dy: dy);
      }
    }
  }
  return const WarpDeltaFit.ok();
}

/// Row deltas when every plane fits them, otherwise absolute words.
WarpEncoding fpgaEncodingFor(WarpTable fpga, {int? bits}) =>
    fpga.planes.every((p) => fpgaDeltaFits(p, bits: bits).ok)
    ? WarpEncoding.delta
    : WarpEncoding.word;

/// The range of px values a table of this bit type can hold, from [min]
/// inclusive up to [max] exclusive. It is the intersection of what the full
/// table and the FPGA table can carry.
({double min, double max}) warpEncodableRange(int bits) => switch (bits) {
  4 => (min: -1024, max: 3072),
  3 => (min: -2048, max: 6144),
  _ => (min: 0, max: 16384),
};

/// The outcome of [checkWarpEncodable].
class WarpEncodableCheck {
  const WarpEncodableCheck({
    required this.badCount,
    this.firstColumn,
    this.firstRow,
    this.firstX,
    this.firstY,
  });

  /// How many nodes cannot be encoded.
  final int badCount;
  final int? firstColumn;
  final int? firstRow;
  final double? firstX;
  final double? firstY;

  bool get ok => badCount == 0;
}

/// Looks for nodes that the table format cannot hold. The encoders do not
/// clamp: a value out of range would silently wrap.
WarpEncodableCheck checkWarpEncodable(WarpTable table, int bits) {
  final range = warpEncodableRange(bits);
  var bad = 0;
  int? firstColumn;
  int? firstRow;
  double? firstX;
  double? firstY;
  for (final plane in table.planes) {
    for (var r = 0; r < plane.rows; r++) {
      for (var c = 0; c < plane.columns; c++) {
        final x = plane.x(c, r);
        final y = plane.y(c, r);
        if (math.min(x, y) < range.min || math.max(x, y) >= range.max) {
          bad++;
          if (firstColumn == null) {
            firstColumn = c;
            firstRow = r;
            firstX = x;
            firstY = y;
          }
        }
      }
    }
  }
  return WarpEncodableCheck(
    badCount: bad,
    firstColumn: firstColumn,
    firstRow: firstRow,
    firstX: firstX,
    firstY: firstY,
  );
}

/// Panasonic's own software reads bits-4 tables with the sign split at
/// -512 px, so values below it come out wrong there even though the
/// projector shows them correctly. Null when the bit type has no such limit.
int? warpLegacyReaderLimit(int bits) => bits == 4 ? -512 : null;

/// Whether some node is below [warpLegacyReaderLimit], so the vendor software
/// would show this memory as broken after a reload.
bool tableBreaksLegacyReader(WarpTable table, int bits) {
  final limit = warpLegacyReaderLimit(bits);
  if (limit == null) return false;
  for (final plane in table.planes) {
    for (final v in plane.points) {
      if (v < limit) return true;
    }
  }
  return false;
}
