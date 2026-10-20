import 'dart:async';

/// Serialises work against one IMAP client.
///
/// `enough_mail` serialises individual commands, but not a *sequence* of them:
/// two overlapping operations can interleave a `SELECT` with a `FETCH`, and the
/// fetch then reads from the wrong mailbox. Everything that touches the
/// selected mailbox goes through one of these, which makes each operation
/// atomic.
///
/// Deliberately **not** re-entrant: a queued operation must call the raw
/// helpers, not another queued method, or it would wait on itself forever.
class RequestQueue {
  Future<void> _tail = Future<void>.value();
  int _depth = 0;

  /// How many operations are waiting or running.
  int get depth => _depth;

  bool get isBusy => _depth > 0;

  /// Runs [action] after everything already queued, and returns its result —
  /// including its errors, which are rethrown to the caller.
  Future<T> run<T>(Future<T> Function() action) {
    final Completer<T> result = Completer<T>();
    _depth++;

    _tail = _tail.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _depth--;
      }
    });

    return result.future;
  }
}
