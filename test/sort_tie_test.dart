import 'package:ace_mail/models/message_sort.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:flutter_test/flutter_test.dart';

MessageSummary m(int uid, {String from = 'Ann', String subject = 'S', int day = 1}) {
  return MessageSummary(
    uid: uid,
    sequenceId: uid,
    subject: subject,
    fromName: from,
    fromEmail: '$from@example.com',
    date: DateTime(2026, 10, day, 9),
    isSeen: true,
    isFlagged: false,
  );
}

void main() {
  group('two keys', () {
    test('the tie-break only decides what the first key left equal', () {
      final List<MessageSummary> page = <MessageSummary>[
        m(1, from: 'Zed', day: 1),
        m(2, from: 'Ann', day: 2),
        m(3, from: 'Ann', day: 3),
        m(4, from: 'Bob', day: 4),
      ];

      // By sender, then newest first within each sender.
      final List<MessageSummary> sorted = MessageSort.sortBy(
        page,
        primary: MessageSort.sender,
        secondary: MessageSort.newest,
      );
      expect(sorted.map((MessageSummary x) => x.uid).toList(), <int>[3, 2, 4, 1]);
    });

    test('no tie-break leaves the primary order exactly as it was', () {
      final List<MessageSummary> page = <MessageSummary>[
        m(1, from: 'Zed', day: 1),
        m(2, from: 'Ann', day: 2),
        m(3, from: 'Ann', day: 3),
      ];
      final List<MessageSummary> sorted =
          MessageSort.sender.apply(page);
      expect(sorted.map((MessageSummary x) => x.uid).toList(), <int>[2, 3, 1]);
    });

    test('a tie-break that is the same order changes nothing', () {
      final List<MessageSummary> page = <MessageSummary>[
        m(1, from: 'Zed', day: 1),
        m(2, from: 'Ann', day: 2),
      ];
      final List<MessageSummary> sorted = MessageSort.sortBy(
        page,
        primary: MessageSort.newest,
        secondary: MessageSort.newest,
      );
      expect(sorted.map((MessageSummary x) => x.uid).toList(), <int>[2, 1]);
    });

    test('every order still works alone', () {
      final List<MessageSummary> page = <MessageSummary>[
        m(1, from: 'Zed', day: 1, subject: 'Zebra'),
        m(2, from: 'Ann', day: 2, subject: 'Apple'),
      ];
      expect(MessageSort.newest.apply(page).first.uid, 2);
      expect(MessageSort.oldest.apply(page).first.uid, 1);
      expect(MessageSort.sender.apply(page).first.uid, 2);
      expect(MessageSort.subject.apply(page).first.uid, 2);
    });
  });
}
