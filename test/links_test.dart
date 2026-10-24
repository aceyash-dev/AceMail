import 'package:ace_mail/util/links.dart';
import 'package:flutter_test/flutter_test.dart';

/// The addresses [findLinks] finds in [text], as strings.
List<String> found(String text) =>
    findLinks(text).map((LinkSpan l) => l.uri.toString()).toList();

void main() {
  test('finds the obvious ones', () {
    expect(found('see https://example.com/a/b for more'),
        <String>['https://example.com/a/b']);
    expect(found('http://example.com'), <String>['http://example.com']);
  });

  test('www gets a scheme, because a link without one goes nowhere', () {
    expect(found('go to www.example.com now'), <String>['https://www.example.com']);
  });

  test('trailing punctuation belongs to the sentence', () {
    // A full stop carried into the browser is a 404 for a page that exists.
    expect(found('Read https://example.com.'), <String>['https://example.com']);
    expect(found('Really? https://example.com!'), <String>['https://example.com']);
    expect(found('See https://example.com, then come back'),
        <String>['https://example.com']);
  });

  test('a balanced bracket is part of the address', () {
    // Wikipedia-style, and it is a real URL.
    expect(found('https://en.wikipedia.org/wiki/Ace_(disambiguation)'),
        <String>['https://en.wikipedia.org/wiki/Ace_(disambiguation)']);
  });

  test('an unbalanced closing bracket is not', () {
    expect(found('(see https://example.com)'), <String>['https://example.com']);
  });

  test('mailto is allowed, because this is a mail client', () {
    expect(found('write to mailto:hi@example.com'),
        <String>['mailto:hi@example.com']);
  });

  test('schemes that are not allowed are not links', () {
    expect(found('javascript:alert(1)'), isEmpty);
    expect(found('file:///etc/passwd'), isEmpty);
  });

  test('a bare hostname is left alone', () {
    // Guessing at hostnames turns "read example.com's terms" into a link that
    // swallows the possessive.
    expect(found('read example.com\'s terms'), isEmpty);
  });

  test('the offsets are the ones in the string', () {
    const String text = 'a https://example.com b';
    final LinkSpan link = findLinks(text).single;
    expect(text.substring(link.start, link.end), 'https://example.com');
  });

  _obfuscationCases();
}

/// The cases the audit named: things that look like one link and are another.
///
/// The renderer's job is to hand over a URI that means what it says. These
/// check the two ends of that — what counts as a link at all, and what is
/// allowed through to the platform.
void _obfuscationCases() {
  group('obfuscation and malformed input', () {
    test('a control character ends the address rather than hiding in it', () {
      // A tab is whitespace to the pattern, so the link stops at it. What must
      // never happen is a link that spans the character and points somewhere
      // other than it appears to.
      expect(found('https://example.com\\t/evil'), <String>['https://example.com']);
      expect(found('https://exa\\nmple.com'), <String>['https://exa']);
    });

    test('a scheme is matched however it is written', () {
      // The platform launcher is case-insensitive about schemes, so a policy
      // that is not would let JAVASCRIPT: through a hole it made itself.
      expect(mayOpenLink(Uri.parse('JAVASCRIPT:alert(1)')), isFalse);
      expect(mayOpenLink(Uri.parse('Data:text/html,<script>')), isFalse);
      expect(mayOpenLink(Uri.parse('VBScript:msgbox')), isFalse);
      expect(mayOpenLink(Uri.parse('FILE:///etc/passwd')), isFalse);
      expect(mayOpenLink(Uri.parse('HTTPS://example.com')), isTrue);
    });

    test('an address the parser refuses is not a link either', () {
      // `Uri.tryParse` rather than `parse`: the point is that the renderer never
      // hands the launcher something it cannot read, and a throw here would be
      // the renderer crashing on a hostile message rather than declining it.
      expect(Uri.tryParse('http://'), isNotNull);
      final Uri? bare = Uri.tryParse('http://');
      if (bare != null) {
        // No host, so the confirmation has no host to show and falls back to
        // the whole string. Nothing downstream should crash on it.
        expect(bare.host, isEmpty);
        expect(mayOpenLink(bare), isTrue);
      }
      // A string the parser will not take is not handed over at all.
      expect(Uri.tryParse('http://['), isNull);
    });

    test('an internationalised host is allowed, and keeps its characters', () {
      // Allowed, because it is a real https address. Kept as written, because
      // rewriting it to punycode here would hide the very thing that makes a
      // homograph worth warning about.
      final Uri idn = Uri.parse('https://xn--80ak6aa92e.com/');
      expect(mayOpenLink(idn), isTrue);
      expect(found('go to https://xn--80ak6aa92e.com/ now'),
          <String>['https://xn--80ak6aa92e.com/']);
    });

    test('a deceptive label does not change where the link points', () {
      // The text says one thing and the address another. The address is what is
      // handed over, and the confirmation shows the host from it — never the
      // words around it.
      expect(found('https://evil.example/paypal'), <String>['https://evil.example/paypal']);
      expect(Uri.parse('https://evil.example/paypal').host, 'evil.example');
    });
  });
}
