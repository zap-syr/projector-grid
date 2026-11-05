import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/lens_commands.dart';
import 'selection_provider.dart';
import 'workspace_provider.dart';

part 'selected_lens_lock_provider.g.dart';

/// Lens lock of the selection, for the Lens shift card's lock button and the
/// state of its lens buttons. Record equality dedupes the telemetry ticks
/// and drags that leave it unchanged, so the card doesn't rebuild on them.
@riverpod
({LensLockState state, int locked, int total}) selectedLensLock(Ref ref) {
  final selected = ref.watch(selectionProvider);
  final flags = [
    for (final n in ref.watch(workspaceProvider))
      if (selected.contains(n.id)) n.lensLocked,
  ];
  return (
    state: lensLockState(flags),
    locked: flags.where((l) => l).length,
    total: flags.length,
  );
}
