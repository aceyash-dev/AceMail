import 'package:ace_mail/data/limits.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/message_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

/// The renderer is a maintained package now. What is left to test here is
/// everything the app still decides: which links may leave the app, and which
/// images may load.
Widget host(String html, {bool loadRemoteImages = false}) => MaterialApp(
      theme: buildAstryxTheme(Brightness.light),
      home: Scaffold(
        body: AceHtml(
          html: html,
          baseStyle: AstryxText.body(const Color(0xFF111111)),
          linkColor: const Color(0xFF0055FF),
          codeStyle: AstryxText.body(const Color(0xFF111111)),
          loadRemoteImages: loadRemoteImages,
        ),
      ),
    );

void main() {
  setUpAll(() {
    // The renderer's loading placeholder is a spinner by design, and a spinner
    // never settles — which is all `pumpAndSettle` would ever hear about. This
    // makes it a static widget instead, for tests only.
    WidgetFactory.debugDeterministicLoadingWidget = true;
  });

  group('AceHtml.mayOpen', () {
    test('http and https may leave', () {
      expect(AceHtml.mayOpen(Uri.parse('https://example.com')), isTrue);
      expect(AceHtml.mayOpen(Uri.parse('http://example.com')), isTrue);
    });

    test('mailto may, because this is a mail client', () {
      expect(AceHtml.mayOpen(Uri.parse('mailto:a@example.com')), isTrue);
    });

    test('the schemes that are not links are refused', () {
      for (final String url in <String>[
        'javascript:alert(1)',
        'data:text/html;base64,PHNjcmlwdD4=',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'content://com.example/secret',
        'tel:+1234',
      ]) {
        expect(AceHtml.mayOpen(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('the scheme is matched however it is cased', () {
      expect(AceHtml.mayOpen(Uri.parse('HTTPS://example.com')), isTrue);
      expect(AceHtml.mayOpen(Uri.parse('JavaScript:alert(1)')), isFalse);
    });
  });

  group('AceHtml', () {
    testWidgets('renders the text of a message', (WidgetTester tester) async {
      await tester.pumpWidget(host('<p>Hello <b>there</b></p>'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello', findRichText: true), findsOneWidget);
    });

    testWidgets('does not fetch a remote image', (WidgetTester tester) async {
      await tester.pumpWidget(
        host('<p>Logo: <img src="https://tracker.example/pixel.png" alt="Acme"></p>'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(Image),
        findsNothing,
        reason: 'fetching it would tell the sender the message was opened',
      );
      expect(
        find.text('Acme', findRichText: true),
        findsOneWidget,
        reason: 'the description the sender wrote is shown instead',
      );
    });

    testWidgets('a script is not rendered as text', (WidgetTester tester) async {
      await tester.pumpWidget(host('<p>hi</p><script>alert("x")</script>'));
      await tester.pumpAndSettle();

      expect(find.textContaining('alert', findRichText: true), findsNothing);
      expect(find.textContaining('hi', findRichText: true), findsOneWidget);
    });

    testWidgets('a style block is not rendered as text', (WidgetTester tester) async {
      await tester.pumpWidget(
        host('<style>.a{color:red}</style><p>body</p>'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('color:red', findRichText: true), findsNothing);
      expect(find.textContaining('body', findRichText: true), findsOneWidget);
    });

    testWidgets('an oversized body does not hang the frame',
        (WidgetTester tester) async {
      // The cap is applied before the parser sees it: a ten-megabyte HTML part
      // is not a message, it is an attack on the frame budget.
      await tester.pumpWidget(
        host('<p>${'x' * (MailLimits.maxHtmlBytes + 1000)}</p>'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AceHtml), findsOneWidget);
    });
  });
}
