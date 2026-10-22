/// A log line that says what happened without repeating what was said.
///
/// Nothing that reaches a log should be a password, a token, a message body or
/// a one-time code. The risk is not the line that says "sign-in failed" — it is
/// the *error*, because an IMAP or SMTP failure can quote the command that
/// failed, and the command contains the password:
///
/// ```
/// A3 LOGIN yash@example.com "hunter2"   ← the whole secret, in a log
/// ```
///
/// So failures are logged through [safe] rather than interpolated straight in.
abstract final class Redact {
  /// A command that carries a secret in its arguments.
  static final RegExp _authCommand = RegExp(
    r'\b(login|authenticate)\b\s+\S+(\s+\S+)?',
    caseSensitive: false,
  );

  /// A secret written as `key=value` or `key: value` — including the header
  /// form, `Authorization: Bearer eyJhbGciOi…`, where the secret is the *second*
  /// word. The optional scheme is consumed with it, so the token does not
  /// survive in the line after the label has been redacted.
  static final RegExp _namedSecret = RegExp(
    r'\b(pass(word)?|token|secret|api[-_]?key|authorization)\b\s*[:=]\s*'
    r'(?:[A-Za-z][A-Za-z0-9_-]*\s+)?\S+',
    caseSensitive: false,
  );

  static final RegExp _whitespace = RegExp(r'\s+');

  /// How much of a failure is worth keeping. Enough to recognise, not enough to
  /// quote a message back.
  static const int maxLength = 200;

  /// [value] with anything credential-shaped taken out, and cut short.
  ///
  /// For logs only. It is a scrubber, not a guarantee: the guarantee is not
  /// logging message contents in the first place.
  static String safe(Object? value) {
    String text = '$value'.replaceAll(_whitespace, ' ').trim();
    text = text.replaceAll(_authCommand, r'$1 <redacted>');
    text = text.replaceAll(_namedSecret, r'$1=<redacted>');
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength)}…';
    }
    return text;
  }

  /// An address, with the part that identifies a person taken out.
  ///
  /// The domain is worth keeping — "the sign-in to gmail.com failed" is a
  /// useful line — and the local part is the part that names somebody.
  static String address(String email) {
    final int at = email.indexOf('@');
    if (at <= 0) return '<address>';
    return '${email[0]}***${email.substring(at)}';
  }
}
