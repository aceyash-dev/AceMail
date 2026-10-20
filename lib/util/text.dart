/// Collapses runs of blank lines down to a single one.
///
/// Plain-text mail that was laid out in columns arrives with whole screens of
/// whitespace between the few lines that carry meaning, which pushes the body
/// out of view. Two newlines is a paragraph break; more than that is layout.
String collapseBlankLines(String text) =>
    text.replaceAll(RegExp(r'\n[ \t]*\n(?:[ \t]*\n)+'), '\n\n').trim();
