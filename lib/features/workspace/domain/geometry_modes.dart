/// Geometry Correction modes and the register lists their Reset buttons
/// write, kept out of the dialog so they can be unit-tested.
library;

import 'geometry_values.dart';

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
  corner;

  String get label => switch (this) {
    off => 'Off',
    keystone => 'Keystone',
    curved => 'Curved Correction',
    corner => 'Corner Correction',
  };

  /// For mode tiles in a narrow window; [label] goes into the tooltip.
  String get shortLabel => switch (this) {
    off => 'Off',
    keystone => 'Keystone',
    curved => 'Curved',
    corner => 'Corner',
  };

  /// `GMMI0` value.
  String get protocolValue => switch (this) {
    off => '+00000',
    keystone => '+00001',
    curved => '+00002',
    corner => '+00010',
  };

  /// How many registers the first load of the mode reads, for the loading
  /// line ("once the 15 values are read").
  int get valueCount => switch (this) {
    off => 0,
    keystone => 5,
    curved => 8,
    corner => 15,
  };

  static GeometryMode fromProtocol(String value) => switch (value.trim()) {
    '+00001' => keystone,
    '+00002' => curved,
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
