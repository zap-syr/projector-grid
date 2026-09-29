import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/dispatch_result.dart';

import '../helpers/provider_harness.dart';

void main() {
  test('all OK shows only the count', () {
    const r = DispatchResult(command: 'PON', ok: 3);
    expect(r.allOk, isTrue);
    expect(dispatchSummary(r), 'Power On — 3/3 OK');
  });

  test('lists failed and skipped projectors by name', () {
    final r = DispatchResult(
      command: 'OSH:1',
      ok: 2,
      failed: [node('1'), node('2')],
      skipped: [node('3')],
    );
    expect(r.total, 5);
    expect(r.allOk, isFalse);
    expect(
      dispatchSummary(r),
      'Shutter Close — 2/5 OK · 2 failed · 1 skipped. '
      'Failed: Proj 1, Proj 2. Skipped: Proj 3',
    );
  });

  test('skipped only omits the failed part', () {
    final r = DispatchResult(command: 'POF', ok: 1, skipped: [node('2')]);
    expect(
      dispatchSummary(r),
      'Power Standby — 1/2 OK · 1 skipped. Skipped: Proj 2',
    );
  });
}
