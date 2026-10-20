import 'dart:async';
import 'dart:io';

import 'package:ace_mail/services/mail_errors.dart';
import 'package:ace_mail/services/mail_service.dart' show MailService;
import 'package:enough_mail/enough_mail.dart' hide MailException;
import 'package:flutter_test/flutter_test.dart';

MailException classify(Object error) =>
    MailErrors.classify(error, fallback: 'Something failed.');

void main() {
  group('MailErrors.classify', () {
    test('a socket failure is a connection failure, so it is retryable', () {
      expect(classify(const SocketException('nope')),
          isA<MailConnectionException>());
    });

    test('a TLS failure is a connection failure', () {
      expect(
        classify(const HandshakeException('bad cert')),
        isA<MailConnectionException>(),
      );
    });

    test('a timeout is a connection failure', () {
      expect(
        classify(TimeoutException('slow')),
        isA<MailConnectionException>(),
      );
    });

    test('anything unrecognised is a server failure, not a retry', () {
      expect(classify(StateError('?')), isA<MailServerException>());
      expect(classify('a string'), isA<MailServerException>());
    });

    test('an already-classified failure passes through untouched', () {
      const MailAuthException original = MailAuthException('keep me');
      expect(identical(classify(original), original), isTrue);
    });

    test('the fallback text is what the user sees', () {
      expect(classify(StateError('?')).message, 'Something failed.');
    });
  });

  group('SMTP status codes', () {
    SmtpException smtp(String line) =>
        SmtpException(SmtpClient('smtp.example.com'), SmtpResponse(<String>[line]));

    test('535 is an authentication failure', () {
      expect(classify(smtp('535 5.7.8 bad credentials')),
          isA<MailAuthException>());
    });

    test('530 is an authentication failure', () {
      expect(classify(smtp('530 5.7.0 auth required')),
          isA<MailAuthException>());
    });

    test('a 5xx rejection is not retried', () {
      final MailException failure = classify(smtp('550 5.1.1 no such user'));
      expect(failure, isA<MailRejectedException>());
      expect(failure, isNot(isA<MailConnectionException>()));
    });

    test('a 4xx is transient, so it is retryable', () {
      expect(classify(smtp('451 4.3.0 try later')),
          isA<MailConnectionException>());
    });
  });

  group('IMAP', () {
    // The library does not type IMAP failures, so the response code is all
    // there is — narrowed to the cases that change what the app does.
    ImapException imap(String message) =>
        ImapException(ImapClient(), message);

    test('an authentication code is recognised', () {
      expect(
        classify(imap('NO [AUTHENTICATIONFAILED] Invalid credentials')),
        isA<MailAuthException>(),
      );
    });

    test('a transient code is a connection failure', () {
      expect(
        classify(imap('NO [UNAVAILABLE] Temporary failure')),
        isA<MailConnectionException>(),
      );
    });

    test('an unremarkable NO stays a server failure', () {
      expect(classify(imap('NO Mailbox does not exist')),
          isA<MailServerException>());
    });

    test('an empty message is not guessed at', () {
      expect(classify(imap('')), isA<MailServerException>());
    });
  });

  group('search criteria', () {
    test('searches sender and subject', () {
      final String criteria = MailService.searchCriteriaFor('invoice')!;
      expect(criteria.toUpperCase(), contains('OR'));
      expect(criteria.toUpperCase(), contains('SUBJECT'));
      expect(criteria.toUpperCase(), contains('FROM'));
      expect(criteria, contains('invoice'));
    });

    test('drops backslashes and control characters rather than quoting them', () {
      // The library escapes quotes but not backslashes, so these are removed
      // before the term is built.
      final String criteria =
          MailService.searchCriteriaFor(r'a\\b"c' '\u0000d')!;
      expect(criteria, isNot(contains(r'\b')));
      expect(criteria, isNot(contains('\u0000')));
    });

    test('a query that is only noise has no criteria at all', () {
      expect(MailService.searchCriteriaFor('   '), isNull);
      expect(MailService.searchCriteriaFor(r'\\'), isNull);
      expect(MailService.searchCriteriaFor('\u0001\u0002'), isNull);
    });

    test('non-ascii survives', () {
      expect(MailService.searchCriteriaFor('वेतन'), isNotNull);
    });
  });
}
