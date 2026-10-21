import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../data/limits.dart';
import '../widgets/html_image.dart';

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
    this.loadRemoteImages = false,
    this.confirmLink,
  });

  final TextStyle baseStyle;
  final Color linkColor;
  final TextStyle codeStyle;

  /// Off by default: fetching a remote image tells the sender's server that the
  /// message was opened.
  final bool loadRemoteImages;

  /// Asked before a link leaves the app. Returning false means the reader said
  /// no, and nothing happens.
  ///
  /// A link in a mail is text the sender chose, and the text need not be what
  /// the link does — `yahoo.com` can point anywhere. Showing the address before
  /// the browser opens is the difference between a decision and a reflex.
  final Future<bool> Function(Uri uri)? confirmLink;

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
      loadRemoteImages: loadRemoteImages,
      confirmLink: confirmLink,
    );

    try {
      final dom.Document document = html_parser.parse(source);

      // Read every stylesheet in the document first. `<style>` almost always
      // sits in the head, which the walk below never reaches — which is why a
      // rule in a style block was being ignored while the same rule written in
      // a style attribute worked.
      for (final dom.Element style in document.querySelectorAll('style')) {
        builder.stylesheet.add(style.text);
      }

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
    required this.loadRemoteImages,
    required this.confirmLink,
  });

  final TextStyle baseStyle;
  final Color linkColor;
  final TextStyle codeStyle;
  final bool loadRemoteImages;
  final Future<bool> Function(Uri uri)? confirmLink;

  final _Stylesheet _stylesheet = _Stylesheet();

  /// The message's stylesheet, filled from the document before the walk.
  _Stylesheet get stylesheet => _stylesheet;

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
    // `style` is deliberately absent: its rules are read into the stylesheet
    // rather than thrown away. `script` stays: no JavaScript, ever.
    'script', 'head', 'title', 'noscript', 'template', 'svg', 'iframe',
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
        writeImage(node);
        return;
      case 'style':
        // Already read from the document; a second one in the body counts too.
        _stylesheet.add(node.text);
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
    // The stylesheet first, then the element's own attribute over it — the same
    // order a browser resolves them in.
    final _CssStyle css =
        _stylesheet.forElement(node).over(_Stylesheet.declarationsFor(style));

    // Hidden before anything else: nothing it contains is shown. Mail hides its
    // preheader this way, and showing it puts a stray line of preview text at
    // the top of every message.
    if (css.hidden == true) return;

    final bool bold = css.bold ??
        (tag == 'b' ||
            tag == 'strong' ||
            _isHeading(tag) ||
            _boldStyle.hasMatch(style));
    final bool italic = css.italic ??
        (tag == 'i' || tag == 'em' || _italicStyle.hasMatch(style));
    final bool underline = css.underline ??
        (tag == 'u' || tag == 'ins' || _underlineStyle.hasMatch(style));
    final bool code = tag == 'code' || tag == 'pre' || tag == 'kbd' || tag == 'tt';
    final String? href = tag == 'a' ? _safeHref(node.attributes['href']) : null;

    _push(
      _frame.copyWith(
        bold: _frame.bold || bold,
        italic: _frame.italic || italic,
        underline: _frame.underline || underline,
        code: _frame.code || code,
        href: href ?? _frame.href,
        color: css.color,
        sizeScale: css.sizeScale,
        upper: css.upper ?? false,
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

  /// A 300-character tracking URL has no space to wrap at, so it runs off the
  /// side of the reader. A zero-width space every so often gives the line
  /// breaker somewhere to go without adding a visible character.
  static final RegExp _longToken = RegExp(r'\S{24,}');

  static String _breakLongTokens(String text) => text.replaceAllMapped(
        _longToken,
        (Match match) {
          final String token = match.group(0)!;
          final StringBuffer out = StringBuffer();
          for (int i = 0; i < token.length; i += 18) {
            if (i > 0) out.write('\u200b');
            out.write(token.substring(i, math.min(i + 18, token.length)));
          }
          return out.toString();
        },
      );

  /// Whether an `<img>` is a 1×1 beacon.
  static bool _isTrackingPixel(dom.Element node) {
    int? dimension(String name) {
      final String? raw = node.attributes[name];
      if (raw == null) return null;
      return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    final int? width = dimension('width');
    final int? height = dimension('height');
    // Only when both are given and both are tiny: a single `height="1"` on an
    // otherwise normal image is a layout trick, not a beacon.
    return width != null && height != null && width <= 2 && height <= 2;
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

  /// An image becomes a placeholder, the size it says it is, rather than a
  /// bracket of alt text dropped into the middle of a sentence — which is what
  /// "the layout broke" looked like, with a stray `[Yahoo]` where a logo was.
  void writeImage(dom.Element node) {
    // A tracking pixel is an image nobody is meant to see. Emitting a
    // placeholder for one puts an "Image" chip in the middle of a message that
    // has no images in it at all — which is how most mail looks.
    if (_isTrackingPixel(node)) return;

    _flush();
    _breaks = 0;
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: HtmlImage(
          source: node.attributes['src']?.trim(),
          alt: (node.attributes['alt'] ?? '').trim(),
          loadRemote: loadRemoteImages,
        ),
      ),
    );
  }

  void write(String raw) {
    if (raw.isEmpty) return;

    // Collapse runs of whitespace the way HTML does, except inside <pre>.
    String text = _frame.code
        ? raw
        : _breakLongTokens(raw.replaceAll(RegExp(r'[ \t\r\n\u00a0]+'), ' '));
    if (text.isEmpty) return;
    if (_frame.upper) text = text.toUpperCase();

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
      recognizer = TapGestureRecognizer()..onTap = () => _open(href, confirmLink);
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

  static Future<void> _open(
    String href,
    Future<bool> Function(Uri uri)? confirm,
  ) async {
    final Uri? uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!HtmlRenderer._allowedSchemes.contains(uri.scheme.toLowerCase())) return;

    // Asked before leaving the app, when the reader asked to be asked.
    if (confirm != null) {
      final bool go = await confirm(uri);
      if (!go) return;
    }

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
    this.color,
    this.sizeScale = 1,
    this.upper = false,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final String? href;

  /// From CSS, when the message states one.
  final Color? color;

  /// A multiplier on the base size, from a CSS `font-size`.
  final double sizeScale;

  /// From a CSS `text-transform`.
  final bool upper;

  _Frame copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? code,
    String? href,
    Color? color,
    double? sizeScale,
    bool? upper,
  }) =>
      _Frame(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        code: code ?? this.code,
        href: href ?? this.href,
        color: color ?? this.color,
        sizeScale: sizeScale ?? this.sizeScale,
        upper: upper ?? this.upper,
      );

  TextStyle styleFor(TextStyle base, Color linkColor, TextStyle codeStyle) {
    if (code) return codeStyle;
    TextStyle style = base;
    if (sizeScale != 1) {
      style = style.copyWith(fontSize: (base.fontSize ?? 14) * sizeScale);
    }
    if (color != null) style = style.copyWith(color: color);
    if (bold) style = style.copyWith(fontWeight: FontWeight.w600);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (underline || href != null) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    // A link keeps the link colour unless the message coloured it itself.
    if (href != null && color == null) style = style.copyWith(color: linkColor);
    return style;
  }
}

// ---------------------------------------------------------------------------
// A small CSS engine.
//
// Mail is styled with CSS, and ignoring it means ignoring how the sender laid
// the message out — which is most of why a rendered message does not look like
// the one that was sent. This reads `<style>` blocks and the `style` attribute
// and applies the handful of properties that survive being turned into styled
// text: weight, italic, underline, colour, size, and case.
//
// Deliberately not a browser. No layout, no selectors beyond a tag, a class or
// an id, no cascade beyond "later rules win", and — as everywhere else in this
// renderer — no JavaScript.
// ---------------------------------------------------------------------------

/// The properties a rule can set, as the renderer understands them.
class _CssStyle {
  const _CssStyle({
    this.bold,
    this.italic,
    this.underline,
    this.color,
    this.sizeScale,
    this.upper,
    this.hidden,
  });

  final bool? bold;
  final bool? italic;
  final bool? underline;
  final Color? color;
  final double? sizeScale;
  final bool? upper;

  /// `display: none`. Mail hides its preheader this way, and showing it puts a
  /// stray line of preview text at the top of every message.
  final bool? hidden;

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      color == null &&
      sizeScale == null &&
      upper == null &&
      hidden == null;

  /// Later declarations win, so the second one is applied over the first.
  _CssStyle over(_CssStyle other) => _CssStyle(
        bold: other.bold ?? bold,
        italic: other.italic ?? italic,
        underline: other.underline ?? underline,
        color: other.color ?? color,
        sizeScale: other.sizeScale ?? sizeScale,
        upper: other.upper ?? upper,
        hidden: other.hidden ?? hidden,
      );
}

/// A tag, a class or an id. Enough for the selectors mail actually uses.
class _CssSelector {
  const _CssSelector({this.tag, this.clazz, this.id});

  final String? tag;
  final String? clazz;
  final String? id;

  bool matches(dom.Element node) {
    if (id != null && node.id != id) return false;
    if (clazz != null && !node.classes.contains(clazz)) return false;
    if (tag != null && node.localName?.toLowerCase() != tag) return false;
    return true;
  }
}

class _CssRule {
  const _CssRule(this.selectors, this.style);

  final List<_CssSelector> selectors;
  final _CssStyle style;
}

/// The message's stylesheet, in source order.
class _Stylesheet {
  _Stylesheet();

  final List<_CssRule> _rules = <_CssRule>[];

  static final RegExp _comments = RegExp(r'/\*.*?\*/', dotAll: true);
  static final RegExp _blocks = RegExp(r'([^{}]+)\{([^{}]*)\}');

  /// A few names, so `color: red` is not silently dropped.
  static const Map<String, Color> _named = <String, Color>{
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFD32F2F),
    'green': Color(0xFF2E7D32),
    'blue': Color(0xFF1565C0),
    'gray': Color(0xFF616161),
    'grey': Color(0xFF616161),
    'silver': Color(0xFF9E9E9E),
    'orange': Color(0xFFEF6C00),
    'purple': Color(0xFF6A1B9A),
    'maroon': Color(0xFF7B1FA2),
    'navy': Color(0xFF0D47A1),
    'teal': Color(0xFF00695C),
    'olive': Color(0xFF827717),
    'yellow': Color(0xFFF9A825),
  };

  void add(String css) {
    if (css.trim().isEmpty) return;
    final String clean = css.replaceAll(_comments, ' ');

    for (final RegExpMatch block in _blocks.allMatches(clean)) {
      final List<_CssSelector> selectors = <_CssSelector>[];
      for (final String part in block.group(1)!.split(',')) {
        final _CssSelector? selector = _selectorFor(part.trim());
        if (selector != null) selectors.add(selector);
      }
      final _CssStyle style = _styleFor(block.group(2)!);
      if (selectors.isNotEmpty && !style.isEmpty) {
        _rules.add(_CssRule(selectors, style));
      }
    }
  }

  /// The style that applies to [node], with later rules winning.
  _CssStyle forElement(dom.Element node) {
    _CssStyle result = const _CssStyle();
    for (final _CssRule rule in _rules) {
      if (rule.selectors.any((_CssSelector s) => s.matches(node))) {
        result = result.over(rule.style);
      }
    }
    return result;
  }

  /// Takes the last part of a descendant selector — `div.footer a` matches an
  /// `a` — because that is the part that decides which element is styled.
  static _CssSelector? _selectorFor(String raw) {
    if (raw.isEmpty) return null;
    final String last = raw.split(RegExp(r'\s+')).last;

    final RegExpMatch? id = RegExp(r'#([\w-]+)').firstMatch(last);
    final RegExpMatch? cls = RegExp(r'\.([\w-]+)').firstMatch(last);
    final RegExpMatch? tag = RegExp(r'^([a-zA-Z][\w-]*)').firstMatch(last);
    // A pseudo-class or attribute selector is not understood, so it is not
    // applied rather than applied wrongly.
    if (last.contains('[') || last.contains(':')) return null;

    return _CssSelector(
      tag: tag?.group(1)?.toLowerCase(),
      clazz: cls?.group(1),
      id: id?.group(1),
    );
  }

  /// The `style` attribute, parsed by the same code as a rule body.
  static _CssStyle declarationsFor(String declarations) =>
      declarations.trim().isEmpty
          ? const _CssStyle()
          : _styleFor(declarations);

  static _CssStyle _styleFor(String declarations) {
    bool? bold;
    bool? italic;
    bool? underline;
    Color? color;
    double? sizeScale;
    bool? upper;
    bool? hidden;

    for (final String declaration in declarations.split(';')) {
      final int colon = declaration.indexOf(':');
      if (colon < 0) continue;
      final String name = declaration.substring(0, colon).trim().toLowerCase();
      final String value = declaration.substring(colon + 1).trim().toLowerCase();
      if (value.isEmpty) continue;

      switch (name) {
        case 'font-weight':
          final int? weight = int.tryParse(value);
          if (value.contains('bold') || (weight != null && weight >= 600)) {
            bold = true;
          } else if (value.contains('normal') || (weight != null && weight < 600)) {
            bold = false;
          }
        case 'font-style':
          italic = value.contains('italic') || value.contains('oblique');
        case 'text-decoration':
        case 'text-decoration-line':
          if (value.contains('none')) {
            underline = false;
          } else if (value.contains('underline')) {
            underline = true;
          }
        case 'color':
          color = _colorFor(value);
        case 'font-size':
          sizeScale = _scaleFor(value);
        case 'text-transform':
          upper = value.contains('uppercase');
        case 'display':
          hidden = value.contains('none');
        case 'visibility':
          if (value.contains('hidden')) hidden = true;
      }
    }

    return _CssStyle(
      bold: bold,
      italic: italic,
      underline: underline,
      color: color,
      sizeScale: sizeScale,
      upper: upper,
      hidden: hidden,
    );
  }

  static Color? _colorFor(String value) {
    if (value.startsWith('#')) {
      String hex = value.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((String c) => '$c$c').join();
      }
      if (hex.length >= 6) {
        final int? rgb = int.tryParse(hex.substring(0, 6), radix: 16);
        if (rgb != null) return Color(0xFF000000 | rgb);
      }
      return null;
    }
    if (value.startsWith('rgb')) {
      final List<String> parts =
          RegExp(r'\d+').allMatches(value).map((RegExpMatch m) => m.group(0)!).toList();
      if (parts.length >= 3) {
        return Color.fromARGB(
          255,
          int.parse(parts[0]).clamp(0, 255),
          int.parse(parts[1]).clamp(0, 255),
          int.parse(parts[2]).clamp(0, 255),
        );
      }
      return null;
    }
    // `inherit`, `initial`, `currentcolor` and anything unrecognised: no
    // opinion, rather than a wrong one.
    return _named[value];
  }

  /// A font size as a multiplier on the base.
  ///
  /// Capped at 2×: a sender who writes `font-size: 400px` should not be able to
  /// take over the reader.
  static double? _scaleFor(String value) {
    final RegExpMatch? number = RegExp(r'([\d.]+)').firstMatch(value);
    if (number == null) return null;
    final double? amount = double.tryParse(number.group(1)!);
    if (amount == null || amount <= 0) return null;

    double scale;
    if (value.contains('%')) {
      scale = amount / 100;
    } else if (value.contains('em') || value.contains('rem')) {
      scale = amount;
    } else if (value.contains('px')) {
      scale = amount / 16; // against a nominal 16px base
    } else {
      return null;
    }
    return scale.clamp(0.5, 2.0);
  }
}
