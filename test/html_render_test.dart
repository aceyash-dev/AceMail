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

  TextSpan spanFor(List<InlineSpan> spans, String text) =>
      spans.cast<TextSpan>().firstWhere((TextSpan s) => s.text == text);

  group('HtmlRenderer', () {
    test('renders a realistic document without throwing', () {
      final HtmlRenderer renderer = build();
      final List<InlineSpan> spans = renderer.render(
        '<html><head><style>p{color:red}</style></head>'
        '<body><!-- c --><script>alert(1)</script>'
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
      expect(
        spanFor(renderer.render('<b>bold</b>'), 'bold').style?.fontWeight,
        FontWeight.w600,
      );
      renderer.dispose();
    });

    test('separates paragraphs with a blank line', () {
      final HtmlRenderer renderer = build();
      final String text = textOf(renderer.render('<p>One</p><p>Two</p>'));
      expect(text, contains('\n'));
      expect(text.trimLeft().startsWith('One'), isTrue);
      renderer.dispose();
    });

    test('keeps unclosed and mis-nested markup readable', () {
      final HtmlRenderer renderer = build();
      final String text = textOf(
        renderer.render('<p>One<b>two<p>three</b>four</p>'),
      );
      expect(text, contains('One'));
      expect(text, contains('two'));
      expect(text, contains('three'));
      expect(text, contains('four'));
      renderer.dispose();
    });
  });

  group('link policy', () {
    test('gives an https link a tap recogniser and the accent colour', () {
      final HtmlRenderer renderer = build();
      final TextSpan span =
          spanFor(renderer.render('<a href="https://example.com">site</a>'), 'site');
      expect(span.recognizer, isNotNull);
      expect(span.style?.color, const Color(0xFFFF6A1A));
      renderer.dispose();
    });

    test('allows http and mailto', () {
      final HtmlRenderer renderer = build();
      for (final String href in <String>[
        'http://example.com',
        'mailto:someone@example.com',
      ]) {
        final TextSpan span =
            spanFor(renderer.render('<a href="$href">link</a>'), 'link');
        expect(span.recognizer, isNotNull, reason: '$href should be allowed');
      }
      renderer.dispose();
    });

    test('refuses every other scheme', () {
      final HtmlRenderer renderer = build();
      for (final String href in <String>[
        'javascript:alert(1)',
        'data:text/html;base64,PHNjcmlwdD4=',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'content://com.example/secret',
        'tel:+911234567890',
      ]) {
        final TextSpan span =
            spanFor(renderer.render('<a href="$href">link</a>'), 'link');
        expect(
          span.recognizer,
          isNull,
          reason: '$href must not be openable',
        );
        expect(span.style?.color, isNot(const Color(0xFFFF6A1A)));
      }
      renderer.dispose();
    });

    test('refuses a scheme smuggled past a control-character strip', () {
      final HtmlRenderer renderer = build();
      final TextSpan span = spanFor(
        renderer.render('<a href="java\tscript:alert(1)">link</a>'),
        'link',
      );
      expect(span.recognizer, isNull);
      renderer.dispose();
    });

    test('refuses a web link with no host', () {
      final HtmlRenderer renderer = build();
      final TextSpan span =
          spanFor(renderer.render('<a href="https:///nohost">link</a>'), 'link');
      expect(span.recognizer, isNull);
      renderer.dispose();
    });
  });

  group('hostile input', () {
    test('survives deeply nested tags', () {
      final HtmlRenderer renderer = build();
      final String nested = '${'<div>' * 400}deep${'</div>' * 400}';
      expect(() => renderer.render(nested), returnsNormally);
      renderer.dispose();
    });

    test('survives malformed and truncated markup', () {
      final HtmlRenderer renderer = build();
      for (final String html in <String>[
        '<p><b><i>unclosed',
        '<<<>>>',
        '<a href="',
        '<!-- unterminated comment',
        '<table><tr><td>cell',
        '</div></p></b>',
        '<img src=x onerror=alert(1)>',
      ]) {
        expect(() => renderer.render(html), returnsNormally, reason: html);
      }
      renderer.dispose();
    });

    test('an image never becomes active content, only its alt text', () {
      final HtmlRenderer renderer = build();
      final String text =
          textOf(renderer.render('<img src="https://tracker.example/p.gif" alt="Logo">'));
      expect(text, '[Logo]');
      expect(text, isNot(contains('tracker.example')));
      renderer.dispose();
    });

    test('drops an iframe and an svg entirely', () {
      final HtmlRenderer renderer = build();
      final String text = textOf(
        renderer.render('<iframe src="https://evil.example"></iframe>'
            '<svg><script>alert(1)</script></svg>Visible'),
      );
      expect(text, contains('Visible'));
      expect(text, isNot(contains('evil.example')));
      expect(text, isNot(contains('alert')));
      renderer.dispose();
    });
  });
}
