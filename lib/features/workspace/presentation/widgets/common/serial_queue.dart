/// Runs tasks one after another in the order they were added. A task that
/// throws doesn't stop the ones queued behind it.
class SerialQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
