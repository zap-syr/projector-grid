import 'dart:typed_data';

import '../../../core/services/warp_diagnostics.dart';
import '../../../core/services/warp_transfer.dart';
import 'warp_codec.dart';
import 'warp_model_caps.dart';
import 'warp_session_state.dart';
import 'warp_table.dart';

// The text of a free grid diagnostics file. Plain ASCII, one fact per line,
// every line starting with a stable key so the file can be grepped and read
// by a person alike. Pure: the clock and the app version come in as
// arguments.

/// Bytes per line of a hex dump.
const int warpDiagnosticsHexBytesPerLine = 32;

/// [bytes] as upper-case hex pairs separated by a space, wrapped at
/// [perLine] bytes, every line indented by [indent] spaces and joined by
/// `\n` (no trailing newline). Empty for no bytes.
String warpDiagnosticsHex(
  List<int> bytes, {
  int indent = 4,
  int perLine = warpDiagnosticsHexBytesPerLine,
}) {
  final pad = ' ' * indent;
  final lines = <String>[];
  for (var i = 0; i < bytes.length; i += perLine) {
    final end = i + perLine < bytes.length ? i + perLine : bytes.length;
    lines.add(
      pad +
          bytes
              .sublist(i, end)
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' '),
    );
  }
  return lines.join('\n');
}

/// `warp-diagnostics-<model>-<ip>-<yyyy-MM-dd>.txt`, the date in local time.
/// Model and IP keep only `A-Z a-z 0-9 . -`; every run of other characters
/// becomes one `-`, and an empty result becomes `unknown`.
String warpDiagnosticsFileName({
  required String model,
  required String ip,
  required DateTime at,
}) {
  final local = at.toLocal();
  final date =
      '${_pad(local.year, 4)}-${_pad(local.month, 2)}-${_pad(local.day, 2)}';
  return 'warp-diagnostics-${_fileSafe(model)}-${_fileSafe(ip)}-$date.txt';
}

String _fileSafe(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[^A-Za-z0-9.-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'unknown' : cleaned;
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

String _stamp(DateTime t) =>
    '${_pad(t.year, 4)}-${_pad(t.month, 2)}-${_pad(t.day, 2)} '
    '${_pad(t.hour, 2)}:${_pad(t.minute, 2)}:${_pad(t.second, 2)}';

String _hex(int value) => '0x${value.toRadixString(16)}';

String _hex2(int value) =>
    '0x${value.toRadixString(16).toUpperCase().padLeft(2, '0')}';

String _answer(WarpAsciiStep step) {
  final error = step.error;
  if (error != null) return 'error: $error';
  return step.reply ?? 'no reply';
}

/// What the app knows of the model row, on one line.
String _rowLine(WarpModelCaps c) =>
    '${c.id}, bits ${c.bits}, panel ${c.panelWidth} x ${c.panelHeight}, '
    'view ${c.viewWidth} x ${c.viewHeight}, '
    'table ${c.tableColumns} x ${c.tableRows}, '
    'step ${c.stepX} x ${c.stepY}, '
    'movable range ${c.movableRangeX} x ${c.movableRangeY}, '
    'flags 4k_fpga=${_flag(c.is4kFpga)} gcx2=${_flag(c.isGcx2)} '
    'scx4=${_flag(c.isScx4)} no_inverse=${_flag(c.isNoInverse)}, '
    'cursor_select ${c.cursorSelect}, '
    'display_adj_points ${c.displayAdjPoints}, '
    'full table type base ${_hex2(c.fullBase)}, '
    'fpga table type base ${_hex2(c.fpgaBase)}';

String _flag(bool value) => value ? '1' : '0';

/// Why the free grid is or is not available for the model, in the words of
/// the app's own check ([warpModelSupported]).
String _statusLine(WarpModelCaps? caps) {
  if (caps == null) {
    return "unknown, the model is not in the app's table";
  }
  if (warpModelSupported(caps)) return 'supported';
  final neutral = identityWarpTable(caps.geometry);
  final check = checkWarpEncodable(neutral, caps.bits);
  final nodes = neutral.columns * neutral.rows * neutral.planes.length;
  return "not supported, the neutral table does not fit the row's bits "
      '(${check.badCount} of $nodes nodes out of range for ${caps.bits} bits)';
}

String _readSummary(WarpReadStep read) {
  final result = read.result;
  final replies = read.packets.where((p) => p.reply != null).length;
  return switch (result) {
    WarpBlockRead(:final block, :final method) =>
      'block of ${block.length} bytes in $replies packet(s), '
          'method ${_hex2(method)}',
    WarpBlockNotAvailable() => 'not available (error frame FF 8B)',
    WarpBlockEmpty() => 'empty (nothing stored)',
    null => 'failed',
  };
}

void _writeRead(StringBuffer out, WarpReadStep read) {
  out.writeln('READ type ${_hex(read.type)}: ${_readSummary(read)}');
  for (var i = 0; i < read.packets.length; i++) {
    final packet = read.packets[i];
    final n = i + 1;
    _writePacket(out, 'packet $n sent', packet.sent);
    final reply = packet.reply;
    if (reply == null) {
      out.writeln(
        '  packet $n reply: none, error: '
        '${packet.error ?? 'no reply'}',
      );
    } else {
      _writePacket(out, 'packet $n reply', reply);
    }
  }
  final error = read.error;
  if (error != null) out.writeln('  error: $error');
}

void _writePacket(StringBuffer out, String key, Uint8List bytes) {
  out.writeln('  $key (${bytes.length} bytes):');
  out.writeln(warpDiagnosticsHex(bytes));
}

/// The diagnostics file for [result].
///
/// [projectorName] is the model as the projector reports it (the name of the
/// card), [serialNumber] what polling found (`-` or empty when it did not),
/// [appVersion] null when it could not be read. [createdAt] is shown in local
/// time and UTC. The app has no firmware version for a projector, so the
/// line says so.
String buildWarpDiagnosticsReport({
  required WarpDiagnosticsResult result,
  required String projectorName,
  required String ip,
  required int port,
  required String serialNumber,
  required String? appVersion,
  required DateTime createdAt,
}) {
  final out = StringBuffer();
  final serial = serialNumber.isEmpty || serialNumber == '-'
      ? 'not known'
      : serialNumber;
  final caps = result.caps;

  out.writeln('Projector Grid free grid diagnostics');
  out.writeln(
    'Created: ${_stamp(createdAt.toLocal())} local, '
    '${_stamp(createdAt.toUtc())} UTC',
  );
  out.writeln('App version: ${appVersion ?? 'not known'}');
  out.writeln('Projector: $projectorName ($ip), port $port');
  out.writeln('Serial number: $serial');
  out.writeln('Firmware: not read by this app');
  out.writeln('Model id (QVX:MIDS1): ${_answer(result.mids)}');
  out.writeln('Model file id: ${result.modelId ?? 'not known'}');
  out.writeln(
    'Model row: ${caps == null ? "not in the app's table" : _rowLine(caps)}',
  );
  out.writeln('Free grid status: ${_statusLine(caps)}');
  out.writeln('Mode (QVX:GMMI0): ${_answer(result.mode)}');

  for (final memory in result.memories) {
    out.writeln();
    out.writeln('[PC-${memory.number}]');
    out.writeln('${memory.stored.command} -> ${_answer(memory.stored)}');
    final read = memory.read;
    if (read == null) {
      out.writeln('READ: skipped, ${memory.readSkipped}');
    } else {
      _writeRead(out, read);
    }
    out.writeln('${memory.grid.command} -> ${_answer(memory.grid)}');
  }
  return out.toString();
}
