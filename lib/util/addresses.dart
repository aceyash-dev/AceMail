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

  /// Returns null when every entry looks like an address, otherwise a sentence
  /// saying what is wrong with the first one that is not.
  ///
  /// "Not a valid email address" is the message that helps nobody: the person
  /// already knows it is not valid — that is why the field is red. What they
  /// cannot see is *which* of the six things it is, so this says which.
  static String? validate(String value, {String field = 'To'}) {
    final List<String> entries = split(value);
    // Emptiness is a different question, and the caller asks it: a To line with
    // nothing in it says "add a recipient", which is not the same sentence as
    // "this address is wrong".
    if (entries.isEmpty) return null;

    for (final String entry in entries) {
      final String email = emailOf(entry);
      if (email.isEmpty) {
        return '$field: “$entry” has no address in it — try name@example.com.';
      }
      final int ats = '@'.allMatches(email).length;
      if (ats == 0) {
        return '$field: “$email” needs an @ — like name@example.com.';
      }
      if (ats > 1) {
        return '$field: “$email” has more than one @. If that is two addresses, '
            'separate them with a comma.';
      }
      if (email.contains(' ')) {
        return '$field: “$email” has a space in it. If that is two addresses, '
            'separate them with a comma.';
      }
      final String domain = email.split('@').last;
      if (domain.isEmpty) {
        return '$field: “$email” stops at the @ — add the domain.';
      }
      if (!domain.contains('.')) {
        return '$field: “$domain” needs a dot in it — like example.com.';
      }
      if (!isValid(entry)) {
        return '$field: “$email” does not look like an address.';
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

/// Whether an address belongs to a machine rather than a person.
///
/// Local parts that only ever send receipts, notifications and bounces. Used
/// where a list of *people* is being built — the address book — because
/// offering to write to "noreply@example.com" is offering something that cannot
/// work.
bool isMachineAddress(String email) {
  final String local =
      (email.contains('@') ? email.split('@').first : email).toLowerCase();
  const Set<String> machine = <String>{
    'noreply', 'no-reply', 'donotreply', 'do-not-reply', 'notification',
    'notifications', 'mailer-daemon', 'postmaster', 'bounce', 'bounces',
    'newsletter', 'updates', 'alerts',
  };
  return machine.contains(local) ||
      local.startsWith('noreply') ||
      local.startsWith('no-reply');
}
