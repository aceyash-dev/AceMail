import 'dart:async';
import 'dart:io';

import 'package:ace_mail/services/mail_errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the background worker decides to tell WorkManager.
///
/// The worker reports failure so WorkManager retries, and it must not do that
/// for a failure that retrying cannot fix. These are the two sides of that
/// decision, tested where the decision is actually made.
void main() {
  bool worthRetrying(Object error) =>
      MailErrors.classify(error, fallback: '') is MailConnectionException;

  test('a connection that dropped is worth trying again', () {
    expect(worthRetrying(const SocketException('network is unreachable')), isTrue);
    expect(worthRetrying(TimeoutException('no answer')), isTrue);
    expect(worthRetrying(const HandshakeException('bad certificate')), isTrue);
  });

  test('a rejected password is not', () {
    // Retrying this forever would be a battery drain that never once succeeds,
    // and it is the failure a person has to fix.
    expect(
      worthRetrying(const MailAuthException('The server rejected the password.')),
      isFalse,
    );
  });

  test('an unclassified failure is not retried', () {
    // Conservative on purpose: an unknown error retried on a schedule is a
    // retry storm against a server that already said no.
    expect(worthRetrying(StateError('something else')), isFalse);
  });

  test('the message is never part of the decision', () {
    // Classification is by type. A server that puts the word "timeout" in an
    // authentication error must not turn it into a network problem.
    expect(
      worthRetrying(const MailAuthException('connection timeout: bad password')),
      isFalse,
    );
  });
}
