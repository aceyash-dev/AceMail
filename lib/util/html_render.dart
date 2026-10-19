import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A small, self-contained HTML → rich text converter.
///
/// Mail bodies are HTML, and a full browser-grade renderer is both heavy and
/// the wrong shape for untrusted content. This handles the subset mail
/// actually uses — paragraphs, line breaks, emphasis, links, lists, headings,
/// quotes, preformatted text — and ignores everything else. No scripts, no
/// remote layout, no surprises.
///
/// Call [dispose] when the spans are no longer needed: link spans carry tap
/// recognisers that must be released.
class HtmlRenderer {
  HtmlRenderer({
    required this.baseStyle,
    required this.linkColor,
    required this.codeStyle,
  });

  final TextStyle baseStyle;
  final Color linkColor;
  final TextStyle codeStyle;

  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  static final RegExp _tag = RegExp(r'<\s*/?\s*([a-zA-Z][a-zA-Z0-9]*)([^>]*)>');
  static final RegExp _droppable = RegExp(
    r'<(script|style|head|title)[^>]*>.*?</\1\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _comment = RegExp(r'<!--.*?-->', dotAll: true);
  static final RegExp _whitespace = RegExp(r'[ \t\r\n]+');

  static const Set<String> _block = <String>{
    'p',
    'div',
    'section',
    'article',
    'header',
    'footer',
    'main',
    'aside',
    'blockquote',
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'ul',
    'ol',
    'pre',
    'figure',
    'figcaption',
    'dl',
    'dt',
    'dd',
  };
  static const Set<String> _heading = <String>{
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  /// Converts [html] into styled spans.
  List<InlineSpan> render(String html) {
    dispose();

    final String source =
        html.replaceAll(_comment, '').replaceAll(_droppable, '');

    final List<InlineSpan> spans = <InlineSpan>[];
    final StringBuffer pending = StringBuffer();
    final List<_Frame> frames = <_Frame>[const _Frame()];
    final List<bool> lists = <bool>[];
    final List<int> counters = <int>[];
    int breaks = 0;
    int position = 0;

    void flush() {
      if (pending.isEmpty) return;
      final _Frame frame = frames.last;
      TapGestureRecognizer? recognizer;
      final String? href = frame.href;
      if (href != null) {
        recognizer = TapGestureRecognizer()..onTap = () => _open(href);
        _recognizers.add(recognizer);
      }
      spans.add(TextSpan(
        text: pending.toString(),
        style: frame.resolve(baseStyle, linkColor, codeStyle),
        recognizer: recognizer,
      ));
      pending.clear();
    }

    void write(String raw) {
      String text = _decodeEntities(raw);
      if (text.isEmpty) return;
      if (!frames.last.pre) text = text.replaceAll(_whitespace, ' ');
      if (text.isEmpty) return;
      if (breaks > 0) {
        // Never lead the document with blank lines.
        if (!(spans.isEmpty && pending.isEmpty)) {
          pending.write('\n' * (breaks > 2 ? 2 : breaks));
        }
        breaks = 0;
      }
      pending.write(text);
    }

    void lineBreak(int count) {
      if (spans.isEmpty && pending.isEmpty) return;
      if (count > breaks) breaks = count;
    }

    void handleTag(String raw, String name, String attributes, bool closing) {
      flush();
      if (name == 'br') {
        lineBreak(1);
        return;
      }
      if (name == 'hr') {
        lineBreak(2);
        pending.write('———');
        lineBreak(2);
        return;
      }
      if (name == 'li') {
        if (closing) {
          lineBreak(2);
          return;
        }
        lineBreak(1);
        if (lists.isNotEmpty && lists.last) {
          counters[counters.length - 1] += 1;
          pending.write('${counters.last}. ');
        } else {
          pending.write('• ');
        }
        return;
      }
      if (name == 'ul' || name == 'ol') {
        if (closing) {
          if (lists.isNotEmpty) lists.removeLast();
          if (counters.isNotEmpty) counters.removeLast();
          lineBreak(2);
        } else {
          lists.add(name == 'ol');
          counters.add(0);
          lineBreak(2);
        }
        return;
      }
      if (_heading.contains(name)) {
        if (closing) {
          frames.removeLast();
          lineBreak(2);
        } else {
          lineBreak(2);
          frames.add(frames.last.copyWith(bold: true, scale: 1.15));
        }
        return;
      }
      if (_block.contains(name)) {
        if (closing) lineBreak(2);
        return;
      }
      switch (name) {
        case 'b':
        case 'strong':
          _toggle(frames, closing, bold: true);
        case 'i':
        case 'em':
          _toggle(frames, closing, italic: true);
        case 'u':
        case 'ins':
          _toggle(frames, closing, underline: true);
        case 'code':
        case 'tt':
        case 'kbd':
        case 'samp':
          _toggle(frames, closing, code: true);
        case 'pre':
          _toggle(frames, closing, pre: true, code: true);
        case 'a':
          if (closing) {
            frames.removeLast();
          } else {
            frames.add(frames.last.copyWith(href: _hrefOf(attributes)));
          }
        case 'img':
          if (!closing) write(_altOf(attributes) ?? '[image]');
      }
    }

    for (final RegExpMatch match in _tag.allMatches(source)) {
      write(source.substring(position, match.start));
      position = match.end;
      handleTag(
        match.group(0)!,
        match.group(1)!.toLowerCase(),
        match.group(2) ?? '',
        match.group(0)!.startsWith('</'),
      );
    }
    write(source.substring(position));
    flush();

    return spans;
  }

  static void _toggle(
    List<_Frame> frames,
    bool closing, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool code = false,
    bool pre = false,
  }) {
    if (closing) {
      if (frames.length > 1) frames.removeLast();
      return;
    }
    frames.add(frames.last.copyWith(
      bold: bold,
      italic: italic,
      underline: underline,
      code: code,
      pre: pre,
    ));
  }

  static String? _hrefOf(String attributes) {
    final RegExpMatch? match = RegExp(
            r'''href\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))''',
            caseSensitive: false)
        .firstMatch(attributes);
    if (match == null) return null;
    return match.group(2) ?? match.group(3) ?? match.group(4);
  }

  static String? _altOf(String attributes) {
    final RegExpMatch? match = RegExp(
            r'''alt\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))''',
            caseSensitive: false)
        .firstMatch(attributes);
    if (match == null) return null;
    final String? value = match.group(2) ?? match.group(3) ?? match.group(4);
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  static Uri? _normalize(String href) {
    final String trimmed = href.trim();
    if (trimmed.isEmpty) return null;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.hasScheme) return uri;
    return Uri.tryParse('https://$trimmed');
  }

  static void _open(String href) {
    final Uri? uri = _normalize(href);
    if (uri == null) return;
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication)
          .catchError((Object _) => false),
    );
  }

  static String _decodeEntities(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(
      RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
      (Match match) {
        final String body = match.group(1)!;
        if (body.startsWith('#')) {
          final bool hex = body.startsWith('#x') || body.startsWith('#X');
          final int? code = int.tryParse(
            body.substring(hex ? 2 : 1),
            radix: hex ? 16 : 10,
          );
          if (code == null) return match.group(0)!;
          return String.fromCharCode(code);
        }
        return _namedEntities[body.toLowerCase()] ?? match.group(0)!;
      },
    );
  }

  static const Map<String, String> _namedEntities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'lsquo': '‘',
    'rsquo': '’',
    'ldquo': '“',
    'rdquo': '”',
    'laquo': '«',
    'raquo': '»',
    'middot': '·',
    'bull': '•',
    'trade': '™',
    'copy': '©',
    'reg': '®',
    'euro': '€',
    'pound': '£',
    'rupee': '₹',
    'times': '×',
    'deg': '°',
  };
}

class _Frame {
  const _Frame({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.pre = false,
    this.scale = 1,
    this.href,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final bool pre;
  final double scale;
  final String? href;

  _Frame copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? code,
    bool? pre,
    double? scale,
    String? href,
  }) =>
      _Frame(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        code: code ?? this.code,
        pre: pre ?? this.pre,
        scale: scale ?? this.scale,
        href: href ?? this.href,
      );

  TextStyle resolve(
    TextStyle base,
    Color linkColor,
    TextStyle codeStyle,
  ) {
    TextStyle style = code ? codeStyle : base;
    if (scale != 1) {
      style = style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
    }
    if (bold) style = style.copyWith(fontWeight: FontWeight.w600);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (underline || href != null) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    if (href != null) style = style.copyWith(color: linkColor);
    return style;
  }
}
