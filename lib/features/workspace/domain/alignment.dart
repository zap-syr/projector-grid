/// Pure rules for Alignment mode (ROADMAP_PLAN.md §3.2): pattern presets,
/// each projector's role, and what that role puts on screen.
library;

import 'card_layout.dart';
import 'projector_node.dart';
import 'test_patterns.dart';

const _crossHatches = [
  'OTS:07',
  'OTS:70',
  'OTS:71',
  'OTS:72',
  'OTS:73',
  'OTS:74',
  'OTS:75',
];
const _solidColors = [
  'OTS:01',
  'OTS:02',
  'OTS:22',
  'OTS:23',
  'OTS:24',
  'OTS:28',
  'OTS:29',
  'OTS:30',
];

/// Picks the task, which filters the pattern dropdowns and sets defaults.
enum AlignmentPreset {
  geometry('Geometry', _crossHatches, 'OTS:07', 'OTS:70'),
  color('Color', _solidColors, 'OTS:01', null),
  custom('Custom', null, null, null);

  const AlignmentPreset(
    this.label,
    this._patterns,
    this.defaultFocused,
    this.defaultOthers,
  );

  final String label;
  final List<String>? _patterns;

  /// Null on [custom]: it keeps whatever is currently chosen.
  final String? defaultFocused;

  /// Null means "same as focused".
  final String? defaultOthers;

  List<String> get patterns => _patterns ?? kTestPatternLabels.keys.toList();
}

enum AlignmentRole {
  /// The projector being adjusted: shutter open, Focused pattern.
  focused,

  /// Open next to the focused one (neighbour or Show All): Others pattern.
  shown,

  /// In scope but not shown: shutter closed.
  closed,
}

/// Role of every node in [scope] (ids, in any order). Ids in [scope] missing
/// from [nodes] are ignored.
Map<String, AlignmentRole> alignmentRoles({
  required List<ProjectorNode> nodes,
  required Set<String> scope,
  required String focusedId,
  required bool showAll,
  required bool showNeighbours,
  required bool includeDiagonals,
  required Set<String> manualNeighbours,
}) {
  final inScope = nodes.where((n) => scope.contains(n.id)).toList();
  final focused = inScope.where((n) => n.id == focusedId).firstOrNull;
  final shown = <String>{};
  if (focused != null && !showAll && showNeighbours) {
    shown.addAll(neighbours(focused, inScope, diagonals: includeDiagonals));
  }
  // Manual picks toggle: a Ctrl+click on an auto-detected neighbour hides it.
  final open = shown.difference(manualNeighbours)
    ..addAll(manualNeighbours.difference(shown));
  return {
    for (final n in inScope)
      n.id: n.id == focusedId
          ? AlignmentRole.focused
          : (showAll || open.contains(n.id))
          ? AlignmentRole.shown
          : AlignmentRole.closed,
  };
}

/// What a projector should show. [pattern] null = leave the pattern alone
/// (a closed shutter hides it anyway).
typedef ProjectorOutput = ({bool open, String? pattern});

ProjectorOutput outputFor(
  AlignmentRole role, {
  required String focusedPattern,
  required String? othersPattern,
}) => switch (role) {
  AlignmentRole.focused => (open: true, pattern: focusedPattern),
  AlignmentRole.shown => (open: true, pattern: othersPattern ?? focusedPattern),
  AlignmentRole.closed => (open: false, pattern: null),
};

/// Commands that take a projector from [current] to [target], pattern first
/// so an opening shutter never flashes the old pattern.
List<String> commandsFor(ProjectorOutput current, ProjectorOutput target) => [
  if (target.pattern != null && target.pattern != current.pattern)
    target.pattern!,
  if (target.open != current.open) target.open ? 'OSH:0' : 'OSH:1',
];

/// Shutter fade-in / fade-out times as the projector reports them (`2.0`).
typedef ShutterFade = ({String fadeIn, String fadeOut});

/// `SEFS1=2.0` → `2.0`; null for a failed query or garbage.
String? parseShutterFade(String? raw) {
  final value = raw?.split('=').last.trim();
  if (value == null || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
  return value;
}

bool isZeroFade(String value) => double.tryParse(value) == 0;
