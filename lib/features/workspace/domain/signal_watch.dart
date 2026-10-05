/// Signal lost detection as pure functions: what a `QVX:NSGS1` reading
/// means, and how one projector's watch moves on each reading.
/// `signalWatchProvider` only schedules the queries and feeds these.
library;

import 'telemetry_parsing.dart';

enum SignalReading { present, absent, unknown }

/// [display] is a signal as the app shows it ([formatSignal]'s output, the
/// node's `signal` field): `NO SIGNAL` covers both `NSGS1=NO SIGNAL` and the
/// `ER401` a projector answers while it locks onto an input. `-` (never read)
/// and other `ER` codes say nothing.
SignalReading signalReadingOf(String display) {
  if (display.toUpperCase() == 'NO SIGNAL') return SignalReading.absent;
  if (display == '-' || display.isEmpty || display.startsWith('ER')) {
    return SignalReading.unknown;
  }
  return SignalReading.present;
}

/// A `QVX:NSGS1` reply as the app shows it; null (transport failure) is `-`.
String signalDisplayOf(String? raw) =>
    formatSignal(stripSignalKey(raw), fallback: '-');

/// One dropout of a projector's signal.
class SignalLoss {
  const SignalLoss({
    required this.since,
    required this.input,
    this.restoredAt,
    this.open = true,
  });

  final DateTime since;

  /// The input shown when the signal went, e.g. `HDMI 1`.
  final String input;

  /// When the signal came back; null while it is still gone, or when the
  /// watch stopped before it came back (standby, offline).
  final DateTime? restoredAt;

  /// The signal is still gone and the watch is still looking.
  final bool open;

  SignalLoss restored(DateTime at) =>
      SignalLoss(since: since, input: input, restoredAt: at, open: false);

  /// The watch stopped (standby, offline) with the signal still gone.
  SignalLoss ended() =>
      open ? SignalLoss(since: since, input: input, open: false) : this;

  @override
  bool operator ==(Object other) =>
      other is SignalLoss &&
      other.since == since &&
      other.input == input &&
      other.restoredAt == restoredAt &&
      other.open == open;

  @override
  int get hashCode => Object.hash(since, input, restoredAt, open);
}

/// One reading for a powered-on projector. [armed]: a signal was seen since
/// the watch started (power-on) or the app last switched the input, so a
/// projector switched on before its source is ready, or switched to an input
/// with nothing connected, raises nothing.
///
/// [lossCandidate] asks the caller to confirm the projector is still on
/// before starting a loss: `ER401` is also what a projector answers once it
/// has gone to standby by other means (remote control, its own timer), which
/// the regular poll only notices later.
({bool armed, SignalLoss? loss, bool lossCandidate}) stepSignalWatch({
  required bool armed,
  required SignalLoss? loss,
  required SignalReading reading,
  required DateTime now,
}) {
  switch (reading) {
    case SignalReading.unknown:
      return (armed: armed, loss: loss, lossCandidate: false);
    case SignalReading.present:
      final back = loss != null && loss.open ? loss.restored(now) : loss;
      return (armed: true, loss: back, lossCandidate: false);
    case SignalReading.absent:
      final candidate = armed && !(loss?.open ?? false);
      return (armed: armed, loss: loss, lossCandidate: candidate);
  }
}

/// The alert's value: `No signal on HDMI 1`.
String signalLostValue(String input) =>
    input.isEmpty || input == '-' ? 'No signal' : 'No signal on $input';

/// How long a recovered dropout lasted: `Back after 3 s`, `Back after 2 min`.
String formatBackAfter(Duration d) => d.inSeconds < 60
    ? 'Back after ${d.inSeconds < 1 ? 1 : d.inSeconds} s'
    : 'Back after ${d.inMinutes} min';
