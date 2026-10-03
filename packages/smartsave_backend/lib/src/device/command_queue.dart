import 'dart:async';

class _QueuedOperation<T> {
  _QueuedOperation(this.operation) : completer = Completer<T>();
  final Future<T> Function() operation;
  final Completer<T> completer;
}

/// A FIFO queue of asynchronous operations.
final class CommandQueue {
  final List<_QueuedOperation<Object?>> _pending =
      <_QueuedOperation<Object?>>[];
  bool _running = false;

  /// Adds [operation] to the queue.
  Future<T> add<T>(Future<T> Function() operation) {
    final entry = _QueuedOperation<T>(operation);
    _pending.add(entry as _QueuedOperation<Object?>);
    scheduleMicrotask(_drain);
    return entry.completer.future;
  }

  /// Fails queued operations with [error].
  void clear(Object error, [StackTrace? stackTrace]) {
    final queued = List<_QueuedOperation<Object?>>.from(_pending);
    _pending.clear();
    for (final entry in queued) {
      scheduleMicrotask(() {
        if (!entry.completer.isCompleted) {
          entry.completer.completeError(error, stackTrace ?? StackTrace.current);
        }
      });
    }
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      try {
        entry.completer.complete(await entry.operation());
      } catch (error, stackTrace) {
        entry.completer.completeError(error, stackTrace);
      }
    }
    _running = false;
  }
}
