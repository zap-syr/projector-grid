import 'event_log_rows.dart';
import 'log_event.dart';

/// A lens step joins the run when it comes less than this after the
/// previous step (plan §7k.2).
const Duration lensRunGap = Duration(seconds: 3);

/// Events of several projectors fold into a group within this of the
/// group's first event: a poll pass over many projectors.
const Duration logGroupWindow = Duration(seconds: 2);

enum _Mode { one, repeat, group, lens, osc }

/// A row being folded: its parts in the order they came.
class _Fold {
  _Fold(LogRow first, this.seq) : parts = [first] {
    projectors.addAll(_projectorsOf(first));
  }

  final List<LogRow> parts;

  /// When its first part was read, in reading order: a group only takes a
  /// projector that logged nothing since.
  final int seq;
  final Set<String> projectors = {};
  _Mode mode = _Mode.one;

  /// Its place in the list; it moves to the end (the newest place) with
  /// every part it takes.
  int slot = 0;

  DateTime get firstTime => parts.first.timestamp;
  DateTime get lastTime => parts.last.timestamp;

  void add(LogRow row, _Mode as) {
    parts.add(row);
    projectors.addAll(_projectorsOf(row));
    mode = as;
  }

  LogRow build() => switch (mode) {
    _Mode.one => parts.single,
    _Mode.repeat || _Mode.osc => RepeatLogRow([
      for (final p in parts.reversed) (p as SingleLogRow).event,
    ]),
    _Mode.group => GroupLogRow((parts.first as SingleLogRow).event.groupKind!, [
      for (final p in parts) (p as SingleLogRow).event,
    ]),
    _Mode.lens => LensRunLogRow(parts.reversed.toList()),
  };
}

/// How the log tells projectors apart: the node id where the event has
/// one, else the IP.
String? _projectorKey(LogEvent e) => e.nodeId ?? e.projectorIp;

Set<String> _projectorsOf(LogRow row) => switch (row) {
  SingleLogRow(:final event) => {?_projectorKey(event)},
  BatchLogRow(:final batch) => batch.nodeIds.toSet(),
  _ => const {},
};

/// A Lens Shift step: to one projector, or a batch.
bool _isLensStep(LogRow row) => switch (row) {
  SingleLogRow(:final event) =>
    event.type == LogEventType.command &&
        event.outcome != null &&
        isLensShiftCommand(event.command) &&
        _projectorKey(event) != null,
  BatchLogRow(:final batch) => isLensShiftCommand(batch.command),
  _ => false,
};

/// One projector, or a batch's set of projectors in any order.
String _lensTarget(LogRow row) => switch (row) {
  BatchLogRow(:final batch) =>
    'b:${(batch.nodeIds.toList()..sort()).join(',')}',
  SingleLogRow(:final event) => 'p:${_projectorKey(event)}',
  _ => '',
};

/// When a step started: a batch's first reply.
DateTime _startOf(LogRow row) => switch (row) {
  BatchLogRow() =>
    row.events.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
  _ => row.timestamp,
};

/// The sender of an OSC address line that came with a lens step.
String? _oscLensSender(LogRow row) => switch (row) {
  SingleLogRow(:final event)
      when event.type == LogEventType.osc &&
          isLensShiftCommand(event.command) =>
    event.oscSender,
  _ => null,
};

bool _sameEvent(LogEvent a, LogEvent b) =>
    a.type == b.type &&
    a.severity == b.severity &&
    a.message == b.message &&
    a.source == b.source &&
    a.oscSender == b.oscSender &&
    _projectorKey(a) == _projectorKey(b);

/// Folds [rows] (newest first) as the log shows them (plan §7k.2), each
/// folded row in the place of its newest event:
/// - **Lens runs**: Lens Shift steps to the same target from the same
///   source, each less than [lensRunGap] after the previous; any other row
///   about one of those projectors ends the run. The OSC address lines
///   that came with them fold by address and sender.
/// - **Groups**: the same kind of event (`LogEvent.groupKind`) from several
///   projectors within [logGroupWindow] of the first, while none of them
///   logged anything else in between.
/// - **Repeats**: the same event from one projector while it logged
///   nothing else in between; other projectors' events don't break it.
List<LogRow> foldLogRows(List<LogRow> rows) {
  final slots = <_Fold?>[];
  // By projector: the fold holding its newest row, and when it was read.
  final lastOf = <String, _Fold>{};
  final lastSeqOf = <String, int>{};
  final openGroups = <String, _Fold>{};
  final openRuns = <String, _Fold>{};
  final openOsc = <String, _Fold>{};

  _Fold? continueRun(LogRow row) {
    if (!_isLensStep(row)) return null;
    final run = openRuns[_lensTarget(row)];
    if (run == null ||
        run.parts.last.source != row.source ||
        _startOf(row).difference(run.lastTime) >= lensRunGap) {
      return null;
    }
    run.add(row, _Mode.lens);
    return run;
  }

  _Fold? continueOsc(LogRow row) {
    final sender = _oscLensSender(row);
    if (sender == null) return null;
    final run = openOsc[sender];
    if (run == null) return null;
    final last = (run.parts.last as SingleLogRow).event;
    final e = (row as SingleLogRow).event;
    if (last.message != e.message ||
        e.timestamp.difference(last.timestamp) >= lensRunGap) {
      return null;
    }
    run.add(row, _Mode.osc);
    return run;
  }

  _Fold? joinGroup(LogRow row, int seq) {
    if (row is! SingleLogRow) return null;
    final e = row.event;
    final kind = e.groupKind;
    final key = _projectorKey(e);
    if (kind == null || key == null) return null;
    final group = openGroups[kind.key];
    if (group == null ||
        e.timestamp.difference(group.firstTime) > logGroupWindow ||
        group.projectors.contains(key) ||
        (lastSeqOf[key] ?? -1) >= group.seq) {
      return null;
    }
    group.add(row, _Mode.group);
    return group;
  }

  _Fold? repeat(LogRow row) {
    if (row is! SingleLogRow || _isLensStep(row)) return null;
    final key = _projectorKey(row.event);
    if (key == null) return null;
    final prev = lastOf[key];
    if (prev == null || (prev.mode != _Mode.one && prev.mode != _Mode.repeat)) {
      return null;
    }
    final last = prev.parts.last;
    if (last is! SingleLogRow ||
        last.event.batch != null ||
        !_sameEvent(last.event, row.event)) {
      return null;
    }
    prev.add(row, _Mode.repeat);
    return prev;
  }

  for (final (seq, row) in rows.reversed.indexed) {
    final keys = _projectorsOf(row);
    final joined =
        continueRun(row) ??
        continueOsc(row) ??
        joinGroup(row, seq) ??
        repeat(row);
    final fold = joined ?? _Fold(row, seq);
    if (joined != null) slots[joined.slot] = null;
    fold.slot = slots.length;
    slots.add(fold);

    // Anything else from a projector ends what was open for it.
    if (keys.isNotEmpty) {
      openGroups.removeWhere(
        (_, g) => g != fold && g.projectors.any(keys.contains),
      );
      openRuns.removeWhere(
        (_, r) => r != fold && r.projectors.any(keys.contains),
      );
    }
    if (row case SingleLogRow(:final event)
        when event.type == LogEventType.osc && event.oscSender != null) {
      openOsc.removeWhere((s, r) => s == event.oscSender && r != fold);
    }
    // A repeat is one projector's: it no longer takes others.
    if (fold.mode == _Mode.repeat) {
      openGroups.removeWhere((_, g) => g == fold);
    }
    for (final k in keys) {
      lastOf[k] = fold;
      lastSeqOf[k] = seq;
    }

    if (fold.mode == _Mode.one) {
      if (_isLensStep(row)) {
        openRuns[_lensTarget(row)] = fold;
      } else if (_oscLensSender(row) case final sender?) {
        openOsc[sender] = fold;
      } else if (row case SingleLogRow(:final event)
          when event.groupKind != null && keys.isNotEmpty) {
        openGroups[event.groupKind!.key] = fold;
      }
    }
  }
  return [
    for (final f in slots.reversed)
      if (f != null) f.build(),
  ];
}
