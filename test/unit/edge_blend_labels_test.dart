import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/edge_blend_labels.dart';

void main() {
  group('blendTabPill', () {
    String? pill({
      bool loaded = true,
      bool off = false,
      bool linked = false,
      int edges = 2,
    }) => blendTabPill(
      loaded: loaded,
      off: off,
      linked: linked,
      enabledEdges: edges,
    );

    test('counts edges', () {
      expect(pill(edges: 0), 'No edges');
      expect(pill(edges: 1), '1 edge');
      expect(pill(edges: 3), '3 edges');
    });

    test('Off wins over Linked, Linked over the count', () {
      expect(pill(off: true, linked: true), 'Off');
      expect(pill(linked: true), 'Linked');
    });

    test('nothing until the projector answered', () {
      expect(pill(loaded: false, off: true), isNull);
    });
  });

  group('pairReplyOf', () {
    const ok = (loading: false, unreachable: false);
    const silent = (loading: false, unreachable: true);
    const loading = (loading: true, unreachable: false);

    test('each combination', () {
      expect(pairReplyOf(ok, ok), PairReply.online);
      expect(pairReplyOf(silent, ok), PairReply.aSilent);
      expect(pairReplyOf(ok, silent), PairReply.bSilent);
      expect(pairReplyOf(silent, silent), PairReply.bothSilent);
      expect(pairReplyOf(loading, silent), PairReply.reading);
    });

    test('labels', () {
      expect(pairReplyLabel(PairReply.bSilent), 'B not replying');
      expect(pairReplyLabel(PairReply.online), 'Online');
    });
  });

  test('the overlap readout in A pixels and percent of a raster', () {
    const a = (enabled: true, start: 0, width: 640, span: 3840);
    const b = (enabled: true, start: 0, width: 320, span: 3840);
    final r = pairOverlapReadout(a, b);
    expect(r, (px: 640, percent: 17));
    expect(pairOverlapLabel(r), 'Overlap 640 px, 17% of a raster');
  });

  test('a disabled facing edge adds nothing', () {
    const a = (enabled: false, start: 100, width: 640, span: 3840);
    const b = (enabled: false, start: 0, width: 320, span: 3840);
    expect(pairOverlapReadout(a, b), (px: 0, percent: 0));
  });

  test('side letters', () {
    expect(sideLetter(0), 'A');
    expect(sideLetter(1), 'B');
  });
}
