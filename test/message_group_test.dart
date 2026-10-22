import 'package:ace_mail/models/message_group.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:flutter_test/flutter_test.dart';

MessageSummary at(DateTime? date) => MessageSummary(
      uid: date?.millisecondsSinceEpoch ?? 0,
      sequenceId: 1,
      subject: 's',
      fromName: 'n',
      fromEmail: 'a@b.example',
      date: date,
      isSeen: true,
      isFlagged: false,
    );

void main() {
  final DateTime now = DateTime(2026, 10, 22, 12);

  group('groupByDate', () {
    test('nothing in, nothing out', () {
      expect(groupByDate(const <MessageSummary>[], now: now), isEmpty);
    });

    test('buckets by how long ago', () {
      final List<MessageGroup> groups = groupByDate(<MessageSummary>[
        at(DateTime(2026, 10, 22, 9)),
        at(DateTime(2026, 10, 21, 23)),
        at(DateTime(2026, 10, 19)),
        at(DateTime(2026, 10, 2)),
        at(DateTime(2026, 1, 1)),
      ], now: now);

      expect(
        groups.map((MessageGroup g) => g.label),
        <String>['Today', 'Yesterday', 'This week', 'This month', 'Earlier'],
      );
    });

    test('the order is fixed, not the order things arrived', () {
      // A message from January listed first must still be headed "Earlier",
      // and "Today" must still come first in the output.
      final List<MessageGroup> groups = groupByDate(<MessageSummary>[
        at(DateTime(2026, 1, 1)),
        at(DateTime(2026, 10, 22, 9)),
      ], now: now);

      expect(groups.first.label, 'Today');
      expect(groups.last.label, 'Earlier');
    });

    test('a message with no date is not dropped', () {
      final List<MessageGroup> groups = groupByDate(<MessageSummary>[
        at(null),
        at(DateTime(2026, 10, 22)),
      ], now: now);

      expect(groups.map((MessageGroup g) => g.label), contains('No date'));
      expect(
        groups.fold<int>(0, (int n, MessageGroup g) => n + g.messages.length),
        2,
      );
    });

    test('every message lands in exactly one group', () {
      final List<MessageSummary> input = <MessageSummary>[
        for (int i = 0; i < 30; i++) at(now.subtract(Duration(days: i))),
      ];
      final List<MessageGroup> groups = groupByDate(input, now: now);
      final int total =
          groups.fold<int>(0, (int n, MessageGroup g) => n + g.messages.length);

      expect(total, input.length);
    });

    test('an empty group is not shown', () {
      final List<MessageGroup> groups =
          groupByDate(<MessageSummary>[at(now)], now: now);
      expect(groups.length, 1);
      expect(groups.single.label, 'Today');
    });
  });
}
