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
