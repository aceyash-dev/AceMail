import 'package:ace_mail/util/addresses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MailAddresses.split', () {
    test('splits a plain list', () {
      expect(MailAddresses.split('a@x.com, b@y.com'),
          <String>['a@x.com', 'b@y.com']);
    });

    test('keeps a comma inside a quoted display name', () {
      expect(
        MailAddresses.split('"Doe, John" <j@x.com>, a@y.com'),
        <String>['"Doe, John" <j@x.com>', 'a@y.com'],
      );
    });

    test('keeps a comma inside angle brackets', () {
      expect(
        MailAddresses.split('Team <team,a@x.com>, b@y.com'),
        <String>['Team <team,a@x.com>', 'b@y.com'],
      );
    });

    test('ignores empty entries and stray whitespace', () {
      expect(MailAddresses.split(' a@x.com , , '), <String>['a@x.com']);
      expect(MailAddresses.split(''), isEmpty);
    });
  });

  group('MailAddresses.parse', () {
    test('reads the display name and the address', () {
      final List<dynamic> parsed = MailAddresses.parse('Priya Sharma <p@x.com>');
      expect(parsed.single.email, 'p@x.com');
      expect(parsed.single.personalName, 'Priya Sharma');
    });

    test('handles a bare address', () {
      expect(MailAddresses.emailOf('p@x.com'), 'p@x.com');
      expect(MailAddresses.nameOf('p@x.com'), '');
    });

    test('handles a quoted address', () {
      expect(MailAddresses.emailOf('"p@x.com"'), 'p@x.com');
    });
  });

  group('MailAddresses.validate', () {
    test('accepts the forms people actually type', () {
      expect(MailAddresses.validate('a@x.com'), isNull);
      expect(MailAddresses.validate('Priya Sharma <p@x.com>'), isNull);
      expect(MailAddresses.validate('a@x.com, b@y.co.uk'), isNull);
      expect(MailAddresses.validate('a+tag@x.com'), isNull);
    });

    test('names the field and the offending entry', () {
      final String? problem = MailAddresses.validate('good@x.com, nope', field: 'Cc');
      expect(problem, isNotNull);
      expect(problem, contains('Cc'));
      expect(problem, contains('nope'));
    });

    test('rejects a missing domain or a missing local part', () {
      expect(MailAddresses.validate('nope'), isNotNull);
      expect(MailAddresses.validate('a@'), isNotNull);
      expect(MailAddresses.validate('@x.com'), isNotNull);
      expect(MailAddresses.validate('a@x'), isNotNull);
      expect(MailAddresses.validate('a b@x.com'), isNotNull);
    });

    test('an empty list is not an error — emptiness is checked separately', () {
      expect(MailAddresses.validate(''), isNull);
    });
  });

  group('MailAddresses.excluding', () {
    test('drops your own address from a reply-all, case-insensitively', () {
      final List<dynamic> others = MailAddresses.excluding(
        'me@X.com, other@y.com',
        <String>['ME@x.com'],
      );
      expect(others.map((dynamic a) => a.email), <String>['other@y.com']);
    });
  });

  group('MailAddresses.normalize', () {
    test('trims and lowercases for identity comparison', () {
      expect(MailAddresses.normalize('  A@B.com '), 'a@b.com');
    });
  });
}
