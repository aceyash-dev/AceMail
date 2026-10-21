import 'package:ace_mail/util/html_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HtmlRenderer renderer() => HtmlRenderer(
      baseStyle: const TextStyle(fontSize: 14),
      linkColor: const Color(0xFFEE0000),
      codeStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );

String textOf(List<InlineSpan> spans) => spans
    .whereType<TextSpan>()
    .map((TextSpan s) => s.text ?? '')
    .join();

TextStyle styleOf(List<InlineSpan> spans, String text) =>
    spans
        .whereType<TextSpan>()
        .firstWhere((TextSpan s) => (s.text ?? '').contains(text))
        .style!;

void main() {
  group('CSS in a style block', () {
    test('a class rule sets the colour', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>.red { color: #ff0000; }</style><p class="red">Hello</p>',
      );
      expect(styleOf(spans, 'Hello').color, const Color(0xFFFF0000));
      r.dispose();
    });

    test('a tag rule sets the weight', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans =
          r.render('<style>strong { font-weight: 700; }</style><strong>Bold</strong>');
      expect(styleOf(spans, 'Bold').fontWeight, FontWeight.w600);
      r.dispose();
    });

    test('later rules win', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>.a { color: #ff0000; } .a { color: #0000ff; }</style>'
        '<p class="a">Hello</p>',
      );
      expect(styleOf(spans, 'Hello').color, const Color(0xFF0000FF));
      r.dispose();
    });

    test('a style attribute beats a rule', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>p { color: #ff0000; }</style>'
        '<p style="color: #00ff00">Hello</p>',
      );
      expect(styleOf(spans, 'Hello').color, const Color(0xFF00FF00));
      r.dispose();
    });

    test('an id rule matches', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>#head { font-style: italic; }</style><p id="head">Hi</p>',
      );
      expect(styleOf(spans, 'Hi').fontStyle, FontStyle.italic);
      r.dispose();
    });

    test('the last part of a descendant selector decides', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>div.footer a { color: #123456; }</style>'
        '<div class="footer"><a href="https://x.example">link</a></div>',
      );
      expect(styleOf(spans, 'link').color, const Color(0xFF123456));
      r.dispose();
    });

    test('a selector it does not understand is skipped, not guessed at', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>p:hover { color: #ff0000; }</style><p>Hello</p>',
      );
      // The base colour, not red.
      expect(styleOf(spans, 'Hello').color, isNot(const Color(0xFFFF0000)));
      r.dispose();
    });
  });

  group('CSS properties', () {
    test('uppercase is applied to the text', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>.up { text-transform: uppercase; }</style>'
        '<p class="up">quiet</p>',
      );
      expect(textOf(spans), contains('QUIET'));
      r.dispose();
    });

    test('a font size scales the base', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>.big { font-size: 200%; }</style><p class="big">Big</p>',
      );
      expect(styleOf(spans, 'Big').fontSize, closeTo(28, 0.01));
      r.dispose();
    });

    test('an absurd font size is capped rather than obeyed', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<p style="font-size: 400px">Huge</p>',
      );
      // 2x the base, not 25x.
      expect(styleOf(spans, 'Huge').fontSize, closeTo(28, 0.01));
      r.dispose();
    });

    test('a named colour is understood', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render('<p style="color: red">Red</p>');
      expect(styleOf(spans, 'Red').color, isNotNull);
      r.dispose();
    });

    test('text-decoration none clears an underline', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>u { text-decoration: none; }</style><u>Plain</u>',
      );
      expect(styleOf(spans, 'Plain').decoration, isNot(TextDecoration.underline));
      r.dispose();
    });
  });

  group('no JavaScript, still', () {
    test('a script block contributes nothing', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<script>alert(1)</script><p>Safe</p>',
      );
      expect(textOf(spans), contains('Safe'));
      expect(textOf(spans), isNot(contains('alert')));
      r.dispose();
    });

    test('a script inside a styled block is still dropped', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<div class="x"><script>evil()</script>Text</div>',
      );
      expect(textOf(spans), isNot(contains('evil')));
      r.dispose();
    });

    test('a url() in CSS never becomes a request', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>p { background: url(https://track.example/p.gif); }</style>'
        '<p>Hello</p>',
      );
      expect(textOf(spans), isNot(contains('track.example')));
      r.dispose();
    });
  });
}
