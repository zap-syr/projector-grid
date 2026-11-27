/// Geometry Correction modes and the register lists their Reset buttons
/// write, kept out of the dialog so they can be unit-tested.
library;

import 'geometry_values.dart';
import 'warp_codec.dart';

/// The Off state's Quad Pixel Drive note by tier (§7.2), after the bold
/// *Quad Pixel Drive*; null when the model has none.
String? quadPixelDriveNote(QuadPixelTier tier) => switch (tier) {
  QuadPixelTier.a =>
    'turns on by itself when you choose a mode. This model needs it for '
        'geometry correction, and Corner Correction gets a wider inward range.',
  // Their inward limits are unconfirmed, so they stay standard.
  QuadPixelTier.b => 'turns on by itself when you choose a mode.',
  QuadPixelTier.none => null,
};

enum GeometryMode {
  off,
  keystone,
  curved,
  corner,

  /// The free-form warp memories PC-1 to PC-3 (the Free grid).
  pc1,
  pc2,
  pc3;

  /// The modes the dialog shows as tiles, in order. The PC memories get one
  /// tile of their own, so they are not listed here.
  static const tileModes = [off, keystone, curved, corner];

  String get label => switch (this) {
    off => 'Off',
    keystone => 'Keystone',
    curved => 'Curved Correction',
    corner => 'Corner Correction',
    pc1 => 'PC-1',
    pc2 => 'PC-2',
    pc3 => 'PC-3',
  };

  /// For mode tiles in a narrow window; [label] goes into the tooltip.
  String get shortLabel => switch (this) {
    off => 'Off',
    keystone => 'Keystone',
    curved => 'Curved',
    corner => 'Corner',
    pc1 => 'PC-1',
    pc2 => 'PC-2',
    pc3 => 'PC-3',
  };

  /// `GMMI0` value.
  String get protocolValue => switch (this) {
    off => '+00000',
    keystone => '+00001',
    curved => '+00002',
    corner => '+00010',
    pc1 => '+00003',
    pc2 => '+00004',
    pc3 => '+00005',
  };

  /// How many registers the first load of the mode reads, for the loading
  /// line ("once the 15 values are read").
  int get valueCount => switch (this) {
    off => 0,
    keystone => 5,
    curved => 8,
    corner => 15,
    pc1 || pc2 || pc3 => 0,
  };

  /// True for a free-form warp memory (PC-1 to PC-3).
  bool get isFreeGrid => warpSlot != null;

  /// The warp memory a PC mode shows; null for the other modes.
  WarpSlot? get warpSlot => switch (this) {
    pc1 => WarpSlot.pc1,
    pc2 => WarpSlot.pc2,
    pc3 => WarpSlot.pc3,
    off || keystone || curved || corner => null,
  };

  /// The mode that shows [slot]; the live RAM has none.
  static GeometryMode forWarpSlot(WarpSlot slot) => switch (slot) {
    WarpSlot.pc1 => pc1,
    WarpSlot.pc2 => pc2,
    WarpSlot.pc3 => pc3,
    WarpSlot.ram => throw ArgumentError.value(
      slot,
      'slot',
      'a memory PC-1 to PC-3 is needed',
    ),
  };

  static GeometryMode fromProtocol(String value) => switch (value.trim()) {
    '+00001' => keystone,
    '+00002' => curved,
    '+00003' => pc1,
    '+00004' => pc2,
    '+00005' => pc3,
    '+00010' => corner,
    _ => off,
  };
}

/// What Reset in Keystone writes 0 to, in order: `(register, isDegrees)`.
/// Throw ratio stays: it describes the lens, not the correction.
const keystoneResetRegisters = [
  ('GMKS8', true),
  ('GMKS9', true),
  ('GMKI4', false),
  ('GMKI7', false),
];

/// What Reset in Curved Correction writes 0 to; Throw ratio and Maintain
/// aspect ratio stay.
const curvedResetRegisters = [
  ('GMCI2', false),
  ('GMCI3', false),
  ('GMCI6', false),
  ('GMCI7', false),
  ('GMCS8', true),
  ('GMCS9', true),
];
