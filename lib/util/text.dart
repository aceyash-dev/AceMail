import 'dart:convert';

/// Collapses runs of blank lines down to a single one.
///
/// Plain-text mail that was laid out in columns arrives with whole screens of
/// whitespace between the few lines that carry meaning, which pushes the body
/// out of view. Two newlines is a paragraph break; more than that is layout.
String collapseBlankLines(String text) =>
    text.replaceAll(RegExp(r'\n[ \t]*\n(?:[ \t]*\n)+'), '\n\n').trim();

/// Whether a message body promises an attachment.
///
/// Deliberately narrow: the words people actually write when they mean to attach
/// something. A check that also fired on the word "attachment" in a discussion
/// about attachments would be a warning people learn to dismiss, and a dismissed
/// warning is worse than none — it costs a tap every time and catches nothing.
final RegExp _attachmentWords = RegExp(
  r'\b(attach(ed|es|ing)?|attachment(s)?|enclosed|enclosure|'
  r'please find|see attached|the attached)\b',
  caseSensitive: false,
);

bool mentionsAttachment(String body) => _attachmentWords.hasMatch(body);

/// The first [maxCodeUnits] of [text], never cutting a character in half.
///
/// A Dart string is UTF-16, so an emoji or any character outside the basic
/// plane is two code units. `substring` on a boundary between them yields a
/// lone surrogate, which renders as a replacement character — which is how a
/// long message ends up with a broken glyph at the end of the preview.
String truncateSafely(String text, int maxCodeUnits) {
  if (maxCodeUnits <= 0) return '';
  if (text.length <= maxCodeUnits) return text;
  int end = maxCodeUnits;
  final int last = text.codeUnitAt(end - 1);
  // A high surrogate with nothing after it: drop it rather than keep half.
  if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return text.substring(0, end);
}


/// Truncates [text] to at most [maxBytes] UTF-8 bytes without splitting a
/// multibyte code point. Unlike [truncateSafely], the limit is measured in
/// encoded bytes rather than Dart UTF-16 code units.
String truncateUtf8BytesSafely(String text, int maxBytes) {
  if (maxBytes <= 0) return '';
  final List<int> bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return text;

  int end = maxBytes;
  // If the first excluded byte is a continuation, the preceding code point
  // crosses the byte boundary. Drop that whole code point.
  while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
    end--;
  }
  if (end < maxBytes) return utf8.decode(bytes.sublist(0, end));
  return utf8.decode(bytes.sublist(0, maxBytes));
}
