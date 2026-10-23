/// Which links this app will hand to the platform.
///
/// A policy, not a widget: the message renderer and the assistant's replies both
/// need it, and two copies of a rule about what is safe to open is one copy too
/// many.
library;

/// The only schemes Ace Mail will hand to the platform launcher. Everything
/// else — `javascript:`, `data:`, `file:`, `intent:`, and arbitrary app
/// schemes — is discarded. `mailto:` is a deliberate exception because this is
/// a mail client.
const Set<String> kAllowedLinkSchemes = <String>{'http', 'https', 'mailto'};

/// Whether [uri] may be handed to the platform. Pure, so the rule can be
/// asserted without a browser.
bool mayOpenLink(Uri uri) =>
    kAllowedLinkSchemes.contains(uri.scheme.toLowerCase());

/// A link found in plain text: where it is, and what it points at.
class LinkSpan {
  const LinkSpan({required this.start, required this.end, required this.uri});

  /// Offsets into the string it was found in.
  final int start;
  final int end;

  final Uri uri;
}

/// A URL, a `mailto:`, or a bare address.
///
/// The bare address is not optional in a mail client: "write to hi@example.com"
/// is how people give you an address, and a mail app that draws it as plain
/// text has failed at the one thing it is for.
/// Brackets are *allowed* in the body and trimmed afterwards, rather than
/// excluded here: a Wikipedia URL ends in `(disambiguation)` and cutting at the
/// `(` is how you turn a working link into a broken one. The trimming below
/// knows the difference between a bracket that belongs to the address and one
/// that belongs to the sentence; a character class cannot.
final RegExp _urlPattern = RegExp(
  r'(?:https?://|www\.)[^\s<>\[\]{}"“”‘’]+'
  r'|mailto:[^\s<>\[\]{}"“”‘’]+'
  r'|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
  caseSensitive: false,
);

/// The links in [text], in order.
///
/// Pure, so the awkward cases can be asserted without a renderer. The one that
/// matters is trailing punctuation: "see https://example.com." ends with a full
/// stop that is part of the sentence, not the address, and a link that carries
/// it into the browser is a 404 for a page that exists.
///
/// A bare `example.com` is deliberately **not** a link. Guessing at hostnames
/// turns "read example.com's terms" into a link that swallows the possessive,
/// and there is no way to tell the two apart from the text alone.
Iterable<LinkSpan> findLinks(String text) sync* {
  for (final RegExpMatch match in _urlPattern.allMatches(text)) {
    int end = match.end;
    // Trailing punctuation belongs to the sentence. Closing brackets are
    // dropped only when they are unbalanced, so a Wikipedia-style
    // `..._(disambiguation)` survives intact.
    // Written as a set rather than a regex so the quote characters need no
    // escaping — a raw string cannot escape, and `\'` inside one ends it.
    const String trailing = '.,;:!?\u0027\u0022';
    while (end > match.start) {
      final String last = text[end - 1];
      if (trailing.contains(last)) {
        end -= 1;
        continue;
      }
      if (last == ')' &&
          _count(text.substring(match.start, end), '(') <
              _count(text.substring(match.start, end), ')')) {
        end -= 1;
        continue;
      }
      break;
    }
    if (end <= match.start) continue;

    final String raw = text.substring(match.start, end);
    final String lower = raw.toLowerCase();
    // A bare address and a bare host both need a scheme; `mailto:` is already
    // one.
    final String candidate = lower.startsWith('www.')
        ? 'https://$raw'
        : (!lower.contains(':') && raw.contains('@'))
            ? 'mailto:$raw'
            : raw;
    final Uri? uri = Uri.tryParse(candidate);
    if (uri == null || !mayOpenLink(uri)) continue;
    yield LinkSpan(start: match.start, end: end, uri: uri);
  }
}

int _count(String text, String character) =>
    character.allMatches(text).length;
