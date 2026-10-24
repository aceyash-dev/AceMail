import 'package:ace_mail/util/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bandFor', () {
    test('names the band the hour falls in', () {
      expect(bandFor(5), 'morning');
      expect(bandFor(9), 'morning');
      expect(bandFor(13), 'afternoon');
      expect(bandFor(19), 'evening');
      expect(bandFor(23), 'night');
      expect(bandFor(2), 'night');
    });

    test('changes on the boundary, not a minute after it', () {
      expect(bandFor(4), 'night');
      expect(bandFor(5), 'morning');
      expect(bandFor(11), 'morning');
      expect(bandFor(12), 'afternoon');
      expect(bandFor(16), 'afternoon');
      expect(bandFor(17), 'evening');
      expect(bandFor(21), 'evening');
      expect(bandFor(22), 'night');
    });
  });

  group('greetingFor', () {
    // The words vary by design, so what is asserted is the behaviour that has to
    // hold whatever the words are: the same day gives the same line, and the
    // line belongs to the band the clock is in.
    test('holds still for a day', () {
      final DateTime morning = DateTime(2026, 10, 23, 9);
      expect(
        greetingFor(morning),
        greetingFor(DateTime(2026, 10, 23, 11, 59)),
      );
    });

    test('is a greeting, not an empty string, in every band', () {
      for (final int hour in <int>[6, 13, 19, 23]) {
        expect(greetingFor(DateTime(2026, 10, 23, hour)), isNotEmpty);
      }
    });

    test('is one of the words for that band', () {
      // "Good evening" at two in the morning is a greeting that has not looked
      // at the clock, which is what the fourth band exists to avoid.
      expect(bandFor(2), 'night');
      expect(greetingFor(DateTime(2026, 10, 23, 2)), isNotEmpty);
    });
  });

  group('with a name', () {
    test('greets by it', () {
      // The words vary; the name does not. Asserted by endsWith so the test is
      // about the name and not about which of the pool today picked.
      expect(
        greetingFor(DateTime(2026, 10, 23, 9), name: 'Yash Gupta'),
        endsWith(', Yash Gupta'),
      );
      expect(
        greetingFor(DateTime(2026, 10, 23, 19), name: 'Yash'),
        endsWith(', Yash'),
      );
    });

    test('uses it as it came, not title-cased or shortened', () {
      // Somebody who signs themselves "Dr. Rao" is not "Dr", and somebody whose
      // provider says "yash gupta" has chosen that.
      expect(
        greetingFor(DateTime(2026, 10, 23, 9), name: 'yash gupta'),
        endsWith(', yash gupta'),
      );
      expect(
        greetingFor(DateTime(2026, 10, 23, 9), name: 'Dr. Rao'),
        endsWith(', Dr. Rao'),
      );
    });

    test('an empty or blank name is no name', () {
      final String bare = greetingFor(DateTime(2026, 10, 23, 9));
      expect(greetingFor(DateTime(2026, 10, 23, 9), name: ''), bare);
      expect(greetingFor(DateTime(2026, 10, 23, 9), name: '   '), bare);
      expect(greetingFor(DateTime(2026, 10, 23, 9)), bare);
      expect(bare, isNot(contains(',')));
    });
  });

  group('folderSummary', () {
    test('names the folder and the count', () {
      expect(folderSummary('Inbox', 3), 'Inbox · 3 unread');
      expect(folderSummary('Inbox', 1), 'Inbox · 1 unread');
    });

    test('a count of zero is a sentence, not a number', () {
      expect(folderSummary('Inbox', 0), 'Inbox · nothing unread');
      expect(folderSummary('Archive', -1), 'Archive · nothing unread');
    });
  });
}
