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

  List<MessageSummary> apply(List<MessageSummary> messages) {
    final List<MessageSummary> sorted =
        List<MessageSummary>.of(messages);

    int byDate(MessageSummary a, MessageSummary b) {
      final DateTime? da = a.date;
      final DateTime? db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // newest first
    }

    switch (this) {
      case MessageSort.newest:
        sorted.sort(byDate);
      case MessageSort.oldest:
        sorted.sort((MessageSummary a, MessageSummary b) => byDate(b, a));
      case MessageSort.sender:
        sorted.sort((MessageSummary a, MessageSummary b) => _key(a.fromName,
                a.fromEmail)
            .compareTo(_key(b.fromName, b.fromEmail)));
      case MessageSort.subject:
        sorted.sort((MessageSummary a, MessageSummary b) =>
            _key(a.subject, '').compareTo(_key(b.subject, '')));
      case MessageSort.unread:
        // Unread first, and newest within each group.
        sorted.sort((MessageSummary a, MessageSummary b) {
          if (a.isSeen != b.isSeen) return a.isSeen ? 1 : -1;
          return byDate(a, b);
        });
      case MessageSort.attachments:
        // The ones with something on them first, newest within each group. What
        // it is for: finding the thing somebody sent you, when the subject has
        // been forgotten and the date has not.
        sorted.sort((MessageSummary a, MessageSummary b) {
          if (a.hasAttachments != b.hasAttachments) {
            return a.hasAttachments ? -1 : 1;
          }
          return byDate(a, b);
        });
    }
    return sorted;
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
