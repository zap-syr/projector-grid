import 'projector_group.dart';

/// Soft cap on group names: long names get ellipsized on the card's group
/// band anyway, and this keeps the generated OSC address reasonable.
const int maxGroupNameLength = 24;

/// The OSC address a group answers on, derived from its name.
String groupOscAddress(String name) =>
    '/group/${name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

/// Why [name] can't be used for a group, or null when it can. [exceptId] is
/// the group being renamed, which may keep its own name.
String? groupNameError(
  String name,
  Iterable<ProjectorGroup> groups, {
  String? exceptId,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Group name is required';
  final lower = trimmed.toLowerCase();
  final osc = groupOscAddress(trimmed);
  final taken = groups.any(
    (g) =>
        g.id != exceptId &&
        (g.name.toLowerCase() == lower || g.oscAddress == osc),
  );
  return taken ? 'A group with this name already exists' : null;
}
