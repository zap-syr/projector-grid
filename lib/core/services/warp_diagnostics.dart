import 'dart:typed_data';

import '../../features/workspace/domain/warp_codec.dart';
import '../../features/workspace/domain/warp_model_caps.dart';
import 'warp_transfer.dart';

// The read-only survey of a projector's free grid memories (PC-1 to PC-3),
// for a model whose table format the app does not understand: what it
// answers, byte for byte, so the format can be worked out from a file. It
// only asks. Nothing here writes, saves, shows a preview or an overlay.

/// An error of one call, kept as it was reported.
class WarpCallError {
  const WarpCallError({required this.type, required this.message, this.code});

  /// Wraps whatever a call threw.
  factory WarpCallError.from(Object error) => switch (error) {
    WarpProtocolException() => WarpCallError(
      type: 'WarpProtocolException',
      message: error.message,
      code: error.code,
    ),
    WarpTransportException() => WarpCallError(
      type: 'WarpTransportException',
      message: error.message,
    ),
    _ => WarpCallError(type: error.runtimeType.toString(), message: '$error'),
  };

  /// The class of the exception.
  final String type;

  /// The code of an `FF xx` error frame, when there was one.
  final int? code;

  final String message;

  @override
  String toString() =>
      '$type: $message${code == null ? '' : ' (code 0x${_hex2(code!)})'}';
}

String _hex2(int byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0');

/// One call on the link, as it happened.
sealed class WarpLinkCall {
  const WarpLinkCall(this.at, this.error);

  /// When the call was started.
  final DateTime at;

  /// Set when the call threw instead of returning.
  final WarpCallError? error;
}

/// An ASCII command and its reply: null when the projector did not reply.
class WarpAsciiCall extends WarpLinkCall {
  const WarpAsciiCall(super.at, this.command, this.reply, [super.error]);

  final String command;
  final String? reply;
}

/// A binary frame and the reply frame, exactly as the link returned it; the
/// reply is null when the call threw.
class WarpBinaryCall extends WarpLinkCall {
  const WarpBinaryCall(super.at, this.sent, this.reply, [super.error]);

  final Uint8List sent;
  final Uint8List? reply;
}

/// A [WarpLink] that passes every call on and keeps a copy of it, in order:
/// the reply of a binary call is the frame the link returned, so a read that
/// fails half way (checksum, wrong type, too many packets) still has every
/// packet that came back.
class RecordingWarpLink implements WarpLink {
  RecordingWarpLink(this.inner, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WarpLink inner;
  final DateTime Function() _clock;
  final List<WarpLinkCall> _calls = [];

  /// Every call so far, oldest first.
  List<WarpLinkCall> get calls => List.unmodifiable(_calls);

  @override
  Future<Uint8List> binary(Uint8List frame) async {
    final at = _clock();
    final sent = Uint8List.fromList(frame);
    try {
      final reply = await inner.binary(frame);
      _calls.add(WarpBinaryCall(at, sent, Uint8List.fromList(reply)));
      return reply;
    } catch (e) {
      _calls.add(WarpBinaryCall(at, sent, null, WarpCallError.from(e)));
      rethrow;
    }
  }

  @override
  Future<String?> ascii(String command) async {
    final at = _clock();
    try {
      final reply = await inner.ascii(command);
      _calls.add(WarpAsciiCall(at, command, reply));
      return reply;
    } catch (e) {
      _calls.add(WarpAsciiCall(at, command, null, WarpCallError.from(e)));
      rethrow;
    }
  }
}

/// A `QVX:` query and what came of it.
class WarpAsciiStep {
  const WarpAsciiStep(this.command, {this.reply, this.error});

  final String command;

  /// The reply without its `00` prefix, `ERxxx` codes included; null for no
  /// reply (or for [error]).
  final String? reply;

  final WarpCallError? error;

  bool get noReply => reply == null && error == null;
}

/// The READ of one memory's full table.
class WarpReadStep {
  const WarpReadStep({
    required this.type,
    required this.packets,
    this.result,
    this.error,
  });

  /// The type code that was read.
  final int type;

  /// Every frame the read sent and the reply to each, in order.
  final List<WarpBinaryCall> packets;

  /// What the read made of the packets; null when it failed ([error]).
  final WarpReadResult? result;

  final WarpCallError? error;
}

/// What the survey found in one memory.
class WarpMemoryDiagnostics {
  const WarpMemoryDiagnostics({
    required this.slot,
    required this.stored,
    required this.read,
    required this.readSkipped,
    required this.grid,
  });

  final WarpSlot slot;

  /// 1 to 3.
  int get number => slot.offset ~/ 2;

  /// `QVX:GDTS1=n`: when the memory was stored.
  final WarpAsciiStep stored;

  /// Null when the READ was skipped, see [readSkipped].
  final WarpReadStep? read;

  /// Why there is no READ: set exactly when [read] is null.
  final String? readSkipped;

  /// `QVX:GGNS1=n`: the numbers of control points.
  final WarpAsciiStep grid;
}

/// Everything the survey of one projector found.
class WarpDiagnosticsResult {
  const WarpDiagnosticsResult({
    required this.mids,
    required this.modelId,
    required this.caps,
    required this.mode,
    required this.memories,
    required this.calls,
  });

  /// `QVX:MIDS1`.
  final WarpAsciiStep mids;

  /// The parameter file id the reply names (`0018_00_30`); null when there was
  /// no usable reply.
  final String? modelId;

  /// The row of [modelId] in the app's table; null when it is not there.
  final WarpModelCaps? caps;

  /// `QVX:GMMI0`.
  final WarpAsciiStep mode;

  /// PC-1, PC-2, PC-3, in that order.
  final List<WarpMemoryDiagnostics> memories;

  /// Every call on the link, in order, with its time.
  final List<WarpLinkCall> calls;
}

const List<WarpSlot> _memorySlots = [WarpSlot.pc1, WarpSlot.pc2, WarpSlot.pc3];

Future<WarpAsciiStep> _ask(WarpLink link, String command) async {
  try {
    return WarpAsciiStep(command, reply: await link.ascii(command));
  } catch (e) {
    return WarpAsciiStep(command, error: WarpCallError.from(e));
  }
}

String _skipReason(WarpAsciiStep mids, String? modelId) {
  if (mids.error != null || mids.reply == null) {
    return 'the model query got no reply, so the table type is not known';
  }
  if (modelId == null) {
    return 'the model reply could not be read, so the table type is not known';
  }
  return "the model $modelId is not in the app's table, so the table type is "
      'not known';
}

/// Surveys the free grid memories of the projector behind [link]: the model
/// id (`QVX:MIDS1`), the geometry mode (`QVX:GMMI0`), then for PC-1, PC-2
/// and PC-3 the stored time (`QVX:GDTS1=n`), the READ of the full table and
/// the numbers of control points (`QVX:GGNS1=n`).
///
/// Strictly read-only and one call after the other. Every step catches its
/// own failure and records it, so one bad memory does not hide the others.
/// The READ is skipped when the model's row is not in the app's table: its
/// type code comes from the row.
Future<WarpDiagnosticsResult> runWarpDiagnostics(
  WarpLink link, {
  DateTime Function()? clock,
}) async {
  final recorder = RecordingWarpLink(link, clock: clock);

  final mids = await _ask(recorder, 'QVX:MIDS1');
  final midsReply = mids.reply;
  final modelId = midsReply == null ? null : warpModelIdFromMids(midsReply);
  final caps = modelId == null ? null : lookupWarpModelCaps(modelId);
  final mode = await _ask(recorder, 'QVX:GMMI0');

  final memories = <WarpMemoryDiagnostics>[];
  for (final slot in _memorySlots) {
    final n = slot.offset ~/ 2;
    final stored = await _ask(recorder, 'QVX:GDTS1=$n');

    WarpReadStep? read;
    String? skipped;
    if (caps == null) {
      skipped = _skipReason(mids, modelId);
    } else {
      final type = warpTypeCode(caps.fullBase, slot);
      final start = recorder.calls.length;
      WarpReadResult? result;
      WarpCallError? error;
      try {
        result = await readWarpBlock(recorder, type: type);
      } catch (e) {
        error = WarpCallError.from(e);
      }
      read = WarpReadStep(
        type: type,
        packets: recorder.calls
            .skip(start)
            .whereType<WarpBinaryCall>()
            .toList(),
        result: result,
        error: error,
      );
    }

    final grid = await _ask(recorder, 'QVX:GGNS1=$n');
    memories.add(
      WarpMemoryDiagnostics(
        slot: slot,
        stored: stored,
        read: read,
        readSkipped: skipped,
        grid: grid,
      ),
    );
  }

  return WarpDiagnosticsResult(
    mids: mids,
    modelId: modelId,
    caps: caps,
    mode: mode,
    memories: memories,
    calls: recorder.calls,
  );
}
