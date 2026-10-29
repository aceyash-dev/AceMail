import 'message_summary.dart';

/// How the message list is ordered.
///
/// Applied to the page that is loaded, not asked of the server: the folder is
/// already fetched newest-first, and re-ordering a page of forty in memory is
/// instant, where a server-side SORT is an extension many providers do not
/// implement.
enum MessageSort {
  newest('Newest'),
  oldest('Oldest'),
  sender('Sender'),
  subject('Subject'),
  unread('Unread first'),
  attachments('Attachments first');

  const MessageSort(this.label);

  final String label;

  /// This order, with [secondary] deciding the ties.
  ///
  /// One order cannot say "by sender, and within each sender newest first" —
  /// and that is the order most people actually want once a folder is longer
  /// than a screen. The second key only ever breaks ties, so adding one cannot
  /// reorder what the first key decided.
  List<MessageSummary> apply(
    List<MessageSummary> messages, {
    MessageSort? secondary,
  }) =>
      sortBy(messages, primary: this, secondary: secondary);

  /// Two keys, in order. [secondary] is optional and only breaks ties.
  static List<MessageSummary> sortBy(
    List<MessageSummary> messages, {
    required MessageSort primary,
    MessageSort? secondary,
  }) {
    final MessageSort? tie = secondary == primary ? null : secondary;
    return List<MessageSummary>.of(messages)
      ..sort((MessageSummary a, MessageSummary b) {
        final int first = primary.compare(a, b);
        if (first != 0 || tie == null) return first;
        return tie.compare(a, b);
      });
  }

  /// How this order places [a] against [b]: negative for before, zero for the
  /// same place, positive for after.
  ///
  /// A comparator rather than a sort of its own, so two orders can be composed:
  /// the old shape sorted a list and could only answer "where does everything
  /// go", which is why a second key had nowhere to live.
  int compare(MessageSummary a, MessageSummary b) {
    switch (this) {
      case MessageSort.newest:
        return _byDate(a, b);
      case MessageSort.oldest:
        return _byDate(b, a);
      case MessageSort.sender:
        return _key(a.fromName, a.fromEmail)
            .compareTo(_key(b.fromName, b.fromEmail));
      case MessageSort.subject:
        return _key(a.subject, '').compareTo(_key(b.subject, ''));
      case MessageSort.unread:
        // Unread first, and newest within each group.
        if (a.isSeen != b.isSeen) return a.isSeen ? 1 : -1;
        return _byDate(a, b);
      case MessageSort.attachments:
        // The ones with something on them first, newest within each group. What
        // it is for: finding the thing somebody sent you when the subject has
        // been forgotten and the date has not.
        if (a.hasAttachments != b.hasAttachments) {
          return a.hasAttachments ? -1 : 1;
        }
        return _byDate(a, b);
    }
  }

  /// Newest first. A message with no date sorts last rather than crashing the
  /// list: a summary can arrive without one.
  static int _byDate(MessageSummary a, MessageSummary b) {
    final DateTime? da = a.date;
    final DateTime? db = b.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  /// Case- and accent-insensitive enough for a name or a subject, and it falls
  /// back to the other field when one is empty.
  static String _key(String primary, String fallback) {
    final String value = primary.trim().isEmpty ? fallback : primary;
    return value.trim().toLowerCase();
  }
}

/// A quick filter over the loaded page.
enum MessageFilter {
  all('All'),
  unread('Unread'),
  flagged('Flagged'),
  codes('Codes'),
  today('Today'),
  week('This week'),
  month('This month');

  const MessageFilter(this.label);

  final String label;

  /// The oldest a message may be to match, or null for "any time".
  ///
  /// A period is a filter rather than a sort because that is what people mean
  /// by it: "today" is not an order to put things in, it is a smaller pile.
  /// Rolling windows, not calendar ones — "this week" that empties on Sunday
  /// night is not what somebody looking for last Tuesday's receipt wants.
  Duration? get within => switch (this) {
        MessageFilter.today => const Duration(days: 1),
        MessageFilter.week => const Duration(days: 7),
        MessageFilter.month => const Duration(days: 30),
        _ => null,
      };

  /// Whether [message] passes.
  ///
  /// [now] is passed in rather than read here: a period filter asks the clock a
  /// question, and asking it once per message is a syscall per row for an answer
  /// that cannot change during the pass.
  bool matches(MessageSummary message, {required DateTime now}) =>
      switch (this) {
        MessageFilter.all => true,
        MessageFilter.unread => !message.isSeen,
        MessageFilter.flagged => message.isFlagged,
        MessageFilter.codes => message.otp != null,
        _ => _inPeriod(message, now),
      };

  bool _inPeriod(MessageSummary message, DateTime now) {
    final Duration? window = within;
    final DateTime? date = message.date;
    // A message with no date is not in any period. Sorting it to the end of a
    // window would be inventing a date it does not have.
    if (window == null || date == null) return false;
    return now.difference(date) <= window;
  }
}
