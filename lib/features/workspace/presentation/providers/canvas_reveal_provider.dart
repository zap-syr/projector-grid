import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'canvas_reveal_provider.g.dart';

/// A request for the canvas to scroll a card into view (Monitoring's *Find
/// on canvas*). [seq] grows with every request, so asking for the same
/// projector twice scrolls twice.
@Riverpod(keepAlive: true)
class CanvasRevealNotifier extends _$CanvasRevealNotifier {
  @override
  ({String nodeId, int seq})? build() => null;

  void reveal(String nodeId) =>
      state = (nodeId: nodeId, seq: (state?.seq ?? 0) + 1);
}
