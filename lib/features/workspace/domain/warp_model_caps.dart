import 'warp_model_caps_table.dart';
import 'warp_table.dart';

export 'warp_model_caps_table.dart' show warpModelCapsTable;

/// What the free-form warp memories (PC-1 to PC-3) need to know about one
/// projector model, taken from the parameter file Panasonic ships for it.
/// The rows are generated into `warp_model_caps_table.dart`.
///
/// [bits] is never inferred: a wrong value silently scales a table by 2 to
/// 16 times, so it always comes from the row.
class WarpModelCaps {
  const WarpModelCaps({
    required this.id,
    required this.bits,
    required this.panelWidth,
    required this.panelHeight,
    required this.viewWidth,
    required this.viewHeight,
    required this.tableColumns,
    required this.tableRows,
    required this.stepX,
    required this.stepY,
    required this.movableRangeX,
    required this.movableRangeY,
    required this.is4kFpga,
    required this.isGcx2,
    required this.isScx4,
    required this.isNoInverse,
    required this.cursorSelect,
    required this.displayAdjPoints,
  });

  /// The parameter file id, `<model>_<variant>_<panel>` in lower case, for
  /// example `001c_00_26`.
  final String id;

  /// How coordinates are scaled in a table: 4, 3 or 2.
  final int bits;

  /// The panel the control points are laid out on.
  final int panelWidth;
  final int panelHeight;

  /// The size of the displayed image, which can differ from the panel.
  final int viewWidth;
  final int viewHeight;

  /// Nodes of the dense table and their nominal distance in panel pixels.
  final int tableColumns;
  final int tableRows;
  final int stepX;
  final int stepY;

  /// How far a point may leave the panel on each side.
  final int movableRangeX;
  final int movableRangeY;

  final bool is4kFpga;
  final bool isGcx2;
  final bool isScx4;
  final bool isNoInverse;
  final int cursorSelect;
  final int displayAdjPoints;

  /// Models with a 4K FPGA or a GCX2 use the 0x70 / 0x80 table types, the
  /// others 0x40 / 0x50.
  bool get _wideTables => is4kFpga || isGcx2;

  /// Type code base of the full table.
  int get fullBase => _wideTables ? 0x70 : 0x40;

  /// Type code base of the FPGA (delta) table and of the live preview.
  int get fpgaBase => _wideTables ? 0x80 : 0x50;

  WarpGeometry get geometry => WarpGeometry(
    panelWidth: panelWidth,
    panelHeight: panelHeight,
    columns: tableColumns,
    rows: tableRows,
    stepX: stepX,
    stepY: stepY,
  );
}

final RegExp _midsReply = RegExp(
  r'^(?:MIDS1=)?(\d{1,4}):([0-9A-Za-z]{2}):([0-9A-Za-z]{2})$',
  caseSensitive: false,
);

/// The parameter file id for a `QVX:MIDS1` reply (`MIDS1=XXXX:YY:ZZ`). XXXX
/// is decimal and becomes four lower-case hex digits; YY and ZZ select the
/// variant and are only lower-cased. Null when [reply] is not a MIDS1 reply.
String? warpModelIdFromMids(String reply) {
  final m = _midsReply.firstMatch(reply.trim());
  if (m == null) return null;
  final id = int.parse(m.group(1)!).toRadixString(16).padLeft(4, '0');
  return '${id}_${m.group(2)!.toLowerCase()}_${m.group(3)!.toLowerCase()}';
}

final RegExp _binaryModelInfo = RegExp(
  '020185([0-9A-F]{2})([0-9A-F]{2})',
  caseSensitive: false,
);

/// The parameter file id for the reply of the binary model query that older
/// models answer instead (`02 01 85 <id> <panel> 03`, hex). The 2-character
/// ids are only lower-cased, never converted, and the variant is `00`. [hex]
/// may carry the `01` reply prefix. Null when the marker is missing.
String? warpModelIdFromBinaryModelInfo(String hex) {
  final m = _binaryModelInfo.firstMatch(hex.replaceAll(RegExp(r'\s+'), ''));
  if (m == null) return null;
  return '${m.group(1)!.toLowerCase()}_00_${m.group(2)!.toLowerCase()}';
}

/// The row for a parameter file id, or null when the model is not in the
/// table.
WarpModelCaps? lookupWarpModelCaps(String id) => warpModelCapsTable[id];

WarpModelCaps? warpModelCapsFromMids(String reply) {
  final id = warpModelIdFromMids(reply);
  return id == null ? null : lookupWarpModelCaps(id);
}

WarpModelCaps? warpModelCapsFromBinaryModelInfo(String hex) {
  final id = warpModelIdFromBinaryModelInfo(hex);
  return id == null ? null : lookupWarpModelCaps(id);
}
