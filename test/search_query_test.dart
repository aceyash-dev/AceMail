import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/util/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plain words', () {
    test('go to the server as from-or-subject, as they always have', () {
      final String criteria = SearchQuery.parse('invoice').criteria()!;
      expect(criteria.toUpperCase(), contains('OR'));
      expect(criteria.toUpperCase(), contains('FROM'));
      expect(criteria.toUpperCase(), contains('SUBJECT'));
      expect(criteria, contains('invoice'));
    });

    test('several words are one phrase, not several criteria', () {
      final String criteria = SearchQuery.parse('quarterly report').criteria()!;
      expect(criteria, contains('quarterly report'));
      expect(criteria.split('OR').length, 2);
    });

    test('nothing searchable has no criteria', () {
      expect(SearchQuery.parse('   ').criteria(), isNull);
    });
  });

  group('operators', () {
    test('from, to and subject become their own keys', () {
      final String criteria =
          SearchQuery.parse('from:alice@example.com subject:receipt').criteria()!;
      expect(criteria, contains('FROM "alice@example.com"'));
      expect(criteria, contains('SUBJECT "receipt"'));
      expect(criteria.toUpperCase(), isNot(contains('OR')));
    });

    test('is: and has: become flags', () {
      expect(SearchQuery.parse('is:unread').criteria(), 'UNSEEN');
      expect(SearchQuery.parse('is:flagged').criteria(), 'FLAGGED');
      expect(SearchQuery.parse('is:starred').criteria(), 'FLAGGED');
      expect(SearchQuery.parse('is:unread is:flagged').criteria(),
          'UNSEEN FLAGGED');
    });

    test('has:attachment is not asked of the server', () {
      final SearchQuery query = SearchQuery.parse('has:attachment report');
      // No key for it exists in the grammar, so it is not in the criteria.
      expect(query.criteria()!.toUpperCase(), isNot(contains('ATTACH')));
      expect(query.narrowsLocally, isTrue);
    });

    test('dates become IMAP dates, which are not locale-dependent', () {
      expect(SearchQuery.parse('after:2026-01-05').criteria(),
          'SINCE 5-Jan-2026');
      expect(SearchQuery.parse('before:2026-12-31').criteria(),
          'BEFORE 31-Dec-2026');
    });

    test('newer_than reads the shorthand every client accepts', () {
      final SearchQuery query = SearchQuery.parse('newer_than:7d');
      final DateTime since = query.since!;
      final int days = DateTime.now().difference(since).inDays;
      expect(days, inInclusiveRange(6, 7));
      expect(SearchQuery.parse('newer_than:2w').since, isNotNull);
      expect(SearchQuery.parse('newer_than:3m').since, isNotNull);
    });

    test('a word that merely looks like an operator stays a word', () {
      // `wibble:` is not a key, and a search box that rejects input is worse
      // than one that searches for what was typed.
      final SearchQuery query = SearchQuery.parse('wibble:thing');
      expect(query.hasOperators, isFalse);
      expect(query.criteria(), contains('wibble:thing'));
    });

    test('an operator with no value stays a word too', () {
      final SearchQuery query = SearchQuery.parse('from:');
      expect(query.from, isNull);
      expect(query.criteria(), contains('from:'));
    });

    test('a malformed date is a word, not a silent empty result', () {
      final SearchQuery query = SearchQuery.parse('after:5/1/26');
      expect(query.since, isNull);
      expect(query.criteria(), contains('after:5/1/26'));
    });
  });

  group('escaping', () {
    test('a quote cannot end a term early', () {
      final String criteria = SearchQuery.parse('subject:a"b').criteria()!;
      expect(criteria, 'SUBJECT "a b"');
    });

    test('backslashes and control characters are dropped, not quoted', () {
      final String criteria =
          SearchQuery.parse(r'subject:a\b' '\u0000c').criteria()!;
      expect(criteria, isNot(contains(r'\b')));
      expect(criteria, isNot(contains('\u0000')));
    });

    test('a key made entirely of noise contributes nothing', () {
      expect(SearchQuery.parse(r'from:\\').criteria(), isNull);
    });
  });

  group('the local narrowing', () {
    MessageSummary row({required bool attached}) => MessageSummary(
          uid: 1,
          sequenceId: 1,
          subject: 's',
          fromName: 'n',
          fromEmail: 'a@b.com',
          date: DateTime(2026, 10, 23),
          isSeen: true,
          isFlagged: false,
          hasAttachments: attached,
        );

    test('keeps only what has something attached', () {
      final SearchQuery query = SearchQuery.parse('has:attachment');
      expect(query.matches(row(attached: true)), isTrue);
      expect(query.matches(row(attached: false)), isFalse);
    });

    test('narrows nothing when it was not asked to', () {
      final SearchQuery query = SearchQuery.parse('invoice');
      expect(query.narrowsLocally, isFalse);
      expect(query.matches(row(attached: false)), isTrue);
    });
  });
}
