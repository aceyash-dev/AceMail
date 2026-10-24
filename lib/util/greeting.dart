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
    'Good morning to you',
    'Hope the morning is kind',
  ],
  'afternoon': <String>[
    'Good afternoon',
    'Afternoon',
    'Good afternoon to you',
    'Hope the day is going well',
  ],
  'evening': <String>[
    'Good evening',
    'Evening',
    'Good evening to you',
    'Hope the evening is quiet',
  ],
  'night': <String>[
    'Still up',
    'Good evening',
    'Working late',
    'Late one',
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

/// The folder, and what is waiting in it.
///
/// "nothing unread" rather than "0 unread": a count of zero is a number to read
/// and dismiss, and a sentence is not.
String folderSummary(String folder, int unseen) {
  if (unseen <= 0) return '$folder · nothing unread';
  return '$folder · $unseen unread';
}
