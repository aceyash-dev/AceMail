import 'message_summary.dart';

/// A heading and the messages under it.
class MessageGroup {
  const MessageGroup(this.label, this.messages);

  final String label;
  final List<MessageSummary> messages;
}

/// Buckets messages by when they arrived.
///
/// A list of forty identical-looking rows tells you nothing about where to
/// start; the same rows under "Today" and "Earlier" tell you immediately. It is
/// the arrangement the settings screen already uses — a small heading, then the
/// things beneath it.
///
/// [now] is a parameter so this is a pure function of its inputs, and so a test
/// can stand at a fixed moment instead of hoping.
List<MessageGroup> groupByDate(
  List<MessageSummary> messages, {
  DateTime? now,
}) {
  if (messages.isEmpty) return const <MessageGroup>[];

  final DateTime today = _dayOf(now ?? DateTime.now());
  final Map<String, List<MessageSummary>> buckets =
      <String, List<MessageSummary>>{};

  for (final MessageSummary message in messages) {
    buckets.putIfAbsent(_labelFor(message.date, today), () => <MessageSummary>[])
        .add(message);
  }

  // Fixed order, so the headings do not shuffle as messages arrive. A group
  // with nothing in it is not shown at all.
  return <MessageGroup>[
    for (final String label in _order)
      if (buckets[label] != null) MessageGroup(label, buckets[label]!),
  ];
}

const List<String> _order = <String>[
  'Today',
  'Yesterday',
  'This week',
  'This month',
  'Earlier',
  'No date',
];

DateTime _dayOf(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _labelFor(DateTime? date, DateTime today) {
  if (date == null) return 'No date';

  final DateTime day = _dayOf(date);
  final int days = today.difference(day).inDays;

  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return 'This week';
  if (days < 31) return 'This month';
  return 'Earlier';
}
