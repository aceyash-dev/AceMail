import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../theme/astryx_tokens.dart';
import '../theme/astryx_theme.dart';
import '../util/links.dart';

/// One block of Markdown.
sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdList extends MdBlock {
  const MdList({required this.items, required this.ordered});
  final List<String> items;
  final bool ordered;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdCode extends MdBlock {
  const MdCode(this.code, {this.language});
  final String code;
  final String? language;
}

class MdRule extends MdBlock {
  const MdRule();
}

/// Splits Markdown into blocks.
///
/// Written here rather than pulled in, for the same reason the HTML renderer is
/// a package and this is not: the HTML renderer had to survive mail, which is a
/// museum of it, while this only has to survive an assistant that was asked to
/// be brief. What it has to handle is a short list of things — a heading, a
/// bullet, a numbered step, a code span, a bold word, a link — and everything
/// else is a paragraph.
///
/// Pure, so the rules are tested without a widget tree.
List<MdBlock> parseMarkdown(String source) {
  final List<MdBlock> blocks = <MdBlock>[];
  final List<String> lines = source.replaceAll('\r\n', '\n').split('\n');

  final StringBuffer paragraph = StringBuffer();
  final List<String> listItems = <String>[];
  bool listOrdered = false;

  void flushParagraph() {
    final String text = paragraph.toString().trim();
    if (text.isNotEmpty) blocks.add(MdParagraph(text));
    paragraph.clear();
  }

  void flushList() {
    if (listItems.isNotEmpty) {
      blocks.add(MdList(items: List<String>.of(listItems), ordered: listOrdered));
      listItems.clear();
    }
  }

  int i = 0;
  while (i < lines.length) {
    final String line = lines[i];
    final String trimmed = line.trim();

    // A fenced block runs to its closing fence, or to the end if there is none
    // — an assistant that forgets to close one should not lose the rest.
    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushList();
      final String language = trimmed.substring(3).trim();
      final List<String> code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.add(lines[i]);
        i++;
      }
      i++;
      blocks.add(MdCode(code.join('\n'),
          language: language.isEmpty ? null : language));
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      flushList();
      i++;
      continue;
    }

    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      flushParagraph();
      flushList();
      blocks.add(const MdRule());
      i++;
      continue;
    }

    final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      flushList();
      blocks.add(MdHeading(heading.group(1)!.length, heading.group(2)!.trim()));
      i++;
      continue;
    }

    final RegExpMatch? quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (quote != null) {
      flushParagraph();
      flushList();
      final List<String> quoted = <String>[quote.group(1)!];
      i++;
      while (i < lines.length &&
          RegExp(r'^>\s?').hasMatch(lines[i].trim())) {
        quoted.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      blocks.add(MdQuote(quoted.join(' ').trim()));
      continue;
    }

    final RegExpMatch? bullet =
        RegExp(r'^([-*+]|\d+[.)])\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      final bool ordered = RegExp(r'^\d').hasMatch(bullet.group(1)!);
      // A list that changes kind starts a new list, so a numbered list under a
      // bulleted one does not silently become part of it.
      if (listItems.isNotEmpty && ordered != listOrdered) flushList();
      listOrdered = ordered;
      listItems.add(bullet.group(2)!.trim());
      i++;
      continue;
    }

    flushList();
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
    i++;
  }

  flushParagraph();
  flushList();
  return blocks;
}

/// Renders Markdown in the app's own type.
///
/// Links are tappable and carry the accent; code is monospaced on the raised
/// surface. Nothing here is a Markdown *viewer* — there are no tables, no
/// footnotes, no raw HTML — because what it renders is a chat reply.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.source, this.onLink});

  final String source;

  /// Called when a link is tapped. Left null, links are drawn but inert.
  final void Function(String url)? onLink;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final List<MdBlock> blocks = parseMarkdown(source);
    final List<Widget> children = <Widget>[];

    for (final MdBlock block in blocks) {
      if (children.isNotEmpty) children.add(const SizedBox(height: AstryxSpace.s2));

      switch (block) {
        case MdHeading(:final int level, :final String text):
          children.add(
            Text.rich(
              TextSpan(children: _inline(context, text)),
              style: switch (level) {
                1 => AstryxText.heading2(c.textPrimary),
                2 => AstryxText.heading3(c.textPrimary),
                _ => AstryxText.label(c.textPrimary),
              },
            ),
          );
        case MdParagraph(:final String text):
          children.add(
            Text.rich(
              TextSpan(children: _inline(context, text)),
              style: AstryxText.body(c.textPrimary).copyWith(height: 1.45),
            ),
          );
        case MdList(:final List<String> items, :final bool ordered):
          for (int n = 0; n < items.length; n++) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: AstryxSpace.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: Text(
                        ordered ? '${n + 1}.' : '·',
                        style: AstryxText.body(c.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: _inline(context, items[n])),
                        style:
                            AstryxText.body(c.textPrimary).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        case MdQuote(:final String text):
          children.add(
            Container(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s3,
                AstryxSpace.s1,
                AstryxSpace.s1,
                AstryxSpace.s1,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.accent, width: 3),
                ),
              ),
              child: Text.rich(
                TextSpan(children: _inline(context, text)),
                style: AstryxText.body(c.textSecondary),
              ),
            ),
          );
        case MdCode(:final String code):
          children.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AstryxSpace.s3),
              decoration: BoxDecoration(
                color: c.backgroundMuted,
                borderRadius: BorderRadius.circular(AstryxRadius.inner),
              ),
              child: SelectableText(
                code,
                style: AstryxText.supporting(c.textPrimary).copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          );
        case MdRule():
          children.add(Divider(color: c.border, height: AstryxSpace.s4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// The inline rules: code, bold, italic, links.
  List<InlineSpan> _inline(BuildContext context, String text) {
    final AstryxColors c = context.astryx;
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(
      r'(`[^`]+`)'          // code
      r'|(\*\*[^*]+\*\*)'   // bold
      r'|(__[^_]+__)'       // bold, the other way
      r'|(\*[^*\n]+\*)'     // italic
      r'|(\[[^\]]+\]\([^)]+\))', // link
    );

    int index = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final String token = match.group(0)!;

      if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: AstryxText.body(c.textPrimary).copyWith(
              fontFamily: 'monospace',
              backgroundColor: c.backgroundMuted,
            ),
          ),
        );
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (token.startsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        final RegExpMatch link =
            RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token)!;
        final String label = link.group(1)!;
        final String url = link.group(2)!;
        spans.add(
          TextSpan(
            text: label,
            style: AstryxText.body(c.textAccent).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: c.textAccent.withValues(alpha: 0.4),
            ),
            recognizer: onLink == null
                ? null
                : (TapGestureRecognizer()..onTap = () => onLink!(url)),
          ),
        );
      }
      index = match.end;
    }

    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return spans;
  }
}

/// Opens a link the way the rest of the app does, or refuses politely.
///
/// The same two checks the message renderer makes — a scheme this app is
/// willing to hand over, and the user's own confirmation when they have asked
/// for one — because a link in an assistant's reply is no more trustworthy than
/// a link in a message.
Future<void> openMarkdownLink(
  BuildContext context,
  String url, {
  Future<bool> Function(Uri uri)? confirmLink,
}) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !mayOpenLink(uri)) return;
  if (confirmLink != null && !await confirmLink(uri)) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Nothing installed that can handle it. The reply is still on screen, so
    // the URL is not lost.
  }
}
