import 'package:ace_mail/util/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('greetingFor', () {
    test('says the time of day', () {
      expect(greetingFor(DateTime(2026, 10, 23, 0, 5)), 'Good morning');
      expect(greetingFor(DateTime(2026, 10, 23, 9, 30)), 'Good morning');
      expect(greetingFor(DateTime(2026, 10, 23, 13, 0)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 10, 23, 19, 45)), 'Good evening');
      expect(greetingFor(DateTime(2026, 10, 23, 23, 59)), 'Good evening');
    });

    test('changes on the boundary, not a minute after it', () {
      expect(greetingFor(DateTime(2026, 10, 23, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 10, 23, 12, 0)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 10, 23, 16, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 10, 23, 17, 0)), 'Good evening');
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
