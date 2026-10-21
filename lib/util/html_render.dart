import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../data/limits.dart';

/// Converts an HTML mail body into styled spans.
///
/// Parsing is done with `package:html`, a real HTML parser, rather than regular
/// expressions: mail is full of unclosed tags and deeply nested tables, and a
/// tokenizer that guesses at that produces wrong text and wrong style state.
/// Scripts, styles, remote images and active content are dropped, links are
/// restricted to schemes we are willing to open, and the document is capped.
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

  /// The only schemes Ace Mail will hand to the platform launcher. Everything
  /// else — `javascript:`, `data:`, `file:`, `intent:`, and arbitrary app
  /// schemes — is discarded. `mailto:` is a deliberate exception because this
  /// is a mail client.
  static const Set<String> _allowedSchemes = <String>{'http', 'https', 'mailto'};

  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> render(String html) {
    dispose();

    final String source = html.length > MailLimits.maxHtmlBytes
        ? html.substring(0, MailLimits.maxHtmlBytes)
        : html;

    final _Builder builder = _Builder(
      baseStyle: baseStyle,
      linkColor: linkColor,
      codeStyle: codeStyle,
    );

    try {
      final dom.Document document = html_parser.parse(source);
      final dom.Element? body = document.body;
      if (body != null) {
        builder.walk(body);
      } else {
        builder.write(source);
      }
    } catch (_) {
      // Parsing must never take the reader down; show the raw text instead.
      builder.write(source.replaceAll(RegExp(r'<[^>]*>'), ' '));
    }

    builder.finish();
    _recognizers.addAll(builder.recognizers);
    return builder.spans;
  }
}

/// Walks the parsed document, accumulating text under a stack of styles and
/// flushing a span whenever the style changes or a block boundary is reached.
class _Builder {
  _Builder({
    required this.baseStyle,
    required this.linkColor,
    required this.codeStyle,
  });

  final TextStyle baseStyle;
  final Color linkColor;
  final TextStyle codeStyle;

  final List<InlineSpan> spans = <InlineSpan>[];
  final List<TapGestureRecognizer> recognizers = <TapGestureRecognizer>[];

  final StringBuffer _text = StringBuffer();
  final List<_Frame> _frames = <_Frame>[const _Frame()];
  final List<bool> _ordered = <bool>[];
  final List<int> _counters = <int>[];
  int _breaks = 0;
  int _depth = 0;
  bool _inRow = false;

  static const Set<String> _skipped = <String>{
    'script', 'style', 'head', 'title', 'noscript', 'template', 'svg', 'iframe',
  };

  /// Emphasis stated in a `style` attribute rather than a tag — which is how a
  /// lot of mail is written, and which was being thrown away.
  static final RegExp _boldStyle =
      RegExp(r'font-weight\s*:\s*(bold|[6-9]00)', caseSensitive: false);
  static final RegExp _italicStyle =
      RegExp(r'font-style\s*:\s*italic', caseSensitive: false);
  static final RegExp _underlineStyle =
      RegExp(r'text-decoration[^;]*underline', caseSensitive: false);

  /// How deep the walk will go. Mail with thousands of nested divs is not
  /// hypothetical, and recursing through it is how a reader hangs.
  static const int _maxDepth = 60;

  static const Set<String> _blocks = <String>{
    'address', 'article', 'aside', 'blockquote', 'dd', 'div', 'dl', 'dt',
    'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
    'h4', 'h5', 'h6', 'header', 'hr', 'li', 'main', 'nav', 'ol', 'p', 'pre',
    'section', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr', 'ul',
  };

  _Frame get _frame => _frames.last;

  void walk(dom.Node node) {
    for (final dom.Node child in node.nodes) {
      if (child is dom.Text) {
        write(child.text);
      } else if (child is dom.Element) {
        element(child);
      }
    }
  }

  void element(dom.Element node) {
    final String tag = node.localName?.toLowerCase() ?? '';

    if (_skipped.contains(tag)) return;
    if (_depth >= _maxDepth) return;

    switch (tag) {
      case 'br':
        _break(1);
        return;
      case 'hr':
        _break(2);
        write('——————');
        _break(2);
        return;
      case 'li':
        _break(1);
        write(_bullet());
        _push(_frame.copyWith());
        walk(node);
        _pop();
        _break(1);
        return;
      case 'ul':
        _ordered.add(false);
        _counters.add(0);
        _break(2);
        walk(node);
        _ordered.removeLast();
        _counters.removeLast();
        _break(2);
        return;
      case 'ol':
        _ordered.add(true);
        _counters.add(0);
        _break(2);
        walk(node);
        _ordered.removeLast();
        _counters.removeLast();
        _break(2);
        return;
      case 'img':
        final String alt = node.attributes['alt']?.trim() ?? '';
        if (alt.isNotEmpty) write('[$alt]');
        return;
      // A table is a grid on the web and a column here, so rows break and cells
      // are separated. Without this every cell ran into the next one.
      case 'tr':
        _inRow = false;
        _break(2);
        _depth++;
        walk(node);
        _depth--;
        _break(2);
        return;
      case 'td':
      case 'th':
        if (_inRow) write('   ');
        _inRow = true;
        _depth++;
        walk(node);
        _depth--;
        return;
    }

    final bool block = _blocks.contains(tag);
    if (block) _break(2);

    final String style = node.attributes['style'] ?? '';
    final bool bold = tag == 'b' ||
        tag == 'strong' ||
        _isHeading(tag) ||
        _boldStyle.hasMatch(style);
    final bool italic =
        tag == 'i' || tag == 'em' || _italicStyle.hasMatch(style);
    final bool underline =
        tag == 'u' || tag == 'ins' || _underlineStyle.hasMatch(style);
    final bool code = tag == 'code' || tag == 'pre' || tag == 'kbd' || tag == 'tt';
    final String? href = tag == 'a' ? _safeHref(node.attributes['href']) : null;

    _push(
      _frame.copyWith(
        bold: _frame.bold || bold,
        italic: _frame.italic || italic,
        underline: _frame.underline || underline,
        code: _frame.code || code,
        href: href ?? _frame.href,
      ),
    );
    _depth++;
    walk(node);
    _depth--;
    _pop();

    if (block) _break(2);
  }

  /// Text already written belongs to the style it was written in, so the buffer
  /// is closed before the style changes and after it changes back.
  void _push(_Frame frame) {
    _flush();
    _frames.add(frame);
  }

  void _pop() {
    _flush();
    _frames.removeLast();
  }

  static bool _isHeading(String tag) =>
      tag.length == 2 && tag.startsWith('h') && int.tryParse(tag[1]) != null;

  String _bullet() {
    if (_ordered.isEmpty || !_ordered.last) return '• ';
    _counters[_counters.length - 1]++;
    return '${_counters.last}. ';
  }

  void _break(int count) {
    if (count > _breaks) _breaks = count;
  }

  void write(String raw) {
    if (raw.isEmpty) return;

    // Collapse runs of whitespace the way HTML does, except inside <pre>.
    final String text = _frame.code
        ? raw
        : raw.replaceAll(RegExp(r'[ \t\r\n\u00a0]+'), ' ');
    if (text.isEmpty) return;

    // Whitespace-only content between two blocks carries no meaning, but it
    // would still emit its paragraph break — and a layout table has hundreds of
    // empty cells, which is how a short message ends up screens tall.
    if (_breaks > 0 && text.trim().isEmpty) return;

    if (_text.isEmpty && spans.isEmpty) {
      _breaks = 0; // never start a document with blank lines
    }
    if (_breaks > 0) {
      _text.write('\n' * _breaks);
      _breaks = 0;
    }
    _text.write(text);
  }

  void finish() {
    _flush();
  }

  void _flush() {
    if (_text.isEmpty) return;

    final _Frame frame = _frame;
    TapGestureRecognizer? recognizer;
    final String? href = frame.href;
    if (href != null) {
      recognizer = TapGestureRecognizer()..onTap = () => _open(href);
      recognizers.add(recognizer);
    }

    spans.add(
      TextSpan(
        text: _text.toString(),
        style: frame.styleFor(baseStyle, linkColor, codeStyle),
        recognizer: recognizer,
      ),
    );
    _text.clear();
  }

  /// Only http, https and mailto survive; anything else is dropped entirely.
  static String? _safeHref(String? raw) {
    if (raw == null) return null;

    // Control characters can be used to smuggle a scheme past a naive check.
    final String cleaned = raw.replaceAll(RegExp(r'[\x00-\x20\x7f]'), '');
    if (cleaned.isEmpty) return null;

    Uri? parsed = Uri.tryParse(cleaned);
    if (parsed == null) return null;

    if (!parsed.hasScheme) {
      parsed = Uri.tryParse('https://$cleaned');
      if (parsed == null) return null;
    }

    final String scheme = parsed.scheme.toLowerCase();
    if (!HtmlRenderer._allowedSchemes.contains(scheme)) return null;

    // A web link with no host is not a web link.
    if (scheme != 'mailto' && parsed.host.isEmpty) return null;

    return parsed.toString();
  }

  static Future<void> _open(String href) async {
    final Uri? uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!HtmlRenderer._allowedSchemes.contains(uri.scheme.toLowerCase())) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing installed that can handle it.
    }
  }
}

/// One level of inline style.
class _Frame {
  const _Frame({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.href,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final String? href;

  _Frame copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? code,
    String? href,
  }) =>
      _Frame(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        code: code ?? this.code,
        href: href ?? this.href,
      );

  TextStyle styleFor(TextStyle base, Color linkColor, TextStyle codeStyle) {
    if (code) return codeStyle;
    TextStyle style = base;
    if (bold) style = style.copyWith(fontWeight: FontWeight.w600);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (underline || href != null) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    if (href != null) style = style.copyWith(color: linkColor);
    return style;
  }
}
