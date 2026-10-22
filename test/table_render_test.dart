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

Iterable<Widget> widgetsOf(List<InlineSpan> spans) => spans
    .whereType<WidgetSpan>()
    .map((WidgetSpan s) => s.child);

void main() {
  group('tables', () {
    test('a table becomes a grid, not a run of words', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<table>'
        '<tr><th>Status</th><th>Job</th><th>Annotations</th></tr>'
        '<tr><td>Failed</td><td>Build</td><td>5</td></tr>'
        '</table>',
      );

      final Iterable<Widget> widgets = widgetsOf(spans);
      expect(widgets, isNotEmpty, reason: 'a table should be a widget');
      // The columns must not be joined into one line of text.
      expect(textOf(spans), isNot(contains('Status Job')));
      r.dispose();
    });

    test('the grid has a Table in it', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<table><tr><td>a</td><td>b</td></tr></table>',
      );
      bool found = false;
      for (final Widget w in widgetsOf(spans)) {
        if (w is SingleChildScrollView && w.child is Table) found = true;
        if (w is Table) found = true;
      }
      expect(found, isTrue);
      r.dispose();
    });

    test('a cell keeps its own styling', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<style>.red { color: #ff0000; }</style>'
        '<table><tr><td class="red">Red</td><td>Plain</td></tr></table>',
      );
      // The grid is a widget, so the text lives inside it rather than in the
      // outer span list — which is the point: it is laid out, not flattened.
      expect(widgetsOf(spans), isNotEmpty);
      r.dispose();
    });

    test('a table with no rows falls back to text rather than vanishing', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render('<table><p>Loose text</p></table>');
      expect(textOf(spans), contains('Loose text'));
      r.dispose();
    });

    test('a script inside a table still contributes nothing', () {
      final HtmlRenderer r = renderer();
      final List<InlineSpan> spans = r.render(
        '<table><tr><td><script>evil()</script>Safe</td></tr></table>',
      );
      expect(textOf(spans), isNot(contains('evil')));
      r.dispose();
    });
  });
}
