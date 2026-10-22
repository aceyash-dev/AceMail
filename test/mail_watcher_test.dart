import 'package:ace_mail/services/mail_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MailWatcher.compare', () {
    test('the first check says nothing', () {
      // Nothing was seen before, so everything is "new" — which would be a
      // notification storm on the first run rather than a delivery.
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[],
        currentUids: const <int>[4, 3, 2, 1],
        newestSubject: 'Welcome',
      );
      expect(result.hasNews, isFalse);
      expect(result.count, 0);
    });

    test('a uid above the highest seen is news', () {
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[10],
        currentUids: const <int>[12, 11, 10, 9],
        newestSubject: 'Your code',
      );
      expect(result.newUids, <int>[11, 12]);
      expect(result.count, 2);
      expect(result.newestSubject, 'Your code');
    });

    test('nothing new is nothing new', () {
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[10],
        currentUids: const <int>[10, 9, 8],
        newestSubject: 'Old',
      );
      expect(result.hasNews, isFalse);
    });

    test('deleting messages does not look like new mail', () {
      // Uids only climb, so a mailbox with fewer messages is not a delivery.
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[10],
        currentUids: const <int>[4, 3],
        newestSubject: 'Anything',
      );
      expect(result.hasNews, isFalse);
    });

    test('an empty mailbox is not news', () {
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[10],
        currentUids: const <int>[],
        newestSubject: null,
      );
      expect(result.hasNews, isFalse);
    });

    test('the new uids come back in order', () {
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[5],
        currentUids: const <int>[9, 6, 8, 7],
        newestSubject: 'Three',
      );
      expect(result.newUids, <int>[6, 7, 8, 9]);
      expect(result.count, 4);
    });

    test('a uid that arrived and was deleted between checks is not counted', () {
      // It is not in the current list, so nobody is told about mail they can no
      // longer see.
      final WatchResult result = MailWatcher.compare(
        previousUids: const <int>[5],
        currentUids: const <int>[7, 5],
        newestSubject: 'Seven',
      );
      expect(result.newUids, <int>[7]);
    });
  });
}
