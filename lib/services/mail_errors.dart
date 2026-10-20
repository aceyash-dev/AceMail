import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

/// A failure worth showing the user, phrased for a person rather than a log.
///
/// Sealed, so a caller can switch on it exhaustively instead of guessing from
/// the message text.
sealed class MailException implements Exception {
  const MailException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The server rejected the credentials.
final class MailAuthException extends MailException {
  const MailAuthException(super.message);
}

/// The server could not be reached, or the connection dropped mid-command.
/// The only class worth retrying.
final class MailConnectionException extends MailException {
  const MailConnectionException(super.message);
}

/// The server understood the command and refused it. Retrying will not help.
final class MailRejectedException extends MailException {
  const MailRejectedException(super.message);
}

/// The message reached the server, but the answer did not come back — so
/// delivery is genuinely unknown. Never retried automatically.
final class MailUnknownOutcomeException extends MailException {
  const MailUnknownOutcomeException(super.message);
}

/// Anything that could not be classified. Shown as-is, without internals.
final class MailServerException extends MailException {
  const MailServerException(super.message);
}

/// Turns a raw error into the hierarchy above.
///
/// Classification is by **type** wherever the libraries give one — `SocketException`,
/// `HandshakeException`, `TimeoutException`, and SMTP status codes, which are
/// properly typed. IMAP is the exception: `ImapException` carries only a message
/// and untyped `details`, so that one case has a narrow, documented textual
/// fallback rather than the broad substring matching this replaces.
abstract final class MailErrors {
  static MailException classify(Object error, {required String fallback}) {
    if (error is MailException) return error;

    if (error is SmtpException) return _fromSmtp(error, fallback);
    if (error is ImapException) return _fromImap(error, fallback);
    if (error is HandshakeException) {
      return MailConnectionException(
        '$fallback The secure connection could not be verified.',
      );
    }
    if (error is SocketException) {
      return MailConnectionException(
        '$fallback Check this device\'s network connection.',
      );
    }
    if (error is TimeoutException) {
      return MailConnectionException('$fallback The server did not answer.');
    }
    if (error is HttpException) {
      return MailConnectionException(fallback);
    }
    return MailServerException(fallback);
  }

  /// SMTP status codes are meaningful: 5xx is a decision, 4xx is a mood.
  static MailException _fromSmtp(SmtpException error, String fallback) {
    final int? code = error.response.code;

    if (code == 535 || code == 534 || code == 530) {
      return const MailAuthException(
        'The server rejected your sign-in. Most providers need an app '
        'password, not your account password.',
      );
    }
    if (code != null && code >= 500) {
      return const MailRejectedException(
        'The server rejected the message. Check the recipients and try again.',
      );
    }
    if (code != null && code >= 400) {
      return MailConnectionException(
        '$fallback The server is temporarily unable to take the message.',
      );
    }
    return MailServerException(fallback);
  }

  /// IMAP response codes, when the library surfaces them, are the useful part;
  /// otherwise this narrows to the two cases that change what we do.
  static MailException _fromImap(ImapException error, String fallback) {
    final String text = (error.message ?? '').toLowerCase();
    if (text.isEmpty) return MailServerException(fallback);

    const List<String> authCodes = <String>[
      '[authenticationfailed]',
      '[authorizationfailed]',
      '[authenticationfailure]',
    ];
    if (authCodes.any(text.contains)) {
      return const MailAuthException(
        'Sign-in was rejected. Most providers need an app password, not your '
        'account password.',
      );
    }

    const List<String> transient = <String>[
      '[unavailable]',
      '[serverbug]',
      '[inuse]',
      'connection closed',
      'socket',
      'broken pipe',
    ];
    if (transient.any(text.contains)) {
      return MailConnectionException(fallback);
    }

    return MailServerException(fallback);
  }
}
