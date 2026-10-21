import 'package:ace_mail/util/html_render.dart';
import 'package:ace_mail/widgets/html_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlImage.resolved', () {
    test('a plain https source is used as-is', () {
      expect(
        const HtmlImage(source: 'https://cdn.example/logo.png').resolved,
        'https://cdn.example/logo.png',
      );
    });

    test('a protocol-relative source gets https', () {
      // Mail is full of `//cdn.example/logo.png`. Treating it as unfetchable
      // lost most of the images in the messages that use a CDN.
      expect(
        const HtmlImage(source: '//cdn.example/logo.png').resolved,
        'https://cdn.example/logo.png',
      );
    });

    test('an embedded part is not fetchable', () {
      expect(const HtmlImage(source: 'cid:logo@example').resolved, isNull);
    });

    test('a relative path is not fetchable', () {
      expect(const HtmlImage(source: '/images/logo.png').resolved, isNull);
    });

    test('nothing at all is nothing', () {
      expect(const HtmlImage().resolved, isNull);
      expect(const HtmlImage(source: '   ').resolved, isNull);
    });
  });

  group('tracking pixels', () {
    String textOf(List<InlineSpan> spans) => spans
        .whereType<TextSpan>()
        .map((TextSpan s) => s.text ?? '')
        .join();

    HtmlRenderer renderer() => HtmlRenderer(
          baseStyle: const TextStyle(),
          linkColor: const Color(0xFF000000),
          codeStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        );

    test('a 1x1 beacon is dropped entirely', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<p>Hello</p><img src="https://track.example/p.gif" width="1" height="1">',
      );
      // A placeholder for an invisible pixel puts an "Image" chip in the middle
      // of a message that has no images in it.
      expect(spans.whereType<WidgetSpan>(), isEmpty);
      expect(textOf(spans), contains('Hello'));
      r.dispose();
    });

    test('a real image is still shown', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<img src="https://cdn.example/logo.png" alt="Logo" width="600" height="200">',
      );
      expect(spans.whereType<WidgetSpan>(), isNotEmpty);
      r.dispose();
    });

    test('a single small dimension is a layout trick, not a beacon', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<img src="https://cdn.example/rule.png" height="1">',
      );
      expect(spans.whereType<WidgetSpan>(), isNotEmpty);
      r.dispose();
    });
  });
}
