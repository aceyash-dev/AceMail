import '../models/contact.dart';

/// Address suggestions while somebody is typing a recipient.
///
/// Every mail client completes an address from the book you already have; this
/// app had a picker sheet instead, which is fine when you cannot remember a
/// name and useless when you can remember the first three letters. The rules
/// live here, as plain functions, so they can be tested without a keyboard.
///
/// What counts as "the address being typed" is everything after the last
/// separator: `ann, bo` is somebody typing a second address, and the token is
/// `bo`.
abstract final class RecipientSuggest {
  /// Where one address ends and the next begins.
  static final RegExp _separators = RegExp(r'[,;]');

  /// The address currently being typed: the text after the last separator.
  static String token(String text) {
    final int cut = text.lastIndexOf(_separators);
    final String tail = cut < 0 ? text : text.substring(cut + 1);
    return tail.trim();
  }

  /// The addresses already in [text], in order, lower-cased.
  ///
  /// Used to keep somebody from being suggested twice, and to keep the account
  /// you are writing from out of your own To line.
  static Set<String> addressesIn(String text) {
    return <String>{
      for (final String part in text.split(_separators))
        if (_addressOf(part).isNotEmpty) _addressOf(part),
    };
  }

  /// The bare address out of `Name <a@b.com>`, or out of `a@b.com`.
  static String _addressOf(String part) {
    final String trimmed = part.trim();
    final int open = trimmed.lastIndexOf('<');
    final int close = trimmed.lastIndexOf('>');
    final String inside = (open >= 0 && close > open)
        ? trimmed.substring(open + 1, close)
        : trimmed;
    return inside.trim().toLowerCase();
  }

  /// What to put in the field when somebody picks [contact]: a name and an
  /// address when there is a name, the address alone when there is not.
  static String format(Contact contact) {
    final String name = contact.name.trim();
    return name.isEmpty ? contact.email : '$name <${contact.email}>';
  }

  /// [text] with the address being typed replaced by [address], and a separator
  /// after it so the next one can be typed straight away.
  static String replaceToken(String text, String address) {
    final int cut = text.lastIndexOf(_separators);
    final String head = cut < 0 ? '' : text.substring(0, cut + 1).trimRight();
    if (head.isEmpty) return '$address, ';
    return '$head $address, ';
  }

  /// The contacts worth offering for what has been typed so far.
  ///
  /// Nothing until two characters: a suggestion list that appears on the first
  /// keystroke is a list of everybody, and it covers the subject line on the
  /// screen for no reason. Prefix matches come first — typing `an` should offer
  /// Ann before Brianna — and the rest follow by name.
  static List<Contact> forText(
    String text, {
    required Iterable<Contact> contacts,
    Set<String> exclude = const <String>{},
    int limit = 5,
    int minimum = 2,
  }) {
    final String typed = token(text);
    if (typed.length < minimum) return const <Contact>[];

    final String needle = typed.toLowerCase();
    final Set<String> taken = <String>{
      ...addressesIn(text),
      ...exclude.map((String email) => email.trim().toLowerCase()),
    };

    final List<Contact> matches = <Contact>[
      for (final Contact contact in contacts)
        if (contact.email.isNotEmpty && !taken.contains(contact.email.toLowerCase()))
          if (contact.email.toLowerCase().contains(needle) ||
              contact.name.toLowerCase().contains(needle))
            contact,
    ];

    bool prefix(Contact contact) =>
        contact.email.toLowerCase().startsWith(needle) ||
        contact.name.toLowerCase().startsWith(needle);

    matches.sort((Contact a, Contact b) {
      final bool pa = prefix(a);
      final bool pb = prefix(b);
      if (pa != pb) return pa ? -1 : 1;
      // Saved people before ones the mail merely mentioned, then by name.
      if (a.saved != b.saved) return a.saved ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    return matches.take(limit).toList(growable: false);
  }
}
