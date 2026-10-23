import 'package:ace_mail/models/message_sort.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// The quick filters, and the two kinds of them: one that looks at a message,
/// and one that looks at a clock.
void main() {
  final DateTime now = DateTime(2026, 10, 23, 12);

  MessageSummary at(DateTime? date, {bool seen = false, String? otp}) =>
      MessageSummary(
        uid: 1,
        sequenceId: 1,
        subject: 's',
        fromName: 'n',
        fromEmail: 'a@b.com',
        date: date,
        isSeen: seen,
        isFlagged: false,
        otp: otp,
      );

  group('the plain ones', () {
    test('all takes everything, including a message with no date', () {
      expect(MessageFilter.all.matches(at(null), now: now), isTrue);
    });

    test('unread', () {
      expect(MessageFilter.unread.matches(at(now), now: now), isTrue);
      expect(
        MessageFilter.unread.matches(at(now, seen: true), now: now),
        isFalse,
      );
    });

    test('codes', () {
      expect(MessageFilter.codes.matches(at(now, otp: '123456'), now: now),
          isTrue);
      expect(MessageFilter.codes.matches(at(now), now: now), isFalse);
    });
  });

  group('the periods', () {
    test('are rolling windows, not calendar ones', () {
      // "This week" that empties on Sunday night is not what somebody looking
      // for last Tuesday's receipt wants.
      expect(
        MessageFilter.week.matches(at(now.subtract(const Duration(days: 6))),
            now: now),
        isTrue,
      );
      expect(
        MessageFilter.week.matches(at(now.subtract(const Duration(days: 8))),
            now: now),
        isFalse,
      );
    });

    test('today is the last day, to the minute', () {
      expect(
        MessageFilter.today.matches(at(now.subtract(const Duration(hours: 20))),
            now: now),
        isTrue,
      );
      expect(
        MessageFilter.today.matches(at(now.subtract(const Duration(hours: 26))),
            now: now),
        isFalse,
      );
    });

    test('a message with no date is in no period', () {
      // Sorting it into a window would be inventing a date it does not have.
      for (final MessageFilter filter in <MessageFilter>[
        MessageFilter.today,
        MessageFilter.week,
        MessageFilter.month,
      ]) {
        expect(filter.matches(at(null), now: now), isFalse,
            reason: filter.label);
      }
    });

    test('the clock is read once, by the caller', () {
      // `now` is a parameter rather than a call inside, so a page of forty is
      // one reading of the clock and not forty.
      final MessageSummary yesterday =
          at(now.subtract(const Duration(hours: 30)));
      expect(MessageFilter.today.matches(yesterday, now: now), isFalse);
      // A day later, the same message is in a different window — with the same
      // message object, which is the point.
      expect(
        MessageFilter.today.matches(yesterday,
            now: now.add(const Duration(days: 2))),
        isFalse,
      );
      expect(MessageFilter.week.matches(yesterday, now: now), isTrue);
    });
  });
}
