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
  unread('Unread first');

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
  codes('Codes');

  const MessageFilter(this.label);

  final String label;

  bool matches(MessageSummary message) => switch (this) {
        MessageFilter.all => true,
        MessageFilter.unread => !message.isSeen,
        MessageFilter.flagged => message.isFlagged,
        MessageFilter.codes => message.otp != null,
      };
}
