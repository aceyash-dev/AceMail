import '../models/message_summary.dart';

/// A search, as somebody typed it.
///
/// Plain words still work exactly as they did — they go to the server as "from
/// or subject", which is what a person means by typing a word into a search
/// box. On top of that there are operators, the ones people already know from
/// every other mail client:
///
/// ```
/// invoice                 from or subject, as before
/// from:alice              the sender
/// to:bob                  a recipient
/// subject:receipt         the subject line
/// has:attachment          something is attached
/// is:unread  is:flagged   the flags
/// newer_than:7d           within the last seven days
/// older_than:30d          older than thirty days
/// after:2026-01-01        on or after a date
/// before:2026-06-01       before a date
/// ```
///
/// Parsing is pure and separate from the server, because the two halves of a
/// search are different problems: what the person meant, and how to ask this
/// particular IMAP server for it.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.from,
    this.to,
    this.subject,
    this.unread = false,
    this.flagged = false,
    this.hasAttachment = false,
    this.since,
    this.before,
  });

  /// The words that were not part of an operator.
  final String text;

  final String? from;
  final String? to;
  final String? subject;

  final bool unread;
  final bool flagged;

  /// Whether something is attached.
  ///
  /// IMAP has no key for this. There is no "has attachment" in the search
  /// grammar, and the header tricks people use instead depend on how a
  /// particular server assembles multipart messages. So it is not asked of the
  /// server at all: the results are narrowed here, against the structure the
  /// fetch already returned. The cost is that it filters the page the server
  /// sent rather than the whole mailbox, which is the honest version of what a
  /// client can do without downloading everything.
  final bool hasAttachment;

  /// On or after this date.
  final DateTime? since;

  /// Before this date.
  final DateTime? before;

  /// The operators a search can use, for the hint under the field.
  static const List<String> operatorHints = <String>[
    'from:',
    'subject:',
    'has:attachment',
    'is:unread',
    'newer_than:',
    'before:',
  ];

  /// Whether any operator was used at all.
  bool get hasOperators =>
      from != null ||
      to != null ||
      subject != null ||
      unread ||
      flagged ||
      hasAttachment ||
      since != null ||
      before != null;

  /// Whether the server's answer still needs narrowing here.
  bool get narrowsLocally => hasAttachment;

  /// Reads [raw]. Never throws: anything unrecognised is a word to search for,
  /// because a search box that rejects input is worse than one that treats
  /// `wibble:` as text.
  static SearchQuery parse(String raw) {
    String? from;
    String? to;
    String? subject;
    bool unread = false;
    bool flagged = false;
    bool hasAttachment = false;
    DateTime? since;
    DateTime? before;
    final List<String> words = <String>[];

    for (final String token in raw.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final int colon = token.indexOf(':');
      if (colon <= 0 || colon == token.length - 1) {
        words.add(token);
        continue;
      }

      final String key = token.substring(0, colon).toLowerCase();
      final String value = token.substring(colon + 1);

      switch (key) {
        case 'from':
        case 'sender':
          from = value;
        case 'to':
        case 'recipient':
          to = value;
        case 'subject':
          subject = value;
        case 'has':
          // Only the one thing worth having, and only when it is that thing.
          if (value.toLowerCase().startsWith('attach')) {
            hasAttachment = true;
          } else {
            words.add(token);
          }
        case 'is':
        case 'in':
          switch (value.toLowerCase()) {
            case 'unread':
              unread = true;
            case 'read':
              // The opposite of the only flag state worth naming. There is no
              // SEEN key in the grammar, so it is not expressible — and quietly
              // searching for something else would be worse than not searching.
              break;
            case 'flagged':
            case 'starred':
              flagged = true;
            default:
              words.add(token);
          }
        case 'newer_than':
        case 'older_than':
          final Duration? window = _duration(value);
          if (window == null) {
            words.add(token);
            break;
          }
          final DateTime at = DateTime.now().subtract(window);
          if (key == 'newer_than') {
            since = at;
          } else {
            before = at;
          }
        case 'after':
        case 'since':
          final DateTime? at = _date(value);
          if (at == null) {
            words.add(token);
          } else {
            since = at;
          }
        case 'before':
          final DateTime? at = _date(value);
          if (at == null) {
            words.add(token);
          } else {
            before = at;
          }
        default:
          words.add(token);
      }
    }

    return SearchQuery(
      text: words.join(' ').trim(),
      from: from,
      to: to,
      subject: subject,
      unread: unread,
      flagged: flagged,
      hasAttachment: hasAttachment,
      since: since,
      before: before,
    );
  }

  /// `7d`, `2w`, `3m`, `1y` — the shorthand every mail client accepts.
  static Duration? _duration(String value) {
    final RegExpMatch? match =
        RegExp(r'^(\d+)\s*([dwmy])?$', caseSensitive: false).firstMatch(value);
    if (match == null) return null;
    final int? count = int.tryParse(match.group(1)!);
    if (count == null || count <= 0) return null;
    return switch ((match.group(2) ?? 'd').toLowerCase()) {
      'w' => Duration(days: count * 7),
      'm' => Duration(days: count * 30),
      'y' => Duration(days: count * 365),
      _ => Duration(days: count),
    };
  }

  /// `2026-01-01`, or `01-01-2026` for anyone who reads dates the other way.
  ///
  /// Only the unambiguous form is guessed at; anything else is treated as a
  /// word, because a date searched for wrongly returns nothing and looks like
  /// "no mail matched" rather than "that was not a date".
  static DateTime? _date(String value) {
    final RegExpMatch? iso =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    return null;
  }

  /// Whether [message] survives the parts the server cannot be asked about.
  bool matches(MessageSummary message) {
    if (hasAttachment && !message.hasAttachments) return false;
    return true;
  }

  /// The IMAP search criteria, or null when there is nothing to ask a server.
  ///
  /// The keys are ANDed by being written one after another — that is what the
  /// grammar means by a sequence — so the order here is the order of the
  /// sentence. `OR` is left for the free words, which go through the library's
  /// own builder because it knows how to quote them.
  String? criteria() {
    final List<String> keys = <String>[];

    if (unread) keys.add('UNSEEN');
    if (flagged) keys.add('FLAGGED');
    if (since != null) keys.add('SINCE ${imapDate(since!)}');
    if (before != null) keys.add('BEFORE ${imapDate(before!)}');

    final String? fromTerm = _term(from);
    if (fromTerm != null) keys.add('FROM "$fromTerm"');
    final String? toTerm = _term(to);
    if (toTerm != null) keys.add('TO "$toTerm"');
    final String? subjectTerm = _term(subject);
    if (subjectTerm != null) keys.add('SUBJECT "$subjectTerm"');

    final String words = _term(text) ?? '';
    if (words.isNotEmpty) {
      // `fromOrSubject`, which is what typing a word into a search box has
      // always meant here.
      keys.add(
        'OR FROM "$words" SUBJECT "$words"',
      );
    }

    if (keys.isEmpty) return null;
    return keys.join(' ');
  }

  /// A term safe to put inside the double quotes of an IMAP criterion.
  ///
  /// A backslash or a control character inside the quotes could end the term or
  /// break the command, so they are dropped rather than escaped: the grammar
  /// has no escape for them, which is the same reason the plain search has
  /// always done this.
  static String? _term(String? value) {
    if (value == null) return null;
    final String safe = value.replaceAll(RegExp(r'[\\\x00-\x1f\x7f"]'), ' ').trim();
    return safe.isEmpty ? null : safe;
  }

  /// `1-Jan-2026`, which is the one date format IMAP accepts and is not
  /// locale-dependent — unlike anything that goes through `DateFormat`.
  static String imapDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }
}
