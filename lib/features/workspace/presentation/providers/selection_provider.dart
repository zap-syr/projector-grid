import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection_provider.g.dart';

/// Holds the set of currently-selected projector node IDs.
///
/// This is pure UI state — it deliberately lives outside [ProjectorNode] so
/// that selecting/deselecting nodes doesn't rebuild the node list, doesn't
/// get captured in undo/redo snapshots, and never touches project-file
/// serialization.
@riverpod
class SelectionNotifier extends _$SelectionNotifier {
  @override
  Set<String> build() => {};

  void set(Set<String> ids) => state = ids;

  void selectOnly(String id) => state = {id};

  void toggle(String id) {
    final next = Set<String>.of(state);
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = {};
  }

  void removeIds(Iterable<String> ids) {
    if (state.isEmpty) return;
    state = state.difference(ids.toSet());
  }
}
