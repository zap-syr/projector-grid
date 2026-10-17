import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/projector_node.dart';

/// What a projector card's header says, in order of precedence: a
/// projector that doesn't answer or refuses the login has no power or
/// shutter state worth showing.
enum CardHeaderTone { on, transition, standby, offline, loginFailed }

CardHeaderTone cardHeaderTone(ProjectorNode node) =>
    switch (node.connectionStatus) {
      ConnectionStatus.offline => CardHeaderTone.offline,
      ConnectionStatus.unauthorized => CardHeaderTone.loginFailed,
      _ => switch (node.powerStatus) {
        PowerStatus.on => CardHeaderTone.on,
        PowerStatus.standby => CardHeaderTone.standby,
        PowerStatus.turningOn ||
        PowerStatus.cooling => CardHeaderTone.transition,
      },
    };

/// The colours of the projector card and its quick status, from the theme
/// so both themes work: power like the projector's LED (green on, amber in
/// transition, red standby), the shutter green open and red closed while
/// the lamp is lit.
class ProjectorStatusStyle {
  ProjectorStatusStyle.of(BuildContext context)
    : _cs = Theme.of(context).colorScheme,
      _sc = AppStatusColors.of(context),
      _muted = AppText.of(context).tertiary;

  final ColorScheme _cs;
  final AppStatusColors _sc;
  final Color _muted;

  Color toneColor(CardHeaderTone tone) => switch (tone) {
    CardHeaderTone.on => _sc.success,
    CardHeaderTone.transition || CardHeaderTone.loginFailed => _sc.warning,
    CardHeaderTone.standby || CardHeaderTone.offline => _cs.error,
  };

  Color powerColor(PowerStatus power) => switch (power) {
    PowerStatus.on => _sc.success,
    PowerStatus.turningOn || PowerStatus.cooling => _sc.warning,
    PowerStatus.standby => _cs.error,
  };

  /// In standby the shutter decides nothing on screen, so it goes grey.
  Color shutterColor(ProjectorNode node) {
    if (node.powerStatus == PowerStatus.standby) return _muted;
    return node.shutterStatus == ShutterStatus.open ? _sc.success : _cs.error;
  }

  static IconData shutterIcon(ShutterStatus shutter) =>
      shutter == ShutterStatus.open ? Icons.visibility : Icons.visibility_off;

  static String powerLabel(PowerStatus power) => switch (power) {
    PowerStatus.on => 'On',
    PowerStatus.standby => 'Standby',
    PowerStatus.turningOn => 'Warming up',
    PowerStatus.cooling => 'Cooling',
  };

  static String shutterLabel(ShutterStatus shutter) =>
      shutter == ShutterStatus.open ? 'Open' : 'Closed';
}

/// The group band's fill: the group colour mixed 55 % into the card, so a
/// red group doesn't read as a fault and a green one as "on" (owner,
/// 2026-10-15).
Color groupBandColor(Color card, Color group) => Color.lerp(card, group, 0.55)!;

/// Text on [band], chosen from the mixed colour rather than the group
/// colour: black on a muted band of a light group colour was unreadable.
Color groupBandTextColor(Color band) =>
    ThemeData.estimateBrightnessForColor(band) == Brightness.dark
    ? const Color(0xFFF4F5F8)
    : const Color(0xFF15171B);
