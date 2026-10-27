/// The line above the list: where you are, and what is in it.
///
/// Pure, and in a util rather than in the widget, so the one thing that is easy
/// to get wrong — the hour boundaries — can be tested without a clock.
library;

/// Morning, afternoon, evening, from the clock, and the person's name when
/// there is one.
///
/// Never a bare "Hello": a greeting that does not know what time it is says
/// nothing, and the whole point of the line is that the app knows where it is.
///
/// The name is used as it came from the provider — not title-cased, not
/// shortened to a first name. Somebody whose mail says "Dr. Rao" is not "Dr",
/// and somebody who signs themselves "Yash Gupta" has chosen that.
/// More than one way to say it.
///
/// Chosen by the *day*, not by the minute or the rebuild: a greeting that
/// changes while somebody is looking at it is a greeting that looks like a bug,
/// and one that is the same words every morning for a year is a line people stop
/// reading altogether. Same day, same words; different day, different line.
const Map<String, List<String>> _byBand = <String, List<String>>{
  'morning': <String>[
    'Good morning',
    'Morning',
    'Back at it',
    'Let us see what arrived',
  ],
  'afternoon': <String>[
    'Good afternoon',
    'Afternoon',
    'Hope the day is going well',
    'What came in while you were out',
  ],
  'evening': <String>[
    'Good evening',
    'Evening',
    'Hope the evening is quiet',
    'One last look',
  ],
  'night': <String>[
    'Still up',
    'Working late',
    'The quiet hours',
    'Good evening',
  ],
};

/// Which band the hour falls in. Exposed because the boundaries are the one
/// thing here that is easy to get wrong.
String bandFor(int hour) {
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 22) return 'evening';
  return 'night';
}

String greetingFor(DateTime now, {String? name}) {
  final List<String> pool = _byBand[bandFor(now.hour)]!;
  // The day number, so it holds still for a day and moves on.
  final int day = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final String greeting = pool[day % pool.length];

  final String? trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return greeting;
  return '$greeting, $trimmed';
}

/// The folder, under the greeting.
///
/// It used to say how much was unread — "Inbox · nothing unread". A hero that
/// reports a count is a hero you read twice: the list below already says what
/// is unread, and the number was the one part of the line that could be wrong
/// (a folder whose STATUS had not been refreshed). The line names where you are
/// and stops.
String folderSummary(String folder, int unseen) => folder;

/// The same line, while a search is running.
///
/// The unread count is about the *folder*, and a search shows a handful of rows
/// out of it. A number that describes something other than what is on screen is
/// how the count came to look wrong: sitting above four results saying "12
/// unread" reads as a stale counter rather than as a fact about the mailbox. So
/// while a search is up, the line says how much matched.
String searchSummary(String folder, int matches, String query) {
  final String trimmed = query.trim();
  // Long queries are cut, because the line is a heading and not a receipt.
  final String quoted = trimmed.length > 28
      ? '"${trimmed.substring(0, 27)}..."'
      : '"$trimmed"';
  if (matches <= 0) return '$folder · nothing matches $quoted';
  return '$folder · $matches matching $quoted';
}
