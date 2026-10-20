import 'package:enough_mail/enough_mail.dart';

/// Address parsing for the compose screen and the SMTP layer.
///
/// Deliberately conservative: it accepts the forms people actually type, splits
/// on commas only outside quotes and angle brackets, and reports the first bad
/// entry so the UI can point at it.
abstract final class MailAddresses {
  /// `local@domain.tld`, allowing any non-space, non-@ characters on each side.
  static final RegExp _pattern = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$');

  /// Splits on commas that are not inside `"…"` or `<…>`.
  static List<String> split(String value) {
    final List<String> parts = <String>[];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;
    bool inAngle = false;

    for (int i = 0; i < value.length; i++) {
      final String ch = value[i];
      if (ch == '"') inQuotes = !inQuotes;
      if (!inQuotes && ch == '<') inAngle = true;
      if (!inQuotes && ch == '>') inAngle = false;

      if (ch == ',' && !inQuotes && !inAngle) {
        parts.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    parts.add(current.toString());

    return parts
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList();
  }

  /// The bare address from `Display Name <a@b.com>`, `"a@b.com"` or `a@b.com`.
  static String emailOf(String entry) {
    final String trimmed = entry.trim();
    final int open = trimmed.lastIndexOf('<');
    final int close = trimmed.lastIndexOf('>');
    if (open != -1 && close > open) {
      return trimmed.substring(open + 1, close).trim();
    }
    return trimmed.replaceAll('"', '').trim();
  }

  /// The display name from `Display Name <a@b.com>`, or empty.
  static String nameOf(String entry) {
    final int open = entry.lastIndexOf('<');
    if (open <= 0) return '';
    return entry
        .substring(0, open)
        .trim()
        .replaceAll(RegExp(r'^"|"$'), '')
        .trim();
  }

  static bool isValid(String entry) => _pattern.hasMatch(emailOf(entry));

  /// Returns null when every entry looks like an address, otherwise a message
  /// naming the first one that does not.
  static String? validate(String value, {String field = 'To'}) {
    final List<String> entries = split(value);
    for (final String entry in entries) {
      if (!isValid(entry)) {
        return '$field: “$entry” is not a valid email address.';
      }
    }
    return null;
  }

  /// Validated entries as `MailAddress`es. Assumes [validate] has passed.
  static List<MailAddress> parse(String value) => split(value)
      .map((String entry) => MailAddress(nameOf(entry), emailOf(entry)))
      .toList();

  /// Addresses in [value] whose email matches none in [exclude], compared
  /// case-insensitively — used to keep yourself out of a reply-all.
  static List<MailAddress> excluding(
    String value,
    Iterable<String> exclude,
  ) {
    final Set<String> skip =
        exclude.map(normalize).where((String e) => e.isNotEmpty).toSet();
    return parse(value)
        .where((MailAddress a) => !skip.contains(normalize(a.email)))
        .toList();
  }

  /// Identity comparison only. The local part of an address is technically
  /// case-sensitive, but every provider people use treats it as not, and
  /// comparing raw strings produced duplicate accounts for the same mailbox.
  static String normalize(String email) => email.trim().toLowerCase();
}
