import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'workspace_provider.dart';

part 'edit_history_status_provider.g.dart';

/// Undo/redo availability for `TopMenuBar`'s Edit menu.
///
/// `canUndo`/`canRedo` live on `WorkspaceNotifier`'s private undo/redo stacks,
/// not in its public `state` list, so this can't be a `.select()` on
/// `workspaceProvider`. Every stack mutation (`_saveSnapshot`, `undo`, `redo`)
/// happens to reassign `state` in the same method, so watching the list here
/// is enough to recompute at the right times — record equality then dedupes
/// away the many state changes (e.g. telemetry polling, card drags) that
/// leave undo/redo availability unchanged, so widgets watching this provider
/// don't rebuild for those.
@riverpod
({bool canUndo, bool canRedo}) editHistoryStatus(Ref ref) {
  ref.watch(workspaceProvider);
  final notifier = ref.watch(workspaceProvider.notifier);
  return (canUndo: notifier.canUndo, canRedo: notifier.canRedo);
}
