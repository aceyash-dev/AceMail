import 'package:ace_mail/models/message_sort.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:flutter_test/flutter_test.dart';

MessageSummary row(
  int uid, {
  String? subject,
  String? from,
  DateTime? date,
  bool seen = true,
  bool flagged = false,
  String? otp,
}) =>
    MessageSummary(
      uid: uid,
      sequenceId: uid,
      subject: subject ?? 'Subject $uid',
      fromName: from ?? 'Sender $uid',
      fromEmail: 's$uid@example.com',
      date: date,
      isSeen: seen,
      isFlagged: flagged,
      otp: otp,
    );

List<int> uids(List<MessageSummary> rows) =>
    rows.map((MessageSummary m) => m.uid).toList();

void main() {
  final DateTime base = DateTime(2026, 3, 1);

  group('MessageSort', () {
    final List<MessageSummary> page = <MessageSummary>[
      row(1, date: base, from: 'Zoe', subject: 'Zebra'),
      row(2, date: base.add(const Duration(days: 2)), from: 'Adam', subject: 'Apple'),
      row(3, date: base.add(const Duration(days: 1)), from: 'Mia', subject: 'Mango'),
    ];

    test('newest first is the default order', () {
      expect(uids(MessageSort.newest.apply(page)), <int>[2, 3, 1]);
    });

    test('oldest first reverses it', () {
      expect(uids(MessageSort.oldest.apply(page)), <int>[1, 3, 2]);
    });

    test('sender is alphabetical, case-insensitively', () {
      expect(uids(MessageSort.sender.apply(page)), <int>[2, 3, 1]);
    });

    test('subject is alphabetical', () {
      expect(uids(MessageSort.subject.apply(page)), <int>[2, 3, 1]);
    });

    test('unread floats to the top, newest first within each group', () {
      final List<MessageSummary> mixed = <MessageSummary>[
        row(1, date: base, seen: true),
        row(2, date: base.add(const Duration(days: 2)), seen: false),
        row(3, date: base.add(const Duration(days: 1)), seen: false),
      ];
      expect(uids(MessageSort.unread.apply(mixed)), <int>[2, 3, 1]);
    });

    test('a message with no date sorts last rather than first', () {
      final List<MessageSummary> mixed = <MessageSummary>[
        row(1, date: null),
        row(2, date: base),
      ];
      expect(uids(MessageSort.newest.apply(mixed)), <int>[2, 1]);
    });

    test('sorting does not mutate the page it was given', () {
      final List<MessageSummary> original = List<MessageSummary>.of(page);
      MessageSort.sender.apply(page);
      expect(uids(page), uids(original));
    });
  });

  group('MessageFilter', () {
    // A fixed clock: the period filters ask what time it is, and a test that
    // asks the real one is a test that fails at midnight.
    final DateTime now = DateTime(2026, 10, 23, 12);

    final List<MessageSummary> page = <MessageSummary>[
      row(1, seen: false),
      row(2, flagged: true),
      row(3, seen: false, otp: '123456'),
      row(4),
    ];

    test('all matches everything', () {
      expect(page.where((MessageSummary m) => MessageFilter.all.matches(m, now: now)).length, 4);
    });

    test('unread matches only unread', () {
      expect(uids(page.where((MessageSummary m) => MessageFilter.unread.matches(m, now: now)).toList()), <int>[1, 3]);
    });

    test('flagged matches only flagged', () {
      expect(uids(page.where((MessageSummary m) => MessageFilter.flagged.matches(m, now: now)).toList()), <int>[2]);
    });

    test('codes matches only messages with a code', () {
      expect(uids(page.where((MessageSummary m) => MessageFilter.codes.matches(m, now: now)).toList()), <int>[3]);
    });
  });
}
