import 'package:ace_mail/util/redact.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule this file guards: nothing that reaches a log is a password, a
/// token, or the contents of a message.
///
/// The dangerous line is not "sign-in failed". It is the error *behind* it,
/// because an IMAP failure quotes the command that failed — and the command
/// carries the password.
void main() {
  group('Redact.safe', () {
    test('takes the password out of a failed LOGIN', () {
      final String line = Redact.safe(
        'ImapException: A3 LOGIN yash@example.com "hunter2" failed',
      );
      expect(line, isNot(contains('hunter2')));
      expect(line, contains('LOGIN <redacted>'));
    });

    test('takes it out of an AUTHENTICATE too', () {
      final String line = Redact.safe('A2 AUTHENTICATE PLAIN AGNoZW5lcg==');
      expect(line, isNot(contains('AGNoZW5lcg')));
      expect(line, contains('AUTHENTICATE <redacted>'));
    });

    test('takes out anything written as a named secret', () {
      expect(Redact.safe('password=hunter2'), isNot(contains('hunter2')));
      expect(Redact.safe('token: abc123def'), isNot(contains('abc123def')));
      expect(Redact.safe('api_key=deadbeef'), isNot(contains('deadbeef')));
      expect(
        Redact.safe('Authorization: Bearer eyJhbGciOi'),
        isNot(contains('eyJhbGciOi')),
      );
    });

    test('keeps what is useful about a failure', () {
      final String line = Redact.safe(
        'SocketException: Connection refused (port 993)',
      );
      expect(line, contains('Connection refused'));
      expect(line, contains('993'));
    });

    test('cuts a long failure short', () {
      final String line = Redact.safe('x' * 5000);
      expect(line.length, lessThanOrEqualTo(Redact.maxLength + 1));
      expect(line, endsWith('…'));
    });

    test('collapses whitespace, so a body cannot arrive as itself', () {
      expect(Redact.safe('line one\n\nline two'), 'line one line two');
    });

    test('a null or an odd value does not throw', () {
      expect(Redact.safe(null), 'null');
      expect(Redact.safe(42), '42');
    });
  });

  group('Redact.address', () {
    test('keeps the domain and drops the person', () {
      expect(Redact.address('yash@example.com'), 'y***@example.com');
    });

    test('anything that is not an address is not echoed', () {
      expect(Redact.address('not-an-address'), '<address>');
      expect(Redact.address(''), '<address>');
    });
  });
}
