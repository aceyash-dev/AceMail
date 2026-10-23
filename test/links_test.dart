import 'package:ace_mail/util/links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> found(String text) =>
      findLinks(text).map((LinkSpan l) => l.uri.toString()).toList();

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
}
