import 'dart:typed_data';

import '../../../core/services/warp_transfer.dart';
import 'warp_codec.dart';
import 'warp_control_grid.dart';
import 'warp_model_caps.dart';
import 'warp_table.dart';

/// Where a free grid edit session is.
enum WarpSessionPhase {
  /// Asking the projector which model it is.
  detecting,

  /// The projector cannot use the free grid; see
  /// [WarpSessionState.unsupportedReason]. Nothing is ever written.
  unsupported,

  /// Reading a memory.
  loading,

  /// A memory is loaded and no transfer is running.
  ready,

  /// A Store, Restore or Reset is being written; see
  /// [WarpSessionState.progressDone].
  storing,

  /// The last read or write failed; [WarpSessionState.failureMessage] says
  /// how. The session stays usable: Reload is allowed.
  failed,
}

/// Why a session is [WarpSessionPhase.unsupported].
enum WarpUnsupportedReason {
  /// No reply to the model query, or the model is not in the table.
  noModel,

  /// The model has no stored free grid memories: its first read answered
  /// "not available" although the model does not skip that table.
  notAvailable,
}

/// Why a loaded memory cannot be edited.
enum WarpReadOnlyReason {
  /// The stored table does not determine a grid of the memory's size (it
  /// ends short of the panel), so no control points can be recovered.
  fit,

  /// The memory holds one table per colour; the editor shows one plane.
  colourPlanes,
}

/// The state of one projector's free grid edit session. Immutable; the
/// provider replaces it as a whole.
class WarpSessionState {
  const WarpSessionState({
    this.phase = WarpSessionPhase.detecting,
    this.unsupportedReason,
    this.caps,
    this.slot = WarpSlot.pc1,
    this.storedAt,
    this.gridCounts = warpDefaultGridCounts,
    this.gridCountsDefaulted = true,
    this.table,
    this.readHeader,
    this.readMethod = warpMethodFull,
    this.rawBlock,
    this.controlGrid,
    this.residual,
    this.readOnlyReason,
    this.undescribedDetail = false,
    this.backupTakenAt,
    this.lastStoreIncomplete = false,
    this.previewError,
    this.failureMessage,
    this.progressDone = 0,
    this.progressTotal = 0,
  });

  final WarpSessionPhase phase;

  /// Set while [phase] is [WarpSessionPhase.unsupported].
  final WarpUnsupportedReason? unsupportedReason;

  /// The model's warp parameters; null until the model is known.
  final WarpModelCaps? caps;

  /// The memory this session shows.
  final WarpSlot slot;

  /// When the memory was stored (UTC); null when the projector has no time.
  final DateTime? storedAt;

  /// The control points the memory was stored with.
  final WarpGridCounts gridCounts;

  /// True when the projector gave no value and [gridCounts] is the default.
  final bool gridCountsDefaulted;

  /// The full table last read or stored. For an empty memory it is the
  /// neutral table. Null until a memory is loaded.
  final WarpTable? table;

  /// The header as read from the memory; null for an empty one. It goes back
  /// with every write so the fields nobody understands are kept.
  final Uint8List? readHeader;

  /// The method byte of the read, kept for the backup.
  final int readMethod;

  /// The block exactly as last read from the projector (node counts, header
  /// and planes); null for an empty memory. A store does not update it.
  final Uint8List? rawBlock;

  /// The control points recovered from [table]; null when [readOnly] and
  /// while nothing is loaded.
  final WarpControlGrid? controlGrid;

  /// The largest difference in px between [table] and the table [controlGrid]
  /// builds; null together with [controlGrid].
  final double? residual;

  /// Set when the loaded memory must not be edited.
  final WarpReadOnlyReason? readOnlyReason;

  /// True when the stored table holds detail the control grid cannot
  /// describe, so a store would replace it with the grid shape.
  final bool undescribedDetail;

  /// When the backup of this memory was taken (UTC), for the menu entry
  /// "Backup of ..."; null when there is none.
  final DateTime? backupTakenAt;

  /// True when the last write put the table in the projector but not the
  /// stored time or the numbers of control points.
  final bool lastStoreIncomplete;

  /// The last error of a preview or overlay command; cleared by the next one
  /// that works. It never changes [phase].
  final String? previewError;

  /// What went wrong, while [phase] is [WarpSessionPhase.failed].
  final String? failureMessage;

  /// Steps of the running write that are done, and in all, for "step n of
  /// m". The total is 0 until the first step is done.
  final int progressDone;
  final int progressTotal;

  bool get readOnly => readOnlyReason != null;

  /// True while a read or a write runs, so the editor disables its actions.
  bool get busy =>
      phase == WarpSessionPhase.detecting ||
      phase == WarpSessionPhase.loading ||
      phase == WarpSessionPhase.storing;

  WarpSessionState copyWith({
    WarpSessionPhase? phase,
    Object? unsupportedReason = _keep,
    WarpModelCaps? caps,
    WarpSlot? slot,
    Object? storedAt = _keep,
    WarpGridCounts? gridCounts,
    bool? gridCountsDefaulted,
    Object? table = _keep,
    Object? readHeader = _keep,
    int? readMethod,
    Object? rawBlock = _keep,
    Object? controlGrid = _keep,
    Object? residual = _keep,
    Object? readOnlyReason = _keep,
    bool? undescribedDetail,
    Object? backupTakenAt = _keep,
    bool? lastStoreIncomplete,
    Object? previewError = _keep,
    Object? failureMessage = _keep,
    int? progressDone,
    int? progressTotal,
  }) => WarpSessionState(
    phase: phase ?? this.phase,
    unsupportedReason: identical(unsupportedReason, _keep)
        ? this.unsupportedReason
        : unsupportedReason as WarpUnsupportedReason?,
    caps: caps ?? this.caps,
    slot: slot ?? this.slot,
    storedAt: identical(storedAt, _keep)
        ? this.storedAt
        : storedAt as DateTime?,
    gridCounts: gridCounts ?? this.gridCounts,
    gridCountsDefaulted: gridCountsDefaulted ?? this.gridCountsDefaulted,
    table: identical(table, _keep) ? this.table : table as WarpTable?,
    readHeader: identical(readHeader, _keep)
        ? this.readHeader
        : readHeader as Uint8List?,
    readMethod: readMethod ?? this.readMethod,
    rawBlock: identical(rawBlock, _keep)
        ? this.rawBlock
        : rawBlock as Uint8List?,
    controlGrid: identical(controlGrid, _keep)
        ? this.controlGrid
        : controlGrid as WarpControlGrid?,
    residual: identical(residual, _keep) ? this.residual : residual as double?,
    readOnlyReason: identical(readOnlyReason, _keep)
        ? this.readOnlyReason
        : readOnlyReason as WarpReadOnlyReason?,
    undescribedDetail: undescribedDetail ?? this.undescribedDetail,
    backupTakenAt: identical(backupTakenAt, _keep)
        ? this.backupTakenAt
        : backupTakenAt as DateTime?,
    lastStoreIncomplete: lastStoreIncomplete ?? this.lastStoreIncomplete,
    previewError: identical(previewError, _keep)
        ? this.previewError
        : previewError as String?,
    failureMessage: identical(failureMessage, _keep)
        ? this.failureMessage
        : failureMessage as String?,
    progressDone: progressDone ?? this.progressDone,
    progressTotal: progressTotal ?? this.progressTotal,
  );
}

/// Marks a [WarpSessionState.copyWith] argument that was not given, so an
/// explicit null can clear a nullable field.
const Object _keep = Object();
