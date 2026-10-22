/// What a check found.
class WatchResult {
  const WatchResult({required this.newUids, required this.newestSubject});

  /// The uids that are new since the last check, newest last.
  final List<int> newUids;

  /// The subject of the newest of them, for the notification body.
  final String? newestSubject;

  int get count => newUids.length;
  bool get hasNews => newUids.isNotEmpty;
}

/// The part of a new-mail check that is worth testing: given what was there
/// last time and what is there now, what is new.
///
/// IMAP uids only ever climb, so this is a comparison rather than a set
/// difference — which also means a message that arrives and is deleted between
/// two checks is not counted, and that is correct: nobody wants to be told
/// about mail they can no longer see.
abstract final class MailWatcher {
  static WatchResult compare({
    required List<int> previousUids,
    required List<int> currentUids,
    String? newestSubject,
  }) {
    if (currentUids.isEmpty) {
      return const WatchResult(newUids: <int>[], newestSubject: null);
    }

    // Nothing seen before: this is a first check, not a delivery. Reporting
    // every message in the mailbox as new would be a notification storm on the
    // first run, so the first run records and says nothing.
    if (previousUids.isEmpty) {
      return const WatchResult(newUids: <int>[], newestSubject: null);
    }

    final int highest = previousUids.reduce((int a, int b) => a > b ? a : b);
    final List<int> fresh =
        currentUids.where((int uid) => uid > highest).toList()..sort();

    return WatchResult(
      newUids: fresh,
      newestSubject: fresh.isEmpty ? null : newestSubject,
    );
  }
}
