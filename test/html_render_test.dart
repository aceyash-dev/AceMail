import 'package:ace_mail/util/html_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HtmlRenderer build() => HtmlRenderer(
        baseStyle: const TextStyle(fontSize: 14),
        linkColor: const Color(0xFFFF6A1A),
        codeStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      );

  String textOf(List<InlineSpan> spans) =>
      spans.map((InlineSpan s) => (s as TextSpan).text ?? '').join();

  group('HtmlRenderer', () {
    test('renders a realistic document without throwing', () {
      // Regression: the tag-stripping regexes used inline flags (?is)/(?s),
      // which Dart's RegExp rejects with FormatException on first use — so
      // opening any HTML message crashed the app.
      final HtmlRenderer renderer = build();
      final List<InlineSpan> spans = renderer.render(
        '<html><head><style>p{color:red}</style></head>'
        '<body><!-- note --><script>alert(1)</script>'
        '<p>Hello <strong>world</strong></p></body></html>',
      );
      expect(spans, isNotEmpty);
      renderer.dispose();
    });

    test('drops script, style and comment content', () {
      final HtmlRenderer renderer = build();
      final String text = textOf(
        renderer.render('<style>a{}</style><script>bad()</script>Keep me'),
      );
      expect(text, contains('Keep me'));
      expect(text, isNot(contains('bad()')));
      expect(text, isNot(contains('a{}')));
      renderer.dispose();
    });

    test('decodes named and numeric entities', () {
      final HtmlRenderer renderer = build();
      expect(
        textOf(renderer.render('Milk &amp; Orange &mdash; &#8377;499')),
        'Milk & Orange — ₹499',
      );
      renderer.dispose();
    });

    test('marks strong text bold', () {
      final HtmlRenderer renderer = build();
      final Iterable<TextSpan> spans =
          renderer.render('<b>bold</b>').cast<TextSpan>();
      final TextSpan styled =
          spans.firstWhere((TextSpan s) => s.text == 'bold');
      expect(styled.style?.fontWeight, FontWeight.w600);
      renderer.dispose();
    });

    test('gives links an accent colour and a tap recogniser', () {
      final HtmlRenderer renderer = build();
      final Iterable<TextSpan> spans =
          renderer.render('<a href="https://example.com">site</a>')
              .cast<TextSpan>();
      final TextSpan styled =
          spans.firstWhere((TextSpan s) => s.text == 'site');
      expect(styled.recognizer, isNotNull);
      expect(styled.style?.color, const Color(0xFFFF6A1A));
      renderer.dispose();
    });

    test('separates paragraphs with a blank line', () {
      final HtmlRenderer renderer = build();
      final String text = textOf(renderer.render('<p>One</p><p>Two</p>'));
      expect(text.contains('\n'), isTrue);
      expect(text.trimLeft().startsWith('One'), isTrue);
      renderer.dispose();
    });
  });
}
