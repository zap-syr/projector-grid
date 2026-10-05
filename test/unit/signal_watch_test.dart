import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/signal_watch.dart';

final _t0 = DateTime(2026, 10, 5, 14);

void main() {
  group('signalReadingOf / signalDisplayOf', () {
    test('reads replies as the app shows them', () {
      expect(signalDisplayOf('NSGS1=3840x2160/50p'), '3840x2160/50p');
      expect(signalDisplayOf('NSGS1=NO SIGNAL'), 'NO SIGNAL');
      expect(signalDisplayOf('ER401'), 'NO SIGNAL');
      expect(signalDisplayOf(null), '-');
    });

    test('NO SIGNAL and ER401 are absent, failures say nothing', () {
      expect(signalReadingOf('3840x2160/50p'), SignalReading.present);
      expect(signalReadingOf(signalDisplayOf('ER401')), SignalReading.absent);
      expect(signalReadingOf('NO SIGNAL'), SignalReading.absent);
      expect(signalReadingOf('-'), SignalReading.unknown);
      expect(signalReadingOf('ER402'), SignalReading.unknown);
    });
  });

  group('stepSignalWatch', () {
    test('a signal arms the watch', () {
      final s = stepSignalWatch(
        armed: false,
        loss: null,
        reading: SignalReading.present,
        now: _t0,
      );
      expect(s.armed, isTrue);
      expect(s.lossCandidate, isFalse);
    });

    test('no signal before one was seen raises nothing', () {
      final s = stepSignalWatch(
        armed: false,
        loss: null,
        reading: SignalReading.absent,
        now: _t0,
      );
      expect(s.lossCandidate, isFalse);
    });

    test('no signal once armed is a loss candidate, once', () {
      expect(
        stepSignalWatch(
          armed: true,
          loss: null,
          reading: SignalReading.absent,
          now: _t0,
        ).lossCandidate,
        isTrue,
      );
      expect(
        stepSignalWatch(
          armed: true,
          loss: SignalLoss(since: _t0, input: 'HDMI 1'),
          reading: SignalReading.absent,
          now: _t0,
        ).lossCandidate,
        isFalse,
      );
    });

    test('an over dropout does not stop a new one', () {
      final over = SignalLoss(
        since: _t0,
        input: 'HDMI 1',
      ).restored(_t0.add(const Duration(seconds: 4)));
      expect(
        stepSignalWatch(
          armed: true,
          loss: over,
          reading: SignalReading.absent,
          now: _t0,
        ).lossCandidate,
        isTrue,
      );
    });

    test('the signal coming back restores the open loss', () {
      final back = _t0.add(const Duration(seconds: 4));
      final s = stepSignalWatch(
        armed: true,
        loss: SignalLoss(since: _t0, input: 'HDMI 1'),
        reading: SignalReading.present,
        now: back,
      );
      expect(s.loss!.open, isFalse);
      expect(s.loss!.restoredAt, back);
    });

    test('an unknown reading changes nothing', () {
      final loss = SignalLoss(since: _t0, input: 'HDMI 1');
      final s = stepSignalWatch(
        armed: true,
        loss: loss,
        reading: SignalReading.unknown,
        now: _t0,
      );
      expect(s.armed, isTrue);
      expect(s.loss, loss);
      expect(s.lossCandidate, isFalse);
    });
  });

  test('ended keeps a dropout without a return time', () {
    final loss = SignalLoss(since: _t0, input: 'HDMI 1').ended();
    expect(loss.open, isFalse);
    expect(loss.restoredAt, isNull);
  });

  test('signalLostValue and formatBackAfter', () {
    expect(signalLostValue('HDMI 1'), 'No signal on HDMI 1');
    expect(signalLostValue('-'), 'No signal');
    expect(
      formatBackAfter(const Duration(milliseconds: 3600)),
      'Back after 3 s',
    );
    expect(
      formatBackAfter(const Duration(milliseconds: 300)),
      'Back after 1 s',
    );
    expect(formatBackAfter(const Duration(seconds: 150)), 'Back after 2 min');
  });
}
